defmodule LevanngocWeb.CheckAllInTitleLive.Index do
  use LevanngocWeb, :live_view

  import LevanngocWeb.LiveHelpers

  alias Levanngoc.Repo
  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Accounts
  import Number.Delimit

  @number_of_check_all_in_title_threads 20

  @impl true
  def mount(_params, _session, socket) do
    # Safely get user from current_scope
    user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    # Check if user is logged in
    is_logged_in = user != nil

    {:ok,
     socket
     |> assign(:is_logged_in, is_logged_in)
     |> assign(:show_login_required_modal, !is_logged_in)
     |> assign(:uploaded_files, [])
     |> assign(:is_processing, false)
     |> assign(:timer_text, "00:00:00.0")
     |> assign(:start_time, nil)
     |> assign(:show_result_modal, false)
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)
     |> assign(:result_stats, nil)
     |> assign(:is_edit_mode, true)
     |> assign(:manual_keywords, "")
     |> allow_upload(:file, accept: ~w(.xlsx .csv), max_entries: 1, max_file_size: 32_000_000)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    admin_setting = Repo.all(AdminSetting)

    [
      %AdminSetting{
        scraping_dog_api_key: scraping_dog_api_key
      }
      | _
    ] = admin_setting

    has_api_key = is_binary(scraping_dog_api_key) and scraping_dog_api_key != ""

    if has_api_key do
      token_usage_check_allintitle =
        case admin_setting do
          [%AdminSetting{token_usage_check_allintitle: usage} | _] when is_integer(usage) -> usage
          _ -> 0
        end

      # Parse keywords immediately to calculate cost
      is_edit_mode = socket.assigns.is_edit_mode
      manual_keywords = socket.assigns.manual_keywords

      keyword_data =
        if is_edit_mode do
          # Parse manual keywords - split by newlines and filter empty
          # No traffic data in edit mode
          manual_keywords
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(fn keyword -> %{keyword: keyword, traffic: nil} end)
        else
          # Parse from uploaded file - includes traffic data
          uploaded_files =
            consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
              parse_file(path, entry.client_type)
            end)

          List.flatten(uploaded_files)
        end

      total_keywords = length(keyword_data)
      total_cost = total_keywords * token_usage_check_allintitle
      current_token_amount = socket.assigns.current_scope.user.token_amount || 0
      remaining_tokens = current_token_amount - total_cost

      cost_details = %{
        total_keywords: total_keywords,
        token_usage_per_keyword: token_usage_check_allintitle,
        total_cost: total_cost,
        current_token_amount: current_token_amount,
        remaining_tokens: remaining_tokens
      }

      {:noreply,
       socket
       |> assign(:cost_details, cost_details)
       |> assign(:keyword_data_to_process, keyword_data)
       |> assign(:scraping_dog_api_key, scraping_dog_api_key)
       |> assign(:show_confirm_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Cấu hình hệ thống lỗi, vui lòng thử lại sau.")}
    end
  end

  @impl true
  def handle_event("download", %{"type" => type, "format" => format}, socket) do
    # Filter results based on type
    filtered_results =
      case type do
        "all" ->
          socket.assigns.check_results

        "indexed" ->
          Enum.filter(socket.assigns.check_results, fn r -> r.result_count > 0 end)

        "not_indexed" ->
          Enum.filter(socket.assigns.check_results, fn r -> r.result_count == 0 end)
      end

    # Generate file content based on format
    {content, filename, _content_type} =
      case format do
        "xlsx" ->
          generate_xlsx(filtered_results, type)

        "csv" ->
          generate_csv(filtered_results, type)
      end

    {:noreply,
     push_event(socket, "download-file", %{
       content: Base.encode64(content),
       filename: filename
     })}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    {:noreply, assign(socket, :is_edit_mode, !socket.assigns.is_edit_mode)}
  end

  @impl true
  def handle_event("switch_to_edit_mode", _params, socket) do
    {:noreply, assign(socket, :is_edit_mode, true)}
  end

  @impl true
  def handle_event("switch_to_file_mode", _params, socket) do
    {:noreply, assign(socket, :is_edit_mode, false)}
  end

  @impl true
  def handle_event("download_example", %{"format" => format}, socket) do
    # Generate example file content based on format
    {content, filename, _content_type} =
      case format do
        "xlsx" ->
          generate_example_xlsx()

        "csv" ->
          generate_example_csv()
      end

    {:noreply,
     push_event(socket, "download-file", %{
       content: Base.encode64(content),
       filename: filename
     })}
  end

  @impl true
  def handle_event("update_manual_keywords", %{"keywords" => keywords}, socket) do
    {:noreply, assign(socket, :manual_keywords, keywords)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_login_required_modal, false)}
  end

  @impl true
  def handle_event("confirm_check", _params, socket) do
    keyword_data = socket.assigns.keyword_data_to_process
    scraping_dog_api_key = socket.assigns.scraping_dog_api_key
    total_cost = socket.assigns.cost_details.total_cost
    current_user = socket.assigns.current_scope.user

    case Accounts.deduct_user_tokens(current_user, total_cost) do
      {:ok, updated_user} ->
        # Update current_scope with the new user state
        current_scope = %{socket.assigns.current_scope | user: updated_user}

        socket =
          socket
          |> assign(:current_scope, current_scope)
          |> assign(:show_confirm_modal, false)
          |> assign(:is_processing, true)
          |> assign(:start_time, DateTime.utc_now())

        # Process in async task to allow UI updates
        pid = self()

        Task.start(fn ->
          scraping_dog =
            %Levanngoc.External.ScrapingDog{}
            |> Levanngoc.External.ScrapingDog.put_apikey(scraping_dog_api_key)

          results =
            keyword_data
            |> Task.async_stream(
              fn %{keyword: keyword, traffic: traffic} ->
                result_count =
                  Levanngoc.External.ScrapingDog.check_allintitle(scraping_dog, keyword)

                %{keyword: keyword, traffic: traffic, result_count: result_count}
              end,
              max_concurrency: @number_of_check_all_in_title_threads,
              timeout: :infinity
            )
            |> Enum.map(fn {:ok, result} -> result end)

          # Send results as a tuple format expected by handle_info
          send(pid, {:processing_complete, [{nil, results}]})
        end)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_confirm_modal, false)
         |> put_flash(:error, "Có lỗi xảy ra khi trừ token. Vui lòng thử lại.")}
    end
  end

  @impl true
  def handle_event("cancel_check", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)
     |> assign(:keyword_data_to_process, [])}
  end

  @impl true

  def handle_info({:processing_complete, uploaded_files}, socket) do
    # uploaded_files is a list of {path, results}
    # We aggregate results from all files (though max_entries is 1)

    all_results =
      uploaded_files
      |> Enum.flat_map(fn {_path, results} -> results end)

    total_keywords = length(all_results)
    indexed_count = Enum.count(all_results, fn r -> r.result_count > 0 end)
    not_indexed_count = total_keywords - indexed_count

    now = DateTime.utc_now()
    diff = DateTime.diff(now, socket.assigns.start_time, :millisecond)

    hours = div(diff, 3600_000)
    rem_h = rem(diff, 3600_000)
    minutes = div(rem_h, 60_000)
    rem_m = rem(rem_h, 60_000)
    seconds = div(rem_m, 1000)
    millis = rem(rem_m, 1000)
    tenth = div(millis, 100)

    processing_time = "#{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}.#{tenth}"

    result_stats = %{
      total_keywords: total_keywords,
      indexed_count: indexed_count,
      not_indexed_count: not_indexed_count,
      processing_time: processing_time
    }

    {:noreply,
     socket
     |> assign(:is_processing, false)
     # Clear uploaded files or keep them? Usually clear after processing
     |> assign(:uploaded_files, [])
     |> assign(:result_stats, result_stats)
     |> assign(:check_results, all_results)
     |> assign(:show_result_modal, true)}
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  defp generate_xlsx(results, type) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    filename = "allintitle_check_#{type}_#{timestamp}.xlsx"

    # Create workbook with Elixlsx - include traffic if available
    sheet =
      results
      |> Enum.map(fn result ->
        if result.traffic do
          [result.keyword, result.traffic, result.result_count]
        else
          [result.keyword, result.result_count]
        end
      end)
      |> then(fn rows ->
        # Add header based on whether traffic exists
        header =
          if Enum.any?(results, fn r -> r.traffic end) do
            ["Keyword", "Traffic", "Result Count"]
          else
            ["Keyword", "Result Count"]
          end

        [header | rows]
      end)

    workbook = %Elixlsx.Workbook{
      sheets: [
        %Elixlsx.Sheet{
          name: "Results",
          rows: sheet
        }
      ]
    }

    {:ok, {_filename, content}} = Elixlsx.write_to_memory(workbook, filename)

    {content, filename, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: num

  defp to_ho_chi_minh_time(datetime) do
    case DateTime.shift_zone(datetime, "Asia/Ho_Chi_Minh") do
      {:ok, converted_datetime} -> converted_datetime
      # fallback to original if timezone conversion fails
      {:error, _} -> datetime
    end
  end

  defp format_timestamp(datetime) do
    "#{datetime.year}#{pad_zero(datetime.month)}#{pad_zero(datetime.day)}#{pad_zero(datetime.hour)}#{pad_zero(datetime.minute)}#{pad_zero(datetime.second)}"
  end

  defp generate_csv(results, type) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    filename = "allintitle_check_#{type}_#{timestamp}.csv"

    # Create CSV content - include traffic if available
    has_traffic = Enum.any?(results, fn r -> r.traffic end)

    header =
      if has_traffic do
        "Keyword,Traffic,Result Count\n"
      else
        "Keyword,Result Count\n"
      end

    rows =
      results
      |> Enum.map(fn result ->
        if result.traffic do
          "\"#{result.keyword}\",#{result.traffic},#{result.result_count}\n"
        else
          "\"#{result.keyword}\",#{result.result_count}\n"
        end
      end)
      |> Enum.join()

    content = header <> rows

    {content, filename, "text/csv"}
  end

  defp generate_example_xlsx do
    filename = "check_all_in_title_example.xlsx"

    # Create example data with 10 rows - each word from "this is your keyword list to check all in title"
    example_data = [
      ["Keyword", "Traffic"],
      ["this", 1],
      ["is", 2],
      ["your", 3],
      ["keyword", 4],
      ["list", 5],
      ["to", 6],
      ["check", 7],
      ["all", 8],
      ["in", 9],
      ["title", 10]
    ]

    workbook = %Elixlsx.Workbook{
      sheets: [
        %Elixlsx.Sheet{
          name: "Keywords",
          rows: example_data
        }
      ]
    }

    {:ok, {_filename, content}} = Elixlsx.write_to_memory(workbook, filename)

    {content, filename, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}
  end

  defp generate_example_csv do
    filename = "check_all_in_title_example.csv"

    # Create example CSV content with header and 10 rows - each word on its own row
    content = """
    Keyword,Traffic
    this,1
    is,2
    your,3
    keyword,4
    list,5
    to,6
    check,7
    all,8
    in,9
    title,10
    """

    {content, filename, "text/csv"}
  end

  defp parse_file(path, "text/csv") do
    path
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
    |> Enum.to_list()
    |> case do
      [] ->
        []

      [_header | rows] ->
        # Skip header and extract keyword (first column) and traffic (second column)
        rows
        |> Enum.map(fn row ->
          keyword = Enum.at(row, 0)
          traffic = Enum.at(row, 1)

          %{
            keyword: keyword,
            traffic: parse_traffic(traffic)
          }
        end)
        |> Enum.filter(fn %{keyword: keyword} -> keyword != nil and keyword != "" end)
    end
  end

  defp parse_file(path, _type) do
    # Assume XLSX if not CSV
    case Xlsxir.multi_extract(path, 0) do
      {:ok, table_id} ->
        data =
          Xlsxir.get_list(table_id)
          |> case do
            [] ->
              []

            [_header | rows] ->
              # Skip header and extract keyword (first column) and traffic (second column)
              rows
              |> Enum.map(fn row ->
                keyword = Enum.at(row, 0)
                traffic = Enum.at(row, 1)

                %{
                  keyword: to_string(keyword),
                  traffic: parse_traffic(traffic)
                }
              end)
              |> Enum.filter(fn %{keyword: keyword} -> keyword != nil and keyword != "" end)
          end

        Xlsxir.close(table_id)
        data

      _ ->
        []
    end
  end

  defp parse_traffic(nil), do: nil
  defp parse_traffic(""), do: nil

  defp parse_traffic(traffic) when is_integer(traffic), do: traffic

  defp parse_traffic(traffic) when is_binary(traffic) do
    case Integer.parse(traffic) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_traffic(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Kiểm tra All In Title</h1>

      <div class="card bg-base-100 shadow-xl mb-6 border border-base-300 flex-1">
        <div class="card-body flex flex-col p-0">
          <!-- Tabs -->
          <div role="tablist" class="tabs tabs-border mb-0">
            <button
              role="tab"
              class={[
                "tab",
                (@is_edit_mode && "tab-active") || "opacity-60"
              ]}
              phx-click="switch_to_edit_mode"
              disabled={!@is_logged_in or @is_processing}
            >
              Chế độ chỉnh sửa
            </button>
            <button
              role="tab"
              class={[
                "tab",
                (!@is_edit_mode && "tab-active") || "opacity-60"
              ]}
              phx-click="switch_to_file_mode"
              disabled={!@is_logged_in or @is_processing}
            >
              Chế độ File
            </button>
          </div>

          <form phx-change="validate" phx-submit="save" class="flex flex-col flex-1 p-4">
            <%= if @is_edit_mode do %>
              <div class="form-control w-full flex flex-col flex-1">
                <label class="label mb-2">
                  <span class="label-text">Nhập từ khóa (mỗi từ khóa một dòng)</span>
                </label>
                <textarea
                  class="w-full flex-1 textarea textarea-bordered rounded-lg"
                  placeholder="keyword1&#10;keyword2&#10;keyword3"
                  phx-change="update_manual_keywords"
                  name="keywords"
                  disabled={!@is_logged_in or @is_processing}
                >{@manual_keywords}</textarea>
              </div>
            <% else %>
              <div class="form-control w-full flex flex-col flex-1">
                <label class="label mb-2">
                  <span class="label-text">Chọn file (xlsx, csv)</span>
                </label>

                <div
                  class="flex items-center justify-center w-full flex-1"
                  phx-drop-target={@uploads.file.ref}
                >
                  <label
                    for={@uploads.file.ref}
                    class={"flex flex-col items-center justify-center w-full h-full border-2 border-dashed rounded-lg cursor-pointer bg-base-50 hover:bg-base-200 border-base-300 relative #{if !@is_logged_in or @is_processing, do: "opacity-50 pointer-events-none", else: ""}"}
                  >
                    <%= if @uploads.file.entries == [] do %>
                      <div class="flex flex-col items-center justify-center pt-5 pb-6">
                        <svg
                          class="w-8 h-8 mb-4 text-base-content/50"
                          aria-hidden="true"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 20 16"
                        >
                          <path
                            stroke="currentColor"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"
                          />
                        </svg>
                        <p class="mb-2 text-sm text-base-content/70">
                          <span class="font-semibold">Click để upload</span> hoặc kéo thả
                        </p>
                        <p class="text-xs text-base-content/50">XLSX, CSV (Max 32MB)</p>
                      </div>
                    <% else %>
                      <%= for entry <- @uploads.file.entries do %>
                        <div class="flex flex-col items-center justify-center pt-5 pb-6">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            fill="none"
                            viewBox="0 0 24 24"
                            class="w-12 h-12 mb-4 text-success"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <p class="mb-2 text-lg font-semibold text-base-content">
                            {entry.client_name}
                          </p>
                          <p class="text-sm text-base-content/70">
                            {humanize_size(entry.client_size)}
                            <%= if entry.progress > 0 do %>
                              - {entry.progress}%
                            <% end %>
                          </p>
                          <p class="mt-4 text-xs text-base-content/50">
                            Click hoặc kéo thả để thay thế file khác
                          </p>
                        </div>
                      <% end %>
                    <% end %>
                    <.live_file_input
                      upload={@uploads.file}
                      class="hidden"
                      disabled={!@is_logged_in or @is_processing}
                    />
                  </label>
                </div>
              </div>
            <% end %>

            <%= for entry <- @uploads.file.entries do %>
              <%= for err <- upload_errors(@uploads.file, entry) do %>
                <div class="alert alert-error mt-2">
                  <span>{error_to_string(err)}</span>
                </div>
              <% end %>
            <% end %>

            <div class="mt-4 flex justify-between items-center">
              <%= if !@is_edit_mode do %>
                <div class="dropdown dropdown-top">
                  <label tabindex="0" class="btn btn-primary btn-soft">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="w-5 h-5 mr-2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                    Tải file mẫu
                  </label>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52 mb-2"
                  >
                    <li>
                      <button type="button" phx-click="download_example" phx-value-format="xlsx">
                        Tải xuống Excel (.xlsx)
                      </button>
                    </li>
                    <li>
                      <button type="button" phx-click="download_example" phx-value-format="csv">
                        Tải xuống CSV (.csv)
                      </button>
                    </li>
                  </ul>
                </div>
              <% else %>
                <div></div>
              <% end %>
              <button
                type="submit"
                class="btn btn-primary min-w-[160px]"
                disabled={
                  !@is_logged_in or (@uploads.file.entries == [] and !@is_edit_mode) or
                    (@is_edit_mode and @manual_keywords == "") or @is_processing
                }
              >
                <%= if @is_processing do %>
                  <span class="loading loading-spinner"></span>
                <% else %>
                  <%= if @is_edit_mode do %>
                    Kiểm tra
                  <% else %>
                    Upload & Kiểm tra
                  <% end %>
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box relative z-50">
          <h3 class="font-bold text-lg mb-4">Kết quả kiểm tra</h3>

          <div class="space-y-4">
            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div>
                <div class="text-sm opacity-70">Tổng thời gian xử lý</div>
                <div class="text-2xl font-bold text-primary">{@result_stats.processing_time}</div>
              </div>
            </div>

            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div>
                <div class="text-sm opacity-70">Số từ khóa đã check</div>
                <div class="text-2xl font-bold">{@result_stats.total_keywords}</div>
              </div>
              <%= if @result_stats.total_keywords > 0 do %>
                <div class="dropdown dropdown-end">
                  <label tabindex="0" class="btn btn-ghost btn-sm btn-square">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="size-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                  </label>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
                  >
                    <li>
                      <button phx-click="download" phx-value-type="all" phx-value-format="xlsx">
                        Tải xuống (.xlsx)
                      </button>
                    </li>
                    <li>
                      <button phx-click="download" phx-value-type="all" phx-value-format="csv">
                        Tải xuống (.csv)
                      </button>
                    </li>
                  </ul>
                </div>
              <% end %>
            </div>

            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div>
                <div class="text-sm opacity-70">Có kết quả</div>
                <div class="text-2xl font-bold text-success">{@result_stats.indexed_count}</div>
              </div>
              <%= if @result_stats.indexed_count > 0 do %>
                <div class="dropdown dropdown-end">
                  <label tabindex="0" class="btn btn-ghost btn-sm btn-square">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="size-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                  </label>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
                  >
                    <li>
                      <button phx-click="download" phx-value-type="indexed" phx-value-format="xlsx">
                        Tải xuống (.xlsx)
                      </button>
                    </li>
                    <li>
                      <button phx-click="download" phx-value-type="indexed" phx-value-format="csv">
                        Tải xuống (.csv)
                      </button>
                    </li>
                  </ul>
                </div>
              <% end %>
            </div>

            <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
              <div>
                <div class="text-sm opacity-70">Không có kết quả</div>
                <div class="text-2xl font-bold text-error">{@result_stats.not_indexed_count}</div>
              </div>
              <%= if @result_stats.not_indexed_count > 0 do %>
                <div class="dropdown dropdown-end">
                  <label tabindex="0" class="btn btn-ghost btn-sm btn-square">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="size-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                  </label>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
                  >
                    <li>
                      <button
                        phx-click="download"
                        phx-value-type="not_indexed"
                        phx-value-format="xlsx"
                      >
                        Tải xuống (.xlsx)
                      </button>
                    </li>
                    <li>
                      <button phx-click="download" phx-value-type="not_indexed" phx-value-format="csv">
                        Tải xuống (.csv)
                      </button>
                    </li>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>

          <div class="modal-action">
            <button class="btn" phx-click="close_modal">Đóng</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
      </div>
    <% end %>

    <%= if @show_confirm_modal do %>
      <div class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Xác nhận sử dụng Token</h3>

          <div class="py-4 space-y-4">
            <p>Hành động này sẽ tiêu tốn token của bạn. Vui lòng xác nhận trước khi tiếp tục.</p>

            <div class="bg-base-200 p-4 rounded-lg space-y-2">
              <div class="flex justify-between">
                <span>Số lượng từ khóa:</span>
                <span class="font-bold">
                  {number_to_delimited(@cost_details.total_keywords, precision: 0)}
                </span>
              </div>
              <div class="flex justify-between">
                <span>Chi phí mỗi từ khóa:</span>
                <span class="font-bold">
                  {number_to_delimited(@cost_details.token_usage_per_keyword, precision: 0)} token<%= if @cost_details.token_usage_per_keyword > 1 do %>
                    s
                  <% end %>
                </span>
              </div>
              <div class="divider my-1"></div>
              <div class="flex justify-between text-lg">
                <span>Tổng chi phí:</span>
                <span class="font-bold text-error">
                  -{number_to_delimited(@cost_details.total_cost, precision: 0)} token
                </span>
              </div>
            </div>

            <div class="flex items-center justify-center space-x-4 text-lg font-medium">
              <div class="text-center">
                <div class="text-sm opacity-70">Hiện tại</div>
                <div>{number_to_delimited(@cost_details.current_token_amount, precision: 0)}</div>
              </div>
              <div class="text-2xl">-</div>
              <div class="text-center">
                <div class="text-sm opacity-70">Chi phí</div>
                <div class="text-error">
                  {number_to_delimited(@cost_details.total_cost, precision: 0)}
                </div>
              </div>
              <div class="text-2xl">=</div>
              <div class="text-center">
                <div class="text-sm opacity-70">Còn lại</div>
                <div class={
                  if @cost_details.remaining_tokens < 0, do: "text-error", else: "text-success"
                }>
                  {number_to_delimited(@cost_details.remaining_tokens, precision: 0)}
                </div>
              </div>
            </div>

            <%= if @cost_details.remaining_tokens < 0 do %>
              <div class="alert alert-error">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="stroke-current shrink-0 h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span>Bạn không đủ token để thực hiện hành động này.</span>
              </div>
            <% end %>
          </div>

          <div class="modal-action">
            <%= if @cost_details.remaining_tokens < 0 do %>
              <.link href={~p"/users/billing"} class="btn btn-success">
                Tôi muốn nâng cấp gói
              </.link>
              <button class="btn btn-primary" phx-click="cancel_check">Đã hiểu!</button>
            <% else %>
              <button class="btn" phx-click="cancel_check">Hủy bỏ</button>
              <button
                class="btn btn-primary"
                phx-click="confirm_check"
              >
                Xác nhận & Tiếp tục
              </button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_login_required_modal do %>
      <div class="modal modal-open">
        <div class="modal-box relative z-50">
          <h3 class="font-bold text-lg mb-4">Yêu cầu đăng nhập</h3>
          <div class="py-4">
            <div class="flex justify-center mb-4">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-16 w-16 text-warning"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <p class="text-center text-base-content">
              Bạn cần đăng nhập để sử dụng chức năng này.
            </p>
          </div>
          <div class="modal-action justify-center">
            <button class="btn btn-primary" phx-click="close_login_modal">Tôi đã hiểu</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
      </div>
    <% end %>
    """
  end
end
