defmodule LevanngocWeb.BacklinkCheckerLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra Backlink")
     |> assign(:thread_count, 16)
     |> assign(:domain, "")
     |> assign(:url_list, "")
     |> assign(:show_result_modal, false)
     |> assign(:results, [])
     |> assign(:max_anchor_count, 0)
     |> assign(:is_exporting_sheets, false)
     |> assign(:exported_sheets_url, nil)
     |> assign(:is_processing, false)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_domain", %{"domain" => domain}, socket) do
    {:noreply, assign(socket, :domain, domain)}
  end

  @impl true
  def handle_event("update_url_list", %{"url_list" => url_list}, socket) do
    {:noreply, assign(socket, :url_list, url_list)}
  end

  @impl true
  def handle_event("check_backlinks", _params, socket) do
    urls_text = socket.assigns.url_list
    target_domain_input = socket.assigns.domain
    max_workers = socket.assigns.thread_count
    parent = self()

    if urls_text != "" and target_domain_input != "" do
      # Set processing flag
      socket = assign(socket, :is_processing, true)

      Task.start(fn ->
        urls =
          urls_text
          |> String.split("\n")
          |> Stream.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          |> Enum.with_index(1)

        # Ensure domain is in correct format or extracting host if full URL passed
        # Python logic: extract_domain(url) -> parsed.netloc
        # But here input is just "domain". If user enters "https://domain.com", we should extract host.
        # If user enters "domain.com", clean_url adds https://, then extract host.
        target_domain = extract_domain(clean_url(target_domain_input))

        # Use Task.async_stream for multi-threading
        results =
          urls
          |> Task.async_stream(
            fn {url, idx} ->
              check_single_url(url, target_domain, idx)
            end,
            max_concurrency: max_workers,
            timeout: 60_000
          )
          |> Enum.map(fn
            {:ok, result} -> result
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.stt)

        # Calculate max anchor count
        max_anchor_count = calculate_max_anchor_count(results)

        # Send results to LiveView
        send(parent, {:backlink_results, results, max_anchor_count})
      end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_result_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("download", %{"format" => format}, socket) do
    results = socket.assigns.results
    max_anchor_count = socket.assigns.max_anchor_count

    {content, filename} =
      case format do
        "xlsx" ->
          generate_xlsx(results, max_anchor_count)

        "csv" ->
          generate_csv(results, max_anchor_count)
      end

    {:noreply,
     push_event(socket, "download-file", %{
       content: Base.encode64(content),
       filename: filename
     })}
  end

  @impl true
  def handle_event("export_google_sheets", _params, socket) do
    cond do
      socket.assigns.is_exporting_sheets ->
        {:noreply, socket}

      socket.assigns.exported_sheets_url ->
        {:noreply, push_event(socket, "open-url", %{url: socket.assigns.exported_sheets_url})}

      true ->
        socket = assign(socket, :is_exporting_sheets, true)
        rows = prepare_export_rows(socket.assigns.results, socket.assigns.max_anchor_count)
        spreadsheet_name = generate_spreadsheet_name()

        start_google_sheets_export(rows, spreadsheet_name)

        {:noreply, socket}
    end
  end

  defp prepare_export_rows(results, max_anchor_count) do
    build_export_data(results, max_anchor_count)
  end

  defp generate_spreadsheet_name do
    timestamp = format_timestamp(to_ho_chi_minh_time(DateTime.utc_now()))
    "backlink_check_#{timestamp}"
  end

  defp start_google_sheets_export(rows, spreadsheet_name) do
    parent = self()

    Task.start(fn ->
      result =
        with {:ok, folder_id} <- Cachex.get(:cache, :reports_folder_id),
             true <- folder_id != nil,
             conn <- Levanngoc.External.GoogleDrive.get_conn(),
             {:ok, %{spreadsheet_id: spreadsheet_id}} <-
               Levanngoc.External.GoogleDrive.export_to_spreadsheet(
                 conn,
                 folder_id,
                 spreadsheet_name,
                 rows
               ) do
          {:ok, "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}"}
        else
          {:ok, nil} -> {:error, :no_folder}
          {:error, reason} -> {:error, reason}
          false -> {:error, :no_folder}
        end

      send(parent, {:sheets_export_complete, result})
    end)
  end

  @impl true
  def handle_info({:backlink_results, results, max_anchor_count}, socket) do
    {:noreply,
     socket
     |> assign(:results, results)
     |> assign(:max_anchor_count, max_anchor_count)
     |> assign(:is_processing, false)
     |> assign(:show_result_modal, true)
     |> assign(:exported_sheets_url, nil)}
  end

  @impl true
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
         |> put_flash(:error, "Có lỗi xảy ra khi xuất Google Sheets. Vui lòng thử lại.")}
    end
  end

  defp calculate_max_anchor_count([]), do: 0

  defp calculate_max_anchor_count(results) do
    results
    |> Enum.map(fn result ->
      result
      |> Map.drop([:stt, :url])
      |> map_size()
    end)
    |> Enum.max()
  end

  defp check_single_url(url, target_domain, idx) do
    clean_url = clean_url(url)

    headers = [
      {"User-Agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"}
    ]

    try do
      # Python request timeout=10
      options = [follow_redirect: true, max_redirects: 5, recv_timeout: 10_000]

      case HTTPoison.get(clean_url, headers, options) do
        {:ok, %HTTPoison.Response{body: body}} ->
          # Process body regardless of status code if body exists, similar to Python script
          parse_anchors(body, target_domain, clean_url, idx)

        {:error, _reason} ->
          nil
      end
    rescue
      _ -> nil
    end
  end

  defp parse_anchors(html, target_domain, url, idx) do
    with {:ok, document} <- Floki.parse_document(html),
         anchors when anchors != [] <- extract_matching_anchors(document, target_domain) do
      build_result(idx, url, anchors)
    else
      _ -> nil
    end
  end

  defp extract_matching_anchors(document, target_domain) do
    document
    |> Floki.find("a[href]")
    |> Enum.reduce([], fn {_, attrs, children}, acc ->
      case List.keyfind(attrs, "href", 0) do
        {"href", href} when is_binary(href) ->
          if String.contains?(href, target_domain) do
            case Floki.text(children) |> String.trim() do
              "" -> acc
              text -> [text | acc]
            end
          else
            acc
          end

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp build_result(idx, url, anchor_texts) do
    anchor_map =
      anchor_texts
      |> Enum.with_index(1)
      |> Map.new(fn {text, i} -> {:"anchor_text_#{i}", text} end)

    Map.merge(%{stt: idx, url: url}, anchor_map)
  end

  defp clean_url(url) do
    case String.trim(url) do
      "http://" <> _ = url -> url
      "https://" <> _ = url -> url
      url -> "https://#{url}"
    end
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when not is_nil(host) -> host
      _ -> url
    end
  end

  defp generate_xlsx(results, max_anchor_count) do
    timestamp = format_timestamp(DateTime.utc_now())
    filename = "backlink_check_#{timestamp}.xlsx"
    all_rows = build_export_data(results, max_anchor_count)

    workbook = %Elixlsx.Workbook{
      sheets: [
        %Elixlsx.Sheet{
          name: "Backlink Results",
          rows: all_rows
        }
      ]
    }

    {:ok, {_filename, content}} = Elixlsx.write_to_memory(workbook, filename)

    {content, filename}
  end

  defp generate_csv(results, max_anchor_count) do
    timestamp = format_timestamp(DateTime.utc_now())
    filename = "backlink_check_#{timestamp}.csv"
    [header_row | data_rows] = build_export_data(results, max_anchor_count)

    header = Enum.map(header_row, &"\"#{&1}\"") |> Enum.join(",")

    rows =
      Enum.map(data_rows, fn row ->
        Enum.map(row, &"\"#{&1}\"") |> Enum.join(",")
      end)
      |> Enum.join("\n")

    content = header <> "\n" <> rows

    {content, filename}
  end

  defp build_export_data(results, max_anchor_count) do
    header = ["STT", "URL Kiểm tra"] ++ Enum.map(1..max_anchor_count, &"Anchor Text #{&1}")

    data_rows =
      Enum.map(results, fn result ->
        [result.stt, result.url] ++
          Enum.map(1..max_anchor_count, &Map.get(result, :"anchor_text_#{&1}", ""))
      end)

    [header | data_rows]
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: "#{num}"

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Kiểm tra Backlink</h1>

      <div class="card bg-base-100 shadow-xl border border-base-300 flex-1 flex flex-col">
        <div class="card-body p-4 flex flex-col flex-1">
          <form phx-change="validate" phx-submit="check_backlinks" class="flex flex-col flex-1">
            <!-- Domain input -->
            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">Domain cần kiểm tra</span>
              </label>
              <input
                type="text"
                class="input input-bordered w-full"
                placeholder="Ví dụ: example.com"
                name="domain"
                value={@domain}
                phx-change="update_domain"
                disabled={@is_processing}
              />
            </div>
            
    <!-- Second row: URL list textarea -->
            <div class="form-control flex-1 flex flex-col mb-4">
              <label class="label">
                <span class="label-text">Danh sách URL (mỗi URL một dòng)</span>
              </label>
              <textarea
                class="textarea textarea-bordered flex-1 resize-none w-full"
                placeholder="https://example.com/page1&#10;https://example.com/page2&#10;https://example.com/page3"
                name="url_list"
                phx-change="update_url_list"
                disabled={@is_processing}
              >{@url_list}</textarea>
            </div>
            
    <!-- Third row: Check button (right-aligned) -->
            <div class="flex justify-end">
              <button
                type="submit"
                class="btn btn-primary min-w-[160px]"
                disabled={@domain == "" || @url_list == "" || @is_processing}
              >
                <%= if @is_processing do %>
                  <span class="loading loading-spinner"></span>
                <% else %>
                  Kiểm tra
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-[95vw] w-full h-[90vh] flex flex-col">
          <div class="flex justify-between items-center mb-4">
            <h3 class="font-bold text-lg">Kết quả kiểm tra Backlink</h3>
            <button
              type="button"
              class="btn btn-sm btn-ghost btn-circle"
              phx-click="close_result_modal"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <div class="overflow-auto flex-1 border border-base-300 rounded-lg">
            <table class="table table-zebra table-pin-rows table-pin-cols w-full">
              <thead>
                <tr class="bg-base-200">
                  <th class="border-r border-base-300 font-bold text-center w-20">STT</th>
                  <th class="border-r border-base-300 font-bold min-w-[300px]">URL Kiểm tra</th>
                  <%= for i <- 1..@max_anchor_count do %>
                    <th class="border-r border-base-300 font-bold min-w-[200px]">Anchor Text {i}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <%= for result <- @results do %>
                  <tr class="hover">
                    <td class="border-r border-base-300 text-center font-medium">{result.stt}</td>
                    <td class="border-r border-base-300">
                      <div class="tooltip tooltip-right" data-tip={result.url}>
                        <div class="truncate max-w-[400px]">{result.url}</div>
                      </div>
                    </td>
                    <%= for i <- 1..@max_anchor_count do %>
                      <td class="border-r border-base-300">
                        {Map.get(result, :"anchor_text_#{i}", "")}
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="modal-action justify-between mt-4">
            <div class="dropdown dropdown-top">
              <label tabindex="0" class="btn btn-success">
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
                Xuất kết quả
              </label>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52 mb-2"
              >
                <li>
                  <button type="button" phx-click="download" phx-value-format="xlsx">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="w-4 h-4"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                      />
                    </svg>
                    Tải xuống Excel (.xlsx)
                  </button>
                </li>
                <li>
                  <button type="button" phx-click="download" phx-value-format="csv">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="w-4 h-4"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12l3-3m0 0l-3-3m3 3H2.25"
                      />
                    </svg>
                    Tải xuống CSV (.csv)
                  </button>
                </li>
                <div class="divider my-0"></div>
                <li class={@is_exporting_sheets && "disabled"}>
                  <button
                    type="button"
                    phx-click="export_google_sheets"
                    disabled={@is_exporting_sheets}
                  >
                    <%= cond do %>
                      <% @is_exporting_sheets -> %>
                        <span class="loading loading-spinner loading-sm"></span> Đang xuất...
                      <% @exported_sheets_url -> %>
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                          class="w-4 h-4"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                            clip-rule="evenodd"
                          />
                        </svg>
                        Google Sheets
                      <% true -> %>
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="w-4 h-4"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375m9.75-12.75c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125m19.5 0v1.5c0 .621-.504 1.125-1.125 1.125M2.25 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h17.25m-17.25 0h7.5c.621 0 1.125.504 1.125 1.125M3.375 8.25c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m17.25-3.75h-7.5c-.621 0-1.125.504-1.125 1.125m8.625-1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125M12 10.875v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125M13.125 12h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125M20.625 12c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5M12 14.625v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 14.625c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m0 1.5v-1.5m0 0c0-.621.504-1.125 1.125-1.125m0 0h7.5"
                          />
                        </svg>
                        Google Sheets
                    <% end %>
                  </button>
                </li>
              </ul>
            </div>

            <button type="button" class="btn" phx-click="close_result_modal">Đóng</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
      </div>
    <% end %>
    """
  end
end
