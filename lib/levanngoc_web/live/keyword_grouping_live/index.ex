defmodule LevanngocWeb.KeywordGroupingLive.Index do
  use LevanngocWeb, :live_view

  import LevanngocWeb.LiveHelpers

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
     |> assign(:is_edit_mode, true)
     |> assign(:project_name, "")
     |> assign(:keywords_input, "")
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
    # Parse keywords immediately
    is_edit_mode = socket.assigns.is_edit_mode
    keywords_input = socket.assigns.keywords_input

    keywords =
      if is_edit_mode do
        # Parse manual keywords - split by newlines and filter empty
        keywords_input
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
      else
        # Parse from uploaded file
        uploaded_files =
          consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
            parse_file(path, entry.client_type)
          end)

        List.flatten(uploaded_files)
      end

    total_keywords = length(keywords)

    if total_keywords == 0 do
      {:noreply, put_flash(socket, :error, "Vui lòng nhập ít nhất một từ khóa")}
    else
      # Start processing directly without confirmation
      socket =
        socket
        |> assign(:is_processing, true)
        |> assign(:start_time, DateTime.utc_now())
        |> assign(:timer_text, "00:00:00.0")

      # Start timer
      :timer.send_interval(100, self(), :tick)

      # Process in async task to allow UI updates
      pid = self()

      Task.start(fn ->
        # This is a placeholder - implement your keyword grouping logic here
        # For now, just randomly group keywords
        groups = group_keywords(keywords)
        send(pid, {:processing_complete, [{nil, groups}]})
      end)

      {:noreply, socket}
    end
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
  def handle_event("update_project_name", %{"project_name" => project_name}, socket) do
    {:noreply, assign(socket, :project_name, project_name)}
  end

  @impl true
  def handle_event("update_keywords", %{"keywords" => keywords}, socket) do
    {:noreply, assign(socket, :keywords_input, keywords)}
  end

  @impl true
  def handle_event("close_result_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_result_modal, false)
     |> assign(:grouping_results, [])}
  end

  @impl true
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_login_required_modal, false)}
  end

  @impl true
  def handle_event("download", %{"format" => format}, socket) do
    results = socket.assigns.grouping_results

    # Generate file content based on format
    {content, filename, _content_type} =
      case format do
        "xlsx" ->
          generate_xlsx(results)

        "csv" ->
          generate_csv(results)
      end

    {:noreply,
     push_event(socket, "download-file", %{
       content: Base.encode64(content),
       filename: filename
     })}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.is_processing do
      now = DateTime.utc_now()
      diff = DateTime.diff(now, socket.assigns.start_time, :millisecond)

      hours = div(diff, 3600_000)
      rem_h = rem(diff, 3600_000)
      minutes = div(rem_h, 60_000)
      rem_m = rem(rem_h, 60_000)
      seconds = div(rem_m, 1000)
      millis = rem(rem_m, 1000)
      tenth = div(millis, 100)

      timer_text = "#{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}.#{tenth}"

      {:noreply, assign(socket, :timer_text, timer_text)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:processing_complete, uploaded_files}, socket) do
    # uploaded_files is a list of {path, results}
    # We aggregate results from all files (though max_entries is 1)

    all_results =
      uploaded_files
      |> Enum.flat_map(fn {_path, results} -> results end)

    processing_time = socket.assigns.timer_text

    {:noreply,
     socket
     |> assign(:is_processing, false)
     # Clear uploaded files after processing
     |> assign(:uploaded_files, [])
     |> assign(:grouping_results, all_results)
     |> assign(:processing_time, processing_time)
     |> assign(:show_result_modal, true)}
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  # Placeholder keyword grouping logic
  # Replace this with your actual grouping algorithm
  defp group_keywords(keywords) do
    # Simple grouping by first letter (replace with actual logic)
    keywords
    |> Enum.group_by(fn keyword ->
      String.first(keyword) |> String.upcase()
    end)
    |> Enum.map(fn {group_name, keywords_in_group} ->
      %{
        group_name: "Nhóm #{group_name}",
        keywords: keywords_in_group,
        count: length(keywords_in_group)
      }
    end)
  end

  defp generate_xlsx(results) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    filename = "keyword_grouping_#{timestamp}.xlsx"

    # Create workbook with Elixlsx
    rows =
      results
      |> Enum.flat_map(fn group ->
        [["#{group.group_name} (#{group.count} từ khóa)", ""]] ++
          Enum.map(group.keywords, fn kw -> ["", kw] end)
      end)

    sheet = [["Nhóm", "Từ khóa"] | rows]

    workbook = %Elixlsx.Workbook{
      sheets: [
        %Elixlsx.Sheet{
          name: "Keyword Groups",
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
      {:error, _} -> datetime
    end
  end

  defp format_timestamp(datetime) do
    "#{datetime.year}#{pad_zero(datetime.month)}#{pad_zero(datetime.day)}#{pad_zero(datetime.hour)}#{pad_zero(datetime.minute)}#{pad_zero(datetime.second)}"
  end

  defp parse_file(path, "text/csv") do
    path
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
    |> Stream.map(fn row -> List.first(row) end)
    |> Enum.to_list()
  end

  defp parse_file(path, _type) do
    # Assume XLSX if not CSV
    case Xlsxir.multi_extract(path, 0) do
      {:ok, table_id} ->
        data =
          Xlsxir.get_list(table_id)
          |> Enum.map(fn row -> List.first(row) end)

        Xlsxir.close(table_id)
        data

      _ ->
        []
    end
  end

  defp generate_csv(results) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    filename = "keyword_grouping_#{timestamp}.csv"

    # Create CSV content
    header = "Nhóm,Từ khóa\n"

    rows =
      results
      |> Enum.flat_map(fn group ->
        ["\"#{group.group_name} (#{group.count} từ khóa)\",\"\"\n"] ++
          Enum.map(group.keywords, fn kw -> "\"\",\"#{kw}\"\n" end)
      end)
      |> Enum.join()

    content = header <> rows

    {content, filename, "text/csv"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Gom nhóm từ khóa</h1>

      <div class="card bg-base-100 shadow-xl mb-6 border border-base-300 flex-1">
        <div class="card-body flex flex-col p-0">
          <!-- Tabs -->
          <div role="tablist" class="tabs tabs-border mb-0">
            <button
              type="button"
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
              type="button"
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
            <div class="form-control w-full mb-4">
              <label class="label mb-2">
                <span class="label-text">Tên dự án</span>
              </label>
              <input
                type="text"
                class="input w-full rounded-lg"
                placeholder="Nhập tên dự án"
                value={@project_name}
                phx-change="update_project_name"
                name="project_name"
                disabled={!@is_logged_in or @is_processing}
              />
            </div>

            <div class="flex flex-col flex-1">
              <%= if @is_edit_mode do %>
                <div class="form-control w-full flex flex-col flex-1">
                  <label class="label mb-2">
                    <span class="label-text">
                      Danh sách từ khóa để gom nhóm (mỗi từ khóa trên một dòng)
                    </span>
                  </label>
                  <textarea
                    id="keywords-input"
                    class="w-full flex-1 textarea textarea-bordered rounded-lg"
                    placeholder="Nhập từ khóa, mỗi từ khóa một dòng&#10;Ví dụ:&#10;seo tools&#10;keyword research&#10;backlink checker"
                    phx-change="update_keywords"
                    name="keywords"
                    phx-hook="AutoResize"
                    disabled={!@is_logged_in or @is_processing}
                  >{@keywords_input}</textarea>
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

              <div class="mt-4 flex justify-end items-center">
                <button
                  type="submit"
                  class="btn btn-primary min-w-[160px]"
                  disabled={true}
                >
                  <%= if @is_processing do %>
                    {@timer_text}
                  <% else %>
                    Upload & Gom nhóm
                  <% end %>
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-4xl relative z-50">
          <h3 class="font-bold text-lg mb-4">Kết quả gom nhóm từ khóa</h3>

          <div class="space-y-4 max-h-96 overflow-y-auto">
            <%= for group <- @grouping_results do %>
              <div class="card bg-base-200 shadow-sm">
                <div class="card-body p-4">
                  <h4 class="font-semibold text-base flex items-center justify-between">
                    <span>{group.group_name}</span>
                    <span class="badge badge-primary">{group.count} từ khóa</span>
                  </h4>
                  <div class="flex flex-wrap gap-2 mt-2">
                    <%= for keyword <- group.keywords do %>
                      <span class="badge badge-outline">{keyword}</span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="flex justify-between items-center mt-4 pt-4 border-t">
            <div class="text-sm text-base-content/70">
              Thời gian xử lý: <span class="font-semibold">{@processing_time}</span>
            </div>
            <div class="flex gap-2">
              <div class="dropdown dropdown-end">
                <label tabindex="0" class="btn btn-sm btn-primary">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="size-4 mr-1"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                    />
                  </svg>
                  Tải xuống
                </label>
                <ul
                  tabindex="0"
                  class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
                >
                  <li>
                    <button phx-click="download" phx-value-format="xlsx">
                      Tải xuống (.xlsx)
                    </button>
                  </li>
                  <li>
                    <button phx-click="download" phx-value-format="csv">
                      Tải xuống (.csv)
                    </button>
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <div class="modal-action">
            <button class="btn btn-primary" phx-click="close_result_modal">Đóng</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
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
