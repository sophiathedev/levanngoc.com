defmodule LevanngocWeb.CheckKeywordCannibalizationLive.Index do
  use LevanngocWeb, :live_view

  require Logger

  alias Levanngoc.KeywordCannibalization.{Sitemap, HtmlParser, PageData, Scorer}
  alias Levanngoc.External.{ScrapingDog, GoogleDrive}
  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  # Configuration
  @max_urls_to_crawl 10000
  @max_internal_links 100
  @crawl_concurrency 40
  @keyword_scraping_concurrency 30
  @results_dir "priv/crawl_results"

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra Ăn thịt từ khóa")
     |> assign(:domain_input, "")
     |> assign(:result_limit, 20)
     |> assign(:is_edit_mode, true)
     |> assign(:manual_keywords, "")
     |> assign(:checking, false)
     |> assign(:result_file, nil)
     |> assign(:error_message, nil)
     |> assign(:current_page, 1)
     |> assign(:per_page, 20)
     |> assign(:cannibalization_results, [])
     |> assign(:show_result_modal, false)
     |> assign(:selected_keyword_index, 0)
     |> assign(:user_email, Map.get(session, "user_email", "anonymous"))
     |> assign(:session_id, Map.get(session, "session_id", "unknown"))
     |> allow_upload(:file,
       accept: ~w(.xlsx .csv .txt),
       max_entries: 1,
       max_file_size: 32_000_000
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_domain", %{"value" => value}, socket) do
    {:noreply, assign(socket, :domain_input, String.trim(value))}
  end

  @impl true
  def handle_event("select_limit", %{"limit" => limit_str}, socket) do
    limit = String.to_integer(limit_str)
    {:noreply, assign(socket, :result_limit, limit)}
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
  def handle_event("update_manual_keywords", %{"keywords" => keywords}, socket) do
    {:noreply, assign(socket, :manual_keywords, keywords)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  @impl true
  def handle_event("close_result_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("open_result_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, true)}
  end

  @impl true
  def handle_event("select_keyword", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, :selected_keyword_index, index)}
  end

  @impl true
  def handle_event("export_to_xlsx", _params, socket) do
    results = socket.assigns.cannibalization_results
    domain = socket.assigns.domain_input

    # Generate XLSX file
    filename =
      "keyword_cannibalization_#{sanitize_filename(domain)}_#{System.system_time(:second)}.xlsx"

    file_path = Path.join(System.tmp_dir!(), filename)

    case generate_xlsx(results, file_path) do
      :ok ->
        # Read file and send to client
        file_content = File.read!(file_path)
        File.rm(file_path)

        {:noreply,
         socket
         |> push_event("download-file", %{
           filename: filename,
           content: Base.encode64(file_content)
         })}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] XLSX_EXPORT_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Error: #{inspect(reason)}"
        )

        {:noreply, put_flash(socket, :error, "Không thể tạo file Excel")}
    end
  end

  @impl true
  def handle_event("export_to_google_sheet", _params, socket) do
    results = socket.assigns.cannibalization_results
    domain = socket.assigns.domain_input

    case export_to_google_sheets(results, domain) do
      {:ok, sheet_url} ->
        {:noreply,
         socket
         |> put_flash(:info, "Đã tạo Google Sheet thành công!")
         |> push_event("open-url", %{url: sheet_url})}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] GOOGLE_SHEETS_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Error: #{inspect(reason)}"
        )

        {:noreply, put_flash(socket, :error, "Không thể tạo Google Sheet: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("check_cannibalization", _params, socket) do
    domain = socket.assigns.domain_input

    # Log start
    Logger.info(
      "[KEYWORD_CANNIBALIZATION] START - User: #{socket.assigns.user_email}, Domain: #{domain}, Session: #{socket.assigns.session_id}, Time: #{DateTime.utc_now()}"
    )

    case validate_inputs(domain, []) do
      :ok ->
        result_file = generate_result_file_path(domain)
        send(self(), {:start_crawl, domain, result_file})

        {:noreply,
         socket
         |> assign(:checking, true)
         |> assign(:result_file, result_file)
         |> assign(:error_message, nil)
         |> assign(:show_result_modal, false)
         |> assign(:start_time, DateTime.utc_now())}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Reason: #{reason}"
        )

        {:noreply, assign(socket, :error_message, reason)}
    end
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    # Delete file if exists
    if socket.assigns.result_file && File.exists?(socket.assigns.result_file) do
      File.rm(socket.assigns.result_file)
    end

    {:noreply,
     socket
     |> assign(:domain_input, "")
     |> assign(:manual_keywords, "")
     |> assign(:result_file, nil)
     |> assign(:error_message, nil)
     |> assign(:cannibalization_results, [])
     |> assign(:show_result_modal, false)
     |> assign(:current_page, 1)}
  end

  @impl true
  def handle_event("goto_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    {:noreply, assign(socket, :current_page, page)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    results = read_results_from_file(socket.assigns.result_file)
    total_pages = calculate_total_pages(results, socket.assigns.per_page)
    current_page = socket.assigns.current_page

    if current_page < total_pages do
      {:noreply, assign(socket, :current_page, current_page + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    current_page = socket.assigns.current_page

    if current_page > 1 do
      {:noreply, assign(socket, :current_page, current_page - 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:start_crawl, domain, result_file}, socket) do
    normalized_domain = HtmlParser.normalize_domain(domain)
    base_domain = HtmlParser.get_base_domain(normalized_domain)

    # Initialize empty JSON file
    write_results_to_file(result_file, [])

    # Step 1: Crawl sitemap
    case Sitemap.discover(normalized_domain) do
      {:ok, urls} ->
        # Limit URLs to prevent overload
        limited_urls = Enum.take(urls, @max_urls_to_crawl)

        send(self(), {:crawl_urls, limited_urls, base_domain, result_file})

        {:noreply, socket}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] SITEMAP_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Domain: #{domain}, Error: #{inspect(reason)}"
        )

        {:noreply,
         socket
         |> assign(:checking, false)
         |> assign(:error_message, "Không thể tìm thấy sitemap cho domain này")}
    end
  end

  @impl true
  def handle_info({:crawl_urls, urls, base_domain, result_file}, socket) do
    # Crawl URLs concurrently with 40 workers
    _results =
      urls
      |> Task.async_stream(
        fn url ->
          result = crawl_single_url(url, base_domain)

          # Save to JSON file immediately after each URL is crawled
          if match?({:ok, _}, result) do
            {:ok, page_data} = result
            append_result_to_file(result_file, page_data)
          end

          result
        end,
        max_concurrency: @crawl_concurrency,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    # Schedule cleanup job for 2 hours later
    Levanngoc.Jobs.CrawlCleanup.schedule_cleanup(result_file)

    # Parse keywords and start scraping if keywords exist
    keywords =
      socket.assigns.manual_keywords
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if length(keywords) > 0 do
      send(
        self(),
        {:scrape_keywords, keywords, socket.assigns.domain_input, socket.assigns.result_limit}
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, :checking, false)}
    end
  end

  @impl true
  def handle_info({:scrape_keywords, keywords, domain, max_results}, socket) do
    # Get ScrapingDog API key from AdminSetting
    admin_setting = Repo.all(AdminSetting)

    case admin_setting do
      [%AdminSetting{scraping_dog_api_key: api_key} | _]
      when is_binary(api_key) and api_key != "" ->
        # Initialize ScrapingDog client
        scraping_dog =
          %ScrapingDog{}
          |> ScrapingDog.put_apikey(api_key)

        # Scrape keywords concurrently with 30 workers
        results =
          keywords
          |> Task.async_stream(
            fn keyword ->
              try do
                urls = ScrapingDog.scraping_cannibal(scraping_dog, domain, keyword, max_results)
                {keyword, {:ok, urls}}
              rescue
                e ->
                  {keyword, {:error, inspect(e)}}
              end
            end,
            max_concurrency: @keyword_scraping_concurrency,
            timeout: 60_000,
            on_timeout: :kill_task
          )
          |> Enum.to_list()

        # Load crawled data from result_file
        crawled_data = read_results_from_file(socket.assigns.result_file)

        # Score each keyword based on cannibalization criteria
        cannibalization_results =
          results
          |> Enum.with_index()
          |> Enum.reduce([], fn
            {{:ok, {keyword, {:ok, urls}}}, _idx}, acc ->
              cond do
                # No URLs found
                length(urls) == 0 ->
                  result = %{
                    keyword: keyword,
                    score: 0,
                    urls: [],
                    details: %{
                      base_score: 0,
                      title_h1_similarity: 0.0,
                      same_page_type: false,
                      anchor_text_conflicts: 0
                    },
                    visualization: %{
                      percentage: 0.0,
                      circumference: Float.round(2.0 * 3.14159 * 70.0, 2),
                      stroke_dashoffset: Float.round(2.0 * 3.14159 * 70.0, 2)
                    },
                    status: :no_results
                  }

                  [result | acc]

                # Only 1 URL found - no cannibalization
                length(urls) == 1 ->
                  result = %{
                    keyword: keyword,
                    score: 0,
                    urls: urls,
                    details: %{
                      base_score: 0,
                      title_h1_similarity: 0.0,
                      same_page_type: false,
                      anchor_text_conflicts: 0
                    },
                    visualization: %{
                      percentage: 0.0,
                      circumference: Float.round(2.0 * 3.14159 * 70.0, 2),
                      stroke_dashoffset: Float.round(2.0 * 3.14159 * 70.0, 2)
                    },
                    status: :safe
                  }

                  [result | acc]

                # 2+ URLs - potential cannibalization
                true ->
                  case Scorer.score_keyword(keyword, urls, crawled_data) do
                    nil ->
                      # Thay vì bỏ qua, tạo một kết quả no_results
                      result = %{
                        keyword: keyword,
                        score: 0,
                        urls: urls,
                        details: %{
                          base_score: 0,
                          title_h1_similarity: 0.0,
                          same_page_type: false,
                          anchor_text_conflicts: 0
                        },
                        visualization: %{
                          percentage: 0.0,
                          circumference: Float.round(2.0 * 3.14159 * 70.0, 2),
                          stroke_dashoffset: Float.round(2.0 * 3.14159 * 70.0, 2)
                        },
                        status: :no_results
                      }

                      [result | acc]

                    score_result ->
                      result_with_status = Map.put(score_result, :status, :cannibalization)
                      [result_with_status | acc]
                  end
              end

            {{:ok, {keyword, {:error, reason}}}, _idx}, acc ->
              result = %{
                keyword: keyword,
                score: 0,
                urls: [],
                details: %{
                  base_score: 0,
                  title_h1_similarity: 0.0,
                  same_page_type: false,
                  anchor_text_conflicts: 0
                },
                visualization: %{
                  percentage: 0.0,
                  circumference: Float.round(2.0 * 3.14159 * 70.0, 2),
                  stroke_dashoffset: Float.round(2.0 * 3.14159 * 70.0, 2)
                },
                status: :error,
                error_message: reason
              }

              [result | acc]

            {{:exit, reason}, _idx}, acc ->
              # Add a placeholder result for timeout
              result = %{
                keyword: "Unknown (timeout)",
                score: 0,
                urls: [],
                details: %{
                  base_score: 0,
                  title_h1_similarity: 0.0,
                  same_page_type: false,
                  anchor_text_conflicts: 0
                },
                visualization: %{
                  percentage: 0.0,
                  circumference: Float.round(2.0 * 3.14159 * 70.0, 2),
                  stroke_dashoffset: Float.round(2.0 * 3.14159 * 70.0, 2)
                },
                status: :error,
                error_message: "Task timeout: #{inspect(reason)}"
              }

              [result | acc]

            {_other, _idx}, acc ->
              acc
          end)
          |> Enum.sort_by(& &1.keyword)

        cannibalization_count =
          Enum.count(cannibalization_results, fn r -> r.status == :cannibalization end)

        # Log end
        duration = DateTime.diff(DateTime.utc_now(), socket.assigns.start_time, :second)

        Logger.info(
          "[KEYWORD_CANNIBALIZATION] END - User: #{socket.assigns.user_email}, Domain: #{domain}, Total Keywords: #{length(cannibalization_results)}, Cannibalization Found: #{cannibalization_count}, Duration: #{duration}s, Time: #{DateTime.utc_now()}"
        )

        {:noreply,
         socket
         |> assign(:checking, false)
         |> assign(:cannibalization_results, cannibalization_results)
         |> assign(:show_result_modal, true)
         |> assign(:selected_keyword_index, 0)}

      _ ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] API_KEY_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Error: ScrapingDog API key not configured"
        )

        {:noreply, assign(socket, :checking, false)}
    end
  end

  defp validate_inputs(domain, _keywords) do
    if domain == "" do
      {:error, "Vui lòng nhập domain"}
    else
      :ok
    end
  end

  defp crawl_single_url(url, base_domain) do
    case HtmlParser.fetch_and_parse(url, base_domain: base_domain) do
      {:ok, page_data} ->
        # Limit internal links to save memory
        limited_page_data = limit_internal_links(page_data)
        {:ok, limited_page_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp limit_internal_links(%PageData{internal_links: links} = page_data)
       when length(links) > @max_internal_links do
    limited_links = Enum.take(links, @max_internal_links)
    %{page_data | internal_links: limited_links}
  end

  defp limit_internal_links(page_data), do: page_data

  defp calculate_total_pages([], _per_page), do: 1

  defp calculate_total_pages(results, per_page) do
    ceil(length(results) / per_page)
  end

  defp paginate_results(results, page, per_page) do
    start_index = (page - 1) * per_page
    Enum.slice(results, start_index, per_page)
  end

  defp generate_result_file_path(domain) do
    timestamp = System.system_time(:second)
    sanitized_domain = String.replace(domain, ~r/[^a-zA-Z0-9-]/, "_")
    filename = "crawl_#{sanitized_domain}_#{timestamp}.json"
    Path.join(@results_dir, filename)
  end

  defp write_results_to_file(file_path, results) do
    File.mkdir_p!(Path.dirname(file_path))

    json_data = Jason.encode!(results)
    File.write!(file_path, json_data)
  end

  defp append_result_to_file(file_path, page_data) do
    # Read current results
    current_results = read_results_from_file(file_path)

    # Convert PageData struct to map for JSON encoding
    page_map = %{
      url: page_data.url,
      title: page_data.title,
      h1: page_data.h1,
      description: page_data.description,
      canonical_url: page_data.canonical_url,
      internal_links:
        Enum.map(page_data.internal_links, fn link ->
          %{
            target_url: link.target_url,
            anchor_text: link.anchor_text
          }
        end)
    }

    # Append new result
    updated_results = current_results ++ [page_map]

    # Write back to file
    write_results_to_file(file_path, updated_results)
  end

  defp read_results_from_file(nil), do: []

  defp read_results_from_file(file_path) do
    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, results} -> results
            _ -> []
          end

        _ ->
          []
      end
    else
      []
    end
  end

  # Helper function to get badge class based on score
  defp get_score_badge_class(score) when score <= 2, do: "badge-success"
  defp get_score_badge_class(score) when score <= 4, do: "badge-warning"
  defp get_score_badge_class(score) when score <= 6, do: "badge-error"
  defp get_score_badge_class(_score), do: "badge-error font-bold"

  # Sanitize filename for safe file system operations
  defp sanitize_filename(domain) do
    domain
    |> String.replace(~r/[^a-zA-Z0-9-_]/, "_")
    |> String.slice(0..50)
  end

  # Generate XLSX file from cannibalization results
  defp generate_xlsx(results, file_path) do
    try do
      # Create header row
      header = ["Từ khóa", "Điểm", "URLs"]

      # Create data rows
      data_rows =
        Enum.map(results, fn result ->
          # Join URLs with newline character for Excel
          urls_text = Enum.join(result.urls, "\n")

          [result.keyword, result.score, urls_text]
        end)

      # Combine header and data
      all_rows = [header | data_rows]

      # Create workbook
      workbook = %Elixlsx.Workbook{
        sheets: [
          %Elixlsx.Sheet{
            name: "Results",
            rows: all_rows
          }
        ]
      }

      # Write to file
      Elixlsx.write_to(workbook, file_path)

      :ok
    rescue
      e ->
        {:error, e}
    end
  end

  # Export to Google Sheets
  defp export_to_google_sheets(results, domain) do
    try do
      # Get folder ID from cache
      case Cachex.get(:cache, :reports_folder_id) do
        {:ok, folder_id} when is_binary(folder_id) ->
          # Get connection
          conn = GoogleDrive.get_conn()

          # Prepare spreadsheet name
          spreadsheet_name =
            "Keyword Cannibalization - #{domain} - #{DateTime.utc_now() |> DateTime.to_date()}"

          # Prepare data rows
          header = ["Từ khóa", "Điểm", "URLs"]

          data_rows =
            Enum.map(results, fn result ->
              # Join URLs with newline for display in single cell
              urls_text = Enum.join(result.urls, "\n")
              [result.keyword, result.score, urls_text]
            end)

          all_rows = [header | data_rows]

          # Export to spreadsheet
          case GoogleDrive.export_to_spreadsheet(conn, folder_id, spreadsheet_name, all_rows) do
            {:ok, %{spreadsheet_id: spreadsheet_id}} ->
              spreadsheet_url = "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit"
              {:ok, spreadsheet_url}

            {:error, reason} ->
              {:error, reason}
          end

        {:ok, nil} ->
          {:error, "Reports folder ID not configured in cache"}

        {:error, reason} ->
          {:error, "Failed to get reports folder ID: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, inspect(e)}
    end
  end
end
