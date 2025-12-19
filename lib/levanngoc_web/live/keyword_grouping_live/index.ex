defmodule LevanngocWeb.KeywordGroupingLive.Index do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Accounts
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

    {:ok,
     socket
     |> assign(:is_logged_in, is_logged_in)
     |> assign(:show_login_required_modal, !is_logged_in)
     |> assign(:is_processing, false)
     |> assign(:start_time, nil)
     |> assign(:show_result_modal, false)
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)
     |> assign(:project_name, "")
     |> assign(:similarity_threshold, "0.4")
     |> assign(:keywords_input, "")
     |> assign(:original_keyword_order, [])
     |> assign(:is_exporting_sheets, false)
     |> assign(:exported_sheets_url, nil)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    # Parse keywords from input
    keywords_input = socket.assigns.keywords_input
    similarity_threshold_str = socket.assigns.similarity_threshold

    keywords =
      keywords_input
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))

    total_keywords = length(keywords)

    # Validate similarity threshold
    similarity_threshold =
      case Float.parse(similarity_threshold_str) do
        {value, _} when value >= 0.1 and value <= 1.0 -> value
        _ -> 0.4
      end

    if total_keywords == 0 do
      {:noreply, put_flash(socket, :error, "Vui lòng nhập ít nhất một từ khóa")}
    else
      # Get admin settings for API key and token usage
      admin_setting = Levanngoc.Repo.all(Levanngoc.Settings.AdminSetting)

      case admin_setting do
        [%Levanngoc.Settings.AdminSetting{scraping_dog_api_key: api_key} | _]
        when is_binary(api_key) and api_key != "" ->
          # Get token usage for keyword grouping
          token_usage_keyword_grouping =
            case admin_setting do
              [%AdminSetting{token_usage_keyword_grouping: usage} | _] when is_integer(usage) ->
                usage

              _ ->
                0
            end

          # Calculate cost
          total_cost = total_keywords * token_usage_keyword_grouping
          current_token_amount = socket.assigns.current_scope.user.token_amount || 0
          remaining_tokens = current_token_amount - total_cost

          cost_details = %{
            total_keywords: total_keywords,
            token_usage_per_keyword: token_usage_keyword_grouping,
            total_cost: total_cost,
            current_token_amount: current_token_amount,
            remaining_tokens: remaining_tokens
          }

          {:noreply,
           socket
           |> assign(:cost_details, cost_details)
           |> assign(:keywords_to_process, keywords)
           |> assign(:similarity_threshold_value, similarity_threshold)
           |> assign(:api_key, api_key)
           |> assign(:show_confirm_modal, true)}

        _ ->
          {:noreply, put_flash(socket, :error, "Cấu hình hệ thống lỗi, vui lòng thử lại sau.")}
      end
    end
  end

  @impl true
  def handle_event("confirm_grouping", _params, socket) do
    keywords = socket.assigns.keywords_to_process
    api_key = socket.assigns.api_key
    similarity_threshold = socket.assigns.similarity_threshold_value
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
          |> assign(:original_keyword_order, keywords)

        # Process in async task to allow UI updates
        pid = self()

        Task.start(fn ->
          groups = group_keywords(keywords, api_key, similarity_threshold)
          send(pid, {:processing_complete, [{nil, groups}]})
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
  def handle_event("cancel_grouping", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, false)
     |> assign(:cost_details, nil)
     |> assign(:keywords_to_process, [])}
  end

  @impl true
  def handle_event("update_project_name", %{"project_name" => project_name}, socket) do
    {:noreply, assign(socket, :project_name, project_name)}
  end

  @impl true
  def handle_event("update_similarity_threshold", %{"similarity_threshold" => threshold}, socket) do
    {:noreply, assign(socket, :similarity_threshold, threshold)}
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
    original_order = socket.assigns[:original_keyword_order] || []
    project_name = socket.assigns.project_name

    # Generate file content based on format
    {content, filename, _content_type} =
      case format do
        "xlsx" ->
          generate_xlsx(results, original_order, project_name)

        "csv" ->
          generate_csv(results, original_order, project_name)
      end

    {:noreply,
     push_event(socket, "download-file", %{
       content: Base.encode64(content),
       filename: filename
     })}
  end

  @impl true
  def handle_event("export_google_sheets", _params, socket) do
    if socket.assigns.is_exporting_sheets do
      {:noreply, socket}
    else
      # Check if we already exported
      cached_url = socket.assigns.exported_sheets_url

      if cached_url do
        # Reuse existing spreadsheet
        {:noreply, push_event(socket, "open-url", %{url: cached_url})}
      else
        # Set exporting flag and return immediately to show loading state
        socket = assign(socket, :is_exporting_sheets, true)

        results = socket.assigns.grouping_results
        original_order = socket.assigns[:original_keyword_order] || []
        project_name = socket.assigns.project_name

        # Sort groups by size (descending) to assign GROUP_X numbers
        sorted_results =
          results
          |> Enum.sort_by(fn group -> {-group.count, group.group_name} end)
          |> Enum.with_index(1)

        # Create a mapping of keyword -> {group_id, parent}
        keyword_to_group =
          sorted_results
          |> Enum.flat_map(fn {group, index} ->
            group_id = "GROUP_#{index}"
            parent = List.first(group.keywords, "")

            group.keywords
            |> Enum.map(fn keyword ->
              {keyword, {group_id, parent}}
            end)
          end)
          |> Map.new()

        # Generate rows in original keyword order
        rows =
          original_order
          |> Enum.map(fn keyword ->
            case Map.get(keyword_to_group, keyword) do
              {group_id, parent} -> [keyword, group_id, parent]
              nil -> [keyword, "UNGROUPED", ""]
            end
          end)
          |> then(fn rows -> [["Keyword", "Group", "Parent"] | rows] end)

        # Generate spreadsheet name
        timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))

        sanitized_project_name =
          if project_name == "" do
            "keyword_grouping"
          else
            project_name
            |> String.trim()
            |> String.replace(~r/[^\w\s-]/, "")
            |> String.replace(~r/\s+/, "_")
          end

        spreadsheet_name = "#{sanitized_project_name}_#{timestamp}"

        # Export to Google Sheets in async task
        pid = self()

        Task.start(fn ->
          result =
            case Cachex.get(:cache, :reports_folder_id) do
              {:ok, folder_id} when is_binary(folder_id) ->
                conn = Levanngoc.External.GoogleDrive.get_conn()

                case Levanngoc.External.GoogleDrive.export_to_spreadsheet(
                       conn,
                       folder_id,
                       spreadsheet_name,
                       rows
                     ) do
                  {:ok, %{spreadsheet_id: spreadsheet_id}} ->
                    spreadsheet_url =
                      "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit"

                    {:ok, spreadsheet_url}

                  {:error, reason} ->
                    {:error, reason}
                end

              _ ->
                {:error, :no_folder}
            end

          send(pid, {:sheets_export_complete, result})
        end)

        {:noreply, socket}
      end
    end
  end

  @impl true

  def handle_info({:processing_complete, uploaded_files}, socket) do
    # uploaded_files is a list of {path, results}
    # We aggregate results from all files (though max_entries is 1)

    all_results =
      uploaded_files
      |> Enum.flat_map(fn {_path, results} -> results end)

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

    {:noreply,
     socket
     |> assign(:is_processing, false)
     |> assign(:grouping_results, all_results)
     |> assign(:processing_time, processing_time)
     |> assign(:exported_sheets_url, nil)
     |> assign(:show_result_modal, true)}
  end

  def handle_info({:sheets_export_complete, result}, socket) do
    case result do
      {:ok, spreadsheet_url} ->
        {:noreply,
         socket
         |> assign(:is_exporting_sheets, false)
         |> assign(:exported_sheets_url, spreadsheet_url)
         |> push_event("open-url", %{url: spreadsheet_url})}

      {:error, :no_folder} ->
        {:noreply,
         socket
         |> assign(:is_exporting_sheets, false)
         |> put_flash(:error, "Không tìm thấy thư mục báo cáo. Vui lòng thử lại sau.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:is_exporting_sheets, false)
         |> put_flash(:error, "Xuất Google Sheets thất bại. Vui lòng thử lại.")}
    end
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  # Keyword grouping logic based on SERP overlap
  defp group_keywords(keywords, api_key, similarity_threshold) do
    # Step 1: Scrape SERP data for all keywords
    scraping_dog =
      %Levanngoc.External.ScrapingDog{}
      |> Levanngoc.External.ScrapingDog.put_apikey(api_key)

    serp_data =
      keywords
      |> Task.async_stream(
        fn keyword ->
          results =
            try do
              Levanngoc.External.ScrapingDog.scrape_serp_for_grouping(scraping_dog, keyword)
            rescue
              _e ->
                []
            end

          {keyword, results}
        end,
        max_concurrency: 20,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Map.new()

    # Step 2: Calculate required common links based on threshold
    # Assuming max 10 organic results from ScrapingDog
    estimated_max_results = 10
    required_common_links = round(similarity_threshold * estimated_max_results)
    required_common_links = if required_common_links == 0, do: 1, else: required_common_links

    # Step 3: Group keywords using BFS algorithm
    {groups, _} =
      keywords
      |> Enum.reduce({[], MapSet.new()}, fn keyword, {groups_acc, processed} ->
        if MapSet.member?(processed, keyword) do
          {groups_acc, processed}
        else
          # Start a new group with this keyword as seed
          {group_keywords, new_processed} =
            bfs_group_keywords(
              [keyword],
              MapSet.new(),
              keywords,
              processed,
              serp_data,
              required_common_links
            )

          group_id = length(groups_acc) + 1

          group = %{
            group_name: "Nhóm #{group_id}",
            keywords: group_keywords,
            count: length(group_keywords)
          }

          {[group | groups_acc], new_processed}
        end
      end)

    Enum.reverse(groups)
  end

  # BFS algorithm to find all related keywords
  @spec bfs_group_keywords(
          list(String.t()),
          MapSet.t(String.t()),
          list(String.t()),
          MapSet.t(String.t()),
          map(),
          integer()
        ) :: {list(String.t()), MapSet.t(String.t())}
  defp bfs_group_keywords(queue, group_keywords, all_keywords, processed, serp_data, threshold) do
    case queue do
      [] ->
        {Enum.to_list(group_keywords), processed}

      [seed_keyword | rest_queue] ->
        if MapSet.member?(processed, seed_keyword) do
          bfs_group_keywords(
            rest_queue,
            group_keywords,
            all_keywords,
            processed,
            serp_data,
            threshold
          )
        else
          # Add seed to group and mark as processed
          group_keywords = MapSet.put(group_keywords, seed_keyword)
          processed = MapSet.put(processed, seed_keyword)

          # Get SERP links for seed keyword
          seed_links = get_serp_links(serp_data, seed_keyword)

          if MapSet.size(seed_links) == 0 do
            bfs_group_keywords(
              rest_queue,
              group_keywords,
              all_keywords,
              processed,
              serp_data,
              threshold
            )
          else
            # Find related keywords using Task.async_stream for parallel processing
            candidates =
              all_keywords
              |> Enum.filter(fn candidate ->
                not MapSet.member?(processed, candidate)
              end)

            related_keywords =
              candidates
              |> Task.async_stream(
                fn candidate ->
                  candidate_links = get_serp_links(serp_data, candidate)

                  if MapSet.size(candidate_links) == 0 do
                    {candidate, false}
                  else
                    common_links = MapSet.intersection(seed_links, candidate_links)
                    num_common = MapSet.size(common_links)

                    if num_common >= threshold do
                      {candidate, true}
                    else
                      {candidate, false}
                    end
                  end
                end,
                max_concurrency: 20,
                timeout: :infinity
              )
              |> Enum.map(fn {:ok, result} -> result end)
              |> Enum.filter(fn {_candidate, is_related} -> is_related end)
              |> Enum.map(fn {candidate, _is_related} -> candidate end)

            # Add related keywords to queue
            new_queue = rest_queue ++ related_keywords

            bfs_group_keywords(
              new_queue,
              group_keywords,
              all_keywords,
              processed,
              serp_data,
              threshold
            )
          end
        end
    end
  end

  # Extract links from SERP data for a keyword
  defp get_serp_links(serp_data, keyword) do
    case Map.get(serp_data, keyword) do
      nil ->
        MapSet.new()

      results ->
        results
        |> Enum.map(fn result -> Map.get(result, :link) end)
        |> Enum.filter(fn link -> link != nil end)
        |> MapSet.new()
    end
  end

  defp generate_xlsx(results, original_keyword_order, project_name) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))

    # Create filename from project name and timestamp
    sanitized_project_name =
      if project_name == "" do
        "keyword_grouping"
      else
        project_name
        |> String.trim()
        |> String.replace(~r/[^\w\s-]/, "")
        |> String.replace(~r/\s+/, "_")
      end

    filename = "#{sanitized_project_name}_#{timestamp}.xlsx"

    # Sort groups by size (descending) to assign GROUP_X numbers
    sorted_results =
      results
      |> Enum.sort_by(fn group -> {-group.count, group.group_name} end)
      |> Enum.with_index(1)

    # Create a mapping of keyword -> {group_id, parent}
    keyword_to_group =
      sorted_results
      |> Enum.flat_map(fn {group, index} ->
        group_id = "GROUP_#{index}"
        parent = List.first(group.keywords, "")

        group.keywords
        |> Enum.map(fn keyword ->
          {keyword, {group_id, parent}}
        end)
      end)
      |> Map.new()

    # Generate rows in original keyword order
    rows =
      original_keyword_order
      |> Enum.map(fn keyword ->
        case Map.get(keyword_to_group, keyword) do
          {group_id, parent} -> [keyword, group_id, parent]
          nil -> [keyword, "UNGROUPED", ""]
        end
      end)

    sheet = [["Keyword", "Group", "Parent"] | rows]

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

  defp generate_csv(results, original_keyword_order, project_name) do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))

    # Create filename from project name and timestamp
    sanitized_project_name =
      if project_name == "" do
        "keyword_grouping"
      else
        project_name
        |> String.trim()
        |> String.replace(~r/[^\w\s-]/, "")
        |> String.replace(~r/\s+/, "_")
      end

    filename = "#{sanitized_project_name}_#{timestamp}.csv"

    # Sort groups by size (descending) to assign GROUP_X numbers
    sorted_results =
      results
      |> Enum.sort_by(fn group -> {-group.count, group.group_name} end)
      |> Enum.with_index(1)

    # Create a mapping of keyword -> {group_id, parent}
    keyword_to_group =
      sorted_results
      |> Enum.flat_map(fn {group, index} ->
        group_id = "GROUP_#{index}"
        parent = List.first(group.keywords, "")

        group.keywords
        |> Enum.map(fn keyword ->
          {keyword, {group_id, parent}}
        end)
      end)
      |> Map.new()

    # Create CSV content
    header = "Keyword,Group,Parent\n"

    # Generate rows in original keyword order
    rows =
      original_keyword_order
      |> Enum.map(fn keyword ->
        case Map.get(keyword_to_group, keyword) do
          {group_id, parent} -> "\"#{keyword}\",\"#{group_id}\",\"#{parent}\"\n"
          nil -> "\"#{keyword}\",\"UNGROUPED\",\"\"\n"
        end
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
        <div class="card-body flex flex-col p-4">
          <form phx-change="validate" phx-submit="save" class="flex flex-col flex-1">
            <div class="flex gap-4 mb-4">
              <div class="form-control w-[80%]">
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

              <div class="form-control w-[20%]">
                <label class="label mb-2">
                  <span class="label-text">Ngưỡng độ tương đồng</span>
                </label>
                <input
                  type="number"
                  step="0.1"
                  min="0.1"
                  max="1.0"
                  class="input w-full rounded-lg"
                  placeholder="Nhập ngưỡng độ tương đồng (0.1 - 1.0)"
                  value={@similarity_threshold}
                  phx-change="update_similarity_threshold"
                  name="similarity_threshold"
                  disabled={!@is_logged_in or @is_processing}
                />
              </div>
            </div>

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

            <div class="mt-4 flex justify-end items-center">
              <button
                type="submit"
                class="btn btn-primary min-w-[160px]"
                disabled={!@is_logged_in or @is_processing or @keywords_input == ""}
              >
                <%= if @is_processing do %>
                  <span class="loading loading-spinner"></span>
                <% else %>
                  Gom nhóm
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

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
                  {number_to_delimited(@cost_details.token_usage_per_keyword, precision: 0)} token<%= if @cost_details.token_usage_per_keyword >
                    1 do %>
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
              <button class="btn btn-primary" phx-click="cancel_grouping">Đã hiểu!</button>
            <% else %>
              <button class="btn" phx-click="cancel_grouping">Hủy bỏ</button>
              <button class="btn btn-primary" phx-click="confirm_grouping">
                Xác nhận & Tiếp tục
              </button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-4xl relative z-50 overflow-visible">
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
                  <div class="divider my-0"></div>
                  <li class={@is_exporting_sheets && "disabled"}>
                    <button phx-click="export_google_sheets" disabled={@is_exporting_sheets}>
                      <%= cond do %>
                        <% @is_exporting_sheets -> %>
                          <span class="loading loading-spinner loading-sm"></span> Đang xuất...
                        <% @exported_sheets_url -> %>
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke-width="1.5"
                            stroke="currentColor"
                            class="size-4"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                            />
                          </svg>
                          Google Sheets
                        <% true -> %>
                          Google Sheets
                      <% end %>
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
