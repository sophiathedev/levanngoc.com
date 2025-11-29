defmodule LevanngocWeb.CheckKeywordRankingLive.Index do
  use LevanngocWeb, :live_view

  alias Levanngoc.Repo
  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.KeywordCheckings
  alias Levanngoc.KeywordChecking
  import Number.Delimit

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

    page = 1
    per_page = 10

    {pagination, token_usage_per_check, total_token_usage} =
      if is_logged_in do
        pagination =
          KeywordCheckings.list_keyword_checkings_paginated(user.id,
            page: page,
            per_page: per_page
          )

        # Get admin settings for token usage
        admin_setting = Repo.all(AdminSetting) |> List.first()

        token_usage_per_check =
          case admin_setting do
            %AdminSetting{token_usage_keyword_ranking: usage} when is_integer(usage) -> usage
            _ -> 0
          end

        total_token_usage = pagination.total_entries * token_usage_per_check
        {pagination, token_usage_per_check, total_token_usage}
      else
        # Default values for non-logged-in users
        default_pagination = %{
          entries: [],
          page: page,
          per_page: per_page,
          total_entries: 0,
          total_pages: 0
        }

        {default_pagination, 0, 0}
      end

    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra thứ hạng từ khóa")
     |> assign(:is_logged_in, is_logged_in)
     |> assign(:show_login_required_modal, !is_logged_in)
     |> assign(:keyword_checkings, pagination.entries)
     |> assign(:page, pagination.page)
     |> assign(:per_page, pagination.per_page)
     |> assign(:total_entries, pagination.total_entries)
     |> assign(:total_pages, pagination.total_pages)
     |> assign(:token_usage_per_check, token_usage_per_check)
     |> assign(:total_token_usage, total_token_usage)
     |> assign(:editing_keyword, nil)
     |> assign(:form, nil)
     |> assign(:show_create_modal, false)
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)
     |> assign(:is_processing, false)
     |> assign(:timer_text, "00:00:00.0")
     |> assign(:start_time, nil)
     |> assign(:editing_time, false)
     |> assign(:email_hour, "08")
     |> assign(:email_minute, "00")
     |> assign(:show_result_modal, false)
     |> assign(:result_stats, nil)
     |> assign(:check_results, [])}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    changeset = KeywordCheckings.change_keyword_checking(%KeywordChecking{})

    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:editing_keyword, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    keyword_checking = KeywordCheckings.get_keyword_checking!(id)
    changeset = KeywordCheckings.change_keyword_checking(keyword_checking)

    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:editing_keyword, keyword_checking)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:editing_keyword, nil)
     |> assign(:form, nil)}
  end

  def handle_event("save_keyword", %{"keyword_checking" => keyword_params}, socket) do
    user = socket.assigns.current_scope.user
    keyword_params = Map.put(keyword_params, "user_id", user.id)

    result =
      if socket.assigns.editing_keyword do
        KeywordCheckings.update_keyword_checking(
          socket.assigns.editing_keyword,
          keyword_params
        )
      else
        KeywordCheckings.create_keyword_checking(keyword_params)
      end

    case result do
      {:ok, _keyword_checking} ->
        pagination =
          KeywordCheckings.list_keyword_checkings_paginated(
            user.id,
            page: socket.assigns.page,
            per_page: socket.assigns.per_page
          )

        total_token_usage = pagination.total_entries * socket.assigns.token_usage_per_check

        message =
          if socket.assigns.editing_keyword, do: "Cập nhật thành công", else: "Tạo mới thành công"

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(:keyword_checkings, pagination.entries)
         |> assign(:total_entries, pagination.total_entries)
         |> assign(:total_pages, pagination.total_pages)
         |> assign(:total_token_usage, total_token_usage)
         |> assign(:show_create_modal, false)
         |> assign(:editing_keyword, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_keyword", %{"id" => id}, socket) do
    keyword_checking = KeywordCheckings.get_keyword_checking!(id)
    user = socket.assigns.current_scope.user

    case KeywordCheckings.delete_keyword_checking(keyword_checking) do
      {:ok, _} ->
        pagination =
          KeywordCheckings.list_keyword_checkings_paginated(
            user.id,
            page: socket.assigns.page,
            per_page: socket.assigns.per_page
          )

        total_token_usage = pagination.total_entries * socket.assigns.token_usage_per_check

        {:noreply,
         socket
         |> put_flash(:info, "Xóa thành công")
         |> assign(:keyword_checkings, pagination.entries)
         |> assign(:total_entries, pagination.total_entries)
         |> assign(:total_pages, pagination.total_pages)
         |> assign(:total_token_usage, total_token_usage)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Xóa thất bại")}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    user = socket.assigns.current_scope.user
    page = String.to_integer(page)

    pagination =
      KeywordCheckings.list_keyword_checkings_paginated(
        user.id,
        page: page,
        per_page: socket.assigns.per_page
      )

    total_token_usage = pagination.total_entries * socket.assigns.token_usage_per_check

    {:noreply,
     socket
     |> assign(:keyword_checkings, pagination.entries)
     |> assign(:page, pagination.page)
     |> assign(:total_entries, pagination.total_entries)
     |> assign(:total_pages, pagination.total_pages)
     |> assign(:total_token_usage, total_token_usage)}
  end

  def handle_event("toggle_edit_time", _params, socket) do
    {:noreply, assign(socket, :editing_time, !socket.assigns.editing_time)}
  end

  def handle_event("update_email_time", %{"time" => time}, socket) do
    [hour, minute] = String.split(time, ":")

    {:noreply,
     socket
     |> assign(:email_hour, hour)
     |> assign(:email_minute, minute)
     |> assign(:editing_time, false)}
  end

  def handle_event("check_now", _params, socket) do
    current_user = socket.assigns.current_scope.user
    total_keywords = socket.assigns.total_entries
    token_usage_per_check = socket.assigns.token_usage_per_check
    total_cost = socket.assigns.total_token_usage
    current_token_amount = current_user.token_amount || 0
    remaining_tokens = current_token_amount - total_cost

    cost_details = %{
      total_keywords: total_keywords,
      token_usage_per_check: token_usage_per_check,
      total_cost: total_cost,
      current_token_amount: current_token_amount,
      remaining_tokens: remaining_tokens
    }

    {:noreply,
     socket
     |> assign(:cost_details, cost_details)
     |> assign(:show_confirm_modal, true)}
  end

  def handle_event("confirm_check", _params, socket) do
    total_cost = socket.assigns.cost_details.total_cost
    current_user = socket.assigns.current_scope.user

    # Get admin settings for ScrapingDog API key
    admin_setting = Repo.all(AdminSetting) |> List.first()

    case admin_setting do
      %AdminSetting{scraping_dog_api_key: api_key} when is_binary(api_key) and api_key != "" ->
        case Levanngoc.Accounts.deduct_user_tokens(current_user, total_cost) do
          {:ok, updated_user} ->
            # Update current_scope with the new user state
            current_scope = %{socket.assigns.current_scope | user: updated_user}

            # Get all keyword checkings to process
            keyword_checkings = KeywordCheckings.list_keyword_checkings(current_user.id)

            socket =
              socket
              |> assign(:current_scope, current_scope)
              |> assign(:show_confirm_modal, false)
              |> assign(:is_processing, true)
              |> assign(:start_time, DateTime.utc_now())
              |> assign(:timer_text, "00:00:00.0")

            # Start timer
            :timer.send_interval(100, self(), :tick)

            # Process keyword rankings in async task
            pid = self()

            Task.start(fn ->
              scraping_dog =
                %Levanngoc.External.ScrapingDog{}
                |> Levanngoc.External.ScrapingDog.put_apikey(api_key)

              results =
                keyword_checkings
                |> Task.async_stream(
                  fn keyword_checking ->
                    rank =
                      Levanngoc.External.ScrapingDog.check_keyword_ranking(
                        scraping_dog,
                        keyword_checking.keyword,
                        keyword_checking.website_url
                      )

                    %{
                      keyword: keyword_checking.keyword,
                      website_url: keyword_checking.website_url,
                      rank: rank || "Not found"
                    }
                  end,
                  max_concurrency: 10,
                  timeout: :infinity
                )
                |> Enum.map(fn {:ok, result} -> result end)

              send(pid, {:processing_complete, results})
            end)

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(:show_confirm_modal, false)
             |> put_flash(:error, "Có lỗi xảy ra khi trừ token. Vui lòng thử lại.")}
        end

      _ ->
        {:noreply,
         socket
         |> assign(:show_confirm_modal, false)
         |> put_flash(:error, "Cấu hình hệ thống lỗi, vui lòng thử lại sau.")}
    end
  end

  def handle_event("cancel_check", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)}
  end

  def handle_event("close_result_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_login_required_modal, false)}
  end

  def handle_event("download", %{"type" => type, "format" => format}, socket) do
    # Filter results based on type
    filtered_results =
      case type do
        "all" ->
          socket.assigns.check_results

        "ranked" ->
          Enum.filter(socket.assigns.check_results, fn r ->
            r.rank != nil and r.rank != "Not found" and r.rank != "Not Found"
          end)

        "not_ranked" ->
          Enum.filter(socket.assigns.check_results, fn r ->
            r.rank == nil or r.rank == "Not found" or r.rank == "Not Found"
          end)
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

  def handle_info({:processing_complete, results}, socket) do
    total_keywords = length(results)
    ranked_count = Enum.count(results, fn r -> r.rank != nil and r.rank != "Not found" end)
    not_ranked_count = total_keywords - ranked_count

    processing_time = socket.assigns.timer_text

    result_stats = %{
      total_keywords: total_keywords,
      ranked_count: ranked_count,
      not_ranked_count: not_ranked_count,
      processing_time: processing_time
    }

    {:noreply,
     socket
     |> assign(:is_processing, false)
     |> assign(:result_stats, result_stats)
     |> assign(:check_results, results)
     |> assign(:show_result_modal, true)}
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  # Helper function to generate page range with ellipsis
  defp page_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [
          1,
          :ellipsis,
          total_pages - 4,
          total_pages - 3,
          total_pages - 2,
          total_pages - 1,
          total_pages
        ]

      true ->
        [1, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages]
    end
  end

  defp generate_xlsx(results, type) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    filename = "keyword_ranking_#{type}_#{timestamp}.xlsx"

    # Create workbook with Elixlsx
    sheet =
      results
      |> Enum.map(fn result ->
        [result.keyword, result.website_url, result.rank]
      end)
      |> then(fn rows -> [["Keyword", "Website URL", "Rank"] | rows] end)

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
    filename = "keyword_ranking_#{type}_#{timestamp}.csv"

    # Create CSV content
    header = "Keyword,Website URL,Rank\n"

    rows =
      results
      |> Enum.map(fn result ->
        "\"#{result.keyword}\",\"#{result.website_url}\",\"#{result.rank}\"\n"
      end)
      |> Enum.join()

    content = header <> rows

    {content, filename, "text/csv"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col gap-4">
      <div class="flex justify-between items-center mb-2">
        <h1 class="text-3xl font-bold">{@page_title}</h1>
        <button
          class="btn btn-primary"
          phx-click="open_create_modal"
          disabled={!@is_logged_in or @is_processing}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5 mr-2"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"
              clip-rule="evenodd"
            />
          </svg>
          Thêm mới
        </button>
      </div>

      <div class="bg-white grid grid-cols-2 grid-rows-[2fr_1fr] gap-4 flex-1 overflow-hidden">
        <!-- First row spanning 2 columns - 2/3 height -->
        <div class="col-span-2 card shadow-lg border border-base-300 overflow-hidden flex flex-col">
          <div class="flex-1 overflow-hidden flex flex-col">
            <%= if @keyword_checkings == [] do %>
              <div class="text-center py-12 px-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-16 w-16 mx-auto text-base-content/30 mb-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                <p class="text-lg text-base-content/70">Chưa có từ khóa nào</p>
                <p class="text-sm text-base-content/50 mt-2">
                  Nhấn "Thêm mới" để tạo từ khóa đầu tiên
                </p>
              </div>
            <% else %>
              <div class="overflow-auto flex-1">
                <table class="table w-full">
                  <thead class="bg-base-200 sticky top-0 z-10">
                    <tr class="border-b border-base-300">
                      <th class="w-16 py-3 px-4 text-xs font-semibold uppercase tracking-wider text-base-content/70">
                        #
                      </th>
                      <th class="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-base-content/70">
                        Từ khóa
                      </th>
                      <th class="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-base-content/70">
                        Website URL
                      </th>
                      <th class="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-base-content/70 text-right">
                        Hành động
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-base-200">
                    <%= for {keyword, index} <- Enum.with_index(@keyword_checkings, (@page - 1) * @per_page + 1) do %>
                      <tr class="hover:bg-base-200/50 transition-colors">
                        <td class="py-3 px-4 text-sm text-base-content/60">{index}</td>
                        <td class="py-3 px-4">
                          <span class="text-sm font-medium text-base-content">{keyword.keyword}</span>
                        </td>
                        <td class="py-3 px-4">
                          <a
                            href={keyword.website_url}
                            target="_blank"
                            class="text-sm text-primary hover:text-primary-focus hover:underline truncate block max-w-md transition-colors"
                          >
                            {keyword.website_url}
                          </a>
                        </td>
                        <td class="py-3 px-4">
                          <div class="flex justify-end gap-2">
                            <button
                              class="btn btn-sm btn-square btn-ghost hover:bg-primary/10 hover:text-primary transition-colors"
                              phx-click="open_edit_modal"
                              phx-value-id={keyword.id}
                              title="Sửa"
                              disabled={!@is_logged_in or @is_processing}
                            >
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-4 w-4"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                              >
                                <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                              </svg>
                            </button>
                            <button
                              class="btn btn-sm btn-square btn-ghost hover:bg-error/10 hover:text-error transition-colors"
                              phx-click="delete_keyword"
                              phx-value-id={keyword.id}
                              data-confirm="Bạn có chắc chắn muốn xóa từ khóa này?"
                              title="Xóa"
                              disabled={!@is_logged_in or @is_processing}
                            >
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-4 w-4"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                              >
                                <path
                                  fill-rule="evenodd"
                                  d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <%= if @total_entries > @per_page do %>
                <div class="flex justify-between items-center px-4 py-3 border-t border-base-300">
                  <div class="text-xs text-base-content/60">
                    Hiển thị
                    <span class="font-semibold text-base-content">{(@page - 1) * @per_page + 1}</span>
                    -
                    <span class="font-semibold text-base-content">
                      {min(@page * @per_page, @total_entries)}
                    </span>
                    trong tổng số
                    <span class="font-semibold text-base-content">{@total_entries}</span>
                    kết quả
                  </div>
                  <div class="join shadow-sm">
                    <button
                      class="join-item btn btn-sm"
                      phx-click="change_page"
                      phx-value-page={@page - 1}
                      disabled={!@is_logged_in or @page == 1 or @is_processing}
                    >
                      «
                    </button>

                    <%= for page_num <- page_range(@page, @total_pages) do %>
                      <%= if page_num == :ellipsis do %>
                        <button class="join-item btn btn-sm btn-disabled">...</button>
                      <% else %>
                        <button
                          class={"join-item btn btn-sm #{if page_num == @page, do: "btn-active"}"}
                          phx-click="change_page"
                          phx-value-page={page_num}
                          disabled={!@is_logged_in or @is_processing}
                        >
                          {page_num}
                        </button>
                      <% end %>
                    <% end %>

                    <button
                      class="join-item btn btn-sm"
                      phx-click="change_page"
                      phx-value-page={@page + 1}
                      disabled={!@is_logged_in or @page == @total_pages or @is_processing}
                    >
                      »
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Second row - Two cards in separate columns -->
        <div class="card !bg-white shadow-lg border border-base-300 overflow-hidden">
          <div class="card-body p-6">
            <h2 class="card-title text-lg font-semibold text-base-content mb-4">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-primary"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z" />
              </svg>
              Thống kê sử dụng Token
            </h2>
            <div class="space-y-4">
              <div class="flex justify-between items-center p-3 bg-base-100 rounded-lg">
                <span class="text-sm text-base-content/70">Tổng số từ khóa:</span>
                <span class="text-lg font-bold text-primary">
                  {number_to_delimited(@total_entries, precision: 0)}
                </span>
              </div>
              <div class="flex justify-between items-center p-3 bg-base-100 rounded-lg">
                <span class="text-sm text-base-content/70">Token mỗi lần kiểm tra:</span>
                <span class="text-lg font-bold text-info">
                  {number_to_delimited(@token_usage_per_check, precision: 0)}
                </span>
              </div>
              <div class="divider my-2"></div>
              <div class="flex justify-between items-center p-3 bg-primary/10 rounded-lg">
                <span class="text-sm font-semibold text-base-content">Tổng token sẽ dùng:</span>
                <span class="text-xl font-bold text-primary">
                  {number_to_delimited(@total_token_usage, precision: 0)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="card !bg-white shadow-lg border border-base-300 overflow-hidden">
          <div class="card-body p-6 flex flex-col">
            <h2 class="card-title text-lg font-semibold text-base-content mb-4">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-secondary"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
              </svg>
              Gửi Email báo cáo
            </h2>
            <div class="flex-1 space-y-3">
              <div class="bg-base-100 rounded-lg p-4">
                <p class="text-sm text-base-content/70 mb-2">Thời gian gửi email hàng ngày:</p>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5 text-primary flex-shrink-0"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    <%= if @editing_time do %>
                      <form phx-submit="update_email_time" class="flex items-center gap-2">
                        <input
                          type="time"
                          name="time"
                          value={"#{@email_hour}:#{@email_minute}"}
                          class="input input-bordered h-8 font-bold text-primary [&::-webkit-calendar-picker-indicator]:hidden"
                          style="appearance: none; -webkit-appearance: none; -moz-appearance: none;"
                        />
                        <button
                          type="submit"
                          class="btn btn-success h-8 w-8 min-h-0 btn-square border-0"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-4 w-4"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path
                              fill-rule="evenodd"
                              d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </button>
                      </form>
                    <% else %>
                      <span class="text-2xl font-bold text-primary">
                        {@email_hour}:{@email_minute}
                      </span>
                    <% end %>
                  </div>
                  <button
                    class="btn btn-ghost btn-xs btn-square"
                    phx-click="toggle_edit_time"
                    title="Sửa thời gian"
                    disabled={!@is_logged_in}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                    >
                      <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
            <div class="flex justify-end gap-2 mt-4">
              <button class="btn btn-secondary btn-md" disabled={!@is_logged_in or @is_processing}>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5 mr-1"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                  <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                </svg>
                Gửi qua Email
              </button>

              <button
                class="btn btn-primary btn-md"
                phx-click="check_now"
                disabled={!@is_logged_in or @total_entries == 0 or @is_processing}
              >
                <%= if @is_processing do %>
                  {@timer_text}
                <% else %>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-1"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  Kiểm tra ngay
                <% end %>
              </button>
            </div>
          </div>
        </div>
      </div>

      <%= if @show_create_modal or @editing_keyword do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">
              {if @editing_keyword, do: "Sửa từ khóa", else: "Thêm từ khóa mới"}
            </h3>
            <.form for={@form} phx-submit="save_keyword" class="space-y-4">
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Từ khóa <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:keyword]}
                  type="text"
                  placeholder="Nhập từ khóa cần kiểm tra"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Website URL <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:website_url]}
                  type="text"
                  placeholder="example.com hoặc https://example.com"
                  class="input input-bordered w-full"
                  pattern="[a-zA-Z0-9._\-/:?=&%]+"
                  title="Chỉ cho phép chữ cái, số và các ký tự hợp lệ trong URL (không có khoảng trắng)"
                  required
                />
                <label class="label">
                  <span class="label-text-alt text-base-content/60 text-xs">
                    Có thể nhập với hoặc không có http:// hoặc https://
                  </span>
                </label>
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_modal">Hủy</button>
                <button type="submit" class="btn btn-primary">
                  {if @editing_keyword, do: "Cập nhật", else: "Tạo mới"}
                </button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="close_modal"></div>
        </div>
      <% end %>

      <%= if @show_confirm_modal and @cost_details do %>
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
                    {number_to_delimited(@cost_details.token_usage_per_check, precision: 0)} token<%= if @cost_details.token_usage_per_check > 1 do %>
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
                <button class="btn btn-primary" phx-click="confirm_check">
                  Xác nhận & Tiếp tục
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_result_modal and @result_stats do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-2xl">
            <h3 class="font-bold text-lg mb-4">Kết quả kiểm tra thứ hạng</h3>

            <div class="space-y-4">
              <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                <div>
                  <div class="text-sm opacity-70">Tổng thời gian xử lý</div>
                  <div class="text-2xl font-bold text-primary">{@result_stats.processing_time}</div>
                </div>
              </div>

              <%= if @result_stats.total_keywords > 0 do %>
                <%= if @result_stats.ranked_count > 0 do %>
                  <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                    <div>
                      <div class="text-sm opacity-70">Có thứ hạng</div>
                      <div class="text-2xl font-bold text-success">{@result_stats.ranked_count}</div>
                    </div>
                    <div class="dropdown dropdown-end">
                      <label tabindex="0" class="btn btn-ghost btn-sm">
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
                          <button phx-click="download" phx-value-type="ranked" phx-value-format="xlsx">
                            Tải xuống (.xlsx)
                          </button>
                        </li>
                        <li>
                          <button phx-click="download" phx-value-type="ranked" phx-value-format="csv">
                            Tải xuống (.csv)
                          </button>
                        </li>
                      </ul>
                    </div>
                  </div>
                <% end %>

                <%= if @result_stats.not_ranked_count > 0 do %>
                  <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                    <div>
                      <div class="text-sm opacity-70">Không tìm thấy thứ hạng</div>
                      <div class="text-2xl font-bold text-error">
                        {@result_stats.not_ranked_count}
                      </div>
                    </div>
                    <div class="dropdown dropdown-end">
                      <label tabindex="0" class="btn btn-ghost btn-sm">
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
                            phx-value-type="not_ranked"
                            phx-value-format="xlsx"
                          >
                            Tải xuống (.xlsx)
                          </button>
                        </li>
                        <li>
                          <button
                            phx-click="download"
                            phx-value-type="not_ranked"
                            phx-value-format="csv"
                          >
                            Tải xuống (.csv)
                          </button>
                        </li>
                      </ul>
                    </div>
                  </div>
                <% end %>

                <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                  <div>
                    <div class="text-sm opacity-70">Tất cả kết quả</div>
                    <div class="text-2xl font-bold">{@result_stats.total_keywords}</div>
                  </div>
                  <div class="dropdown dropdown-end">
                    <label tabindex="0" class="btn btn-ghost btn-sm">
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
                </div>
              <% end %>
            </div>

            <div class="modal-action">
              <button class="btn btn-primary" phx-click="close_result_modal">Đóng</button>
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
    </div>
    """
  end
end
