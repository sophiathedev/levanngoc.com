defmodule Levanngoc.Jobs.KeywordCannibalizationWorker do
  @moduledoc """
  Oban worker for processing keyword cannibalization analysis in the background.
  Broadcasts real-time progress updates via PubSub.
  """

  use Oban.Worker, queue: :keyword_cannibalization, max_attempts: 1

  require Logger

  alias Levanngoc.KeywordCannibalizationProjects
  alias Levanngoc.KeywordCannibalization.{Sitemap, HtmlParser, PageData, Scorer}
  alias Levanngoc.External.ScrapingDog
  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  # Configuration
  @max_urls_to_crawl 10000
  @max_internal_links 100
  @crawl_concurrency 40
  @keyword_scraping_concurrency 30

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    Logger.info("[CANNIBALIZATION_WORKER] Starting job for project_id: #{project_id}")

    # Load project from DB
    project = Repo.get!(Levanngoc.KeywordCannibalizationProject, project_id)

    # Mark as running
    {:ok, project} = KeywordCannibalizationProjects.mark_as_running(project)

    broadcast_status(project_id, "running", "Đang khởi động...")

    try do
      # Step 1: Discover and crawl sitemap
      normalized_domain = HtmlParser.normalize_domain(project.domain)
      base_domain = HtmlParser.get_base_domain(normalized_domain)

      broadcast_status(project_id, "running", "Đang tìm sitemap...")

      case Sitemap.discover(normalized_domain) do
        {:ok, urls} ->
          limited_urls = Enum.take(urls, @max_urls_to_crawl)
          total_urls = length(limited_urls)

          broadcast_status(
            project_id,
            "running",
            "Tìm thấy #{total_urls} URLs. Đang crawl..."
          )

          # Step 2: Crawl URLs concurrently
          crawled_data = crawl_urls(limited_urls, base_domain, project_id)

          broadcast_status(
            project_id,
            "running",
            "Đã crawl #{length(crawled_data)} URLs. Đang phân tích từ khóa..."
          )

          # Step 3: Scrape keywords if they exist
          if length(project.keywords) > 0 do
            cannibalization_results =
              scrape_and_score_keywords(
                project.keywords,
                project.domain,
                project.result_limit,
                crawled_data,
                project_id
              )

            # Step 4: Save results to DB
            {:ok, _project} =
              KeywordCannibalizationProjects.mark_as_completed(
                project,
                %{urls: crawled_data},
                cannibalization_results
              )

            broadcast_status(project_id, "completed", "Hoàn thành!")
            :ok
          else
            # No keywords, just save crawled data
            {:ok, _project} =
              KeywordCannibalizationProjects.mark_as_completed(
                project,
                %{urls: crawled_data},
                []
              )

            broadcast_status(project_id, "completed", "Hoàn thành crawl (không có từ khóa)!")
            :ok
          end

        {:error, reason} ->
          error_msg = "Không thể tìm thấy sitemap: #{inspect(reason)}"

          Logger.error(
            "[CANNIBALIZATION_WORKER] Sitemap error for project #{project_id}: #{inspect(reason)}"
          )

          KeywordCannibalizationProjects.mark_as_failed(project, error_msg)
          broadcast_status(project_id, "failed", error_msg)
          {:error, reason}
      end
    rescue
      e ->
        error_msg = "Lỗi xử lý: #{Exception.message(e)}"

        Logger.error(
          "[CANNIBALIZATION_WORKER] Exception for project #{project_id}: #{Exception.format(:error, e, __STACKTRACE__)}"
        )

        KeywordCannibalizationProjects.mark_as_failed(project, error_msg)
        broadcast_status(project_id, "failed", error_msg)
        {:error, e}
    end
  end

  defp crawl_urls(urls, base_domain, project_id) do
    total = length(urls)

    urls
    |> Task.async_stream(
      fn url ->
        crawl_single_url(url, base_domain)
      end,
      max_concurrency: @crawl_concurrency,
      timeout: 30_000,
      on_timeout: :kill_task,
      ordered: false
    )
    |> Enum.reduce({[], 0}, fn
      {:ok, {:ok, page_data}}, {acc, processed_count} ->
        processed_count = processed_count + 1
        maybe_broadcast_crawl_progress(project_id, processed_count, total)
        {[page_data_to_map(page_data) | acc], processed_count}

      {:ok, {:error, _reason}}, {acc, processed_count} ->
        processed_count = processed_count + 1
        maybe_broadcast_crawl_progress(project_id, processed_count, total)
        {acc, processed_count}

      {:exit, _reason}, {acc, processed_count} ->
        processed_count = processed_count + 1
        maybe_broadcast_crawl_progress(project_id, processed_count, total)
        {acc, processed_count}

      _other, {acc, processed_count} ->
        processed_count = processed_count + 1
        maybe_broadcast_crawl_progress(project_id, processed_count, total)
        {acc, processed_count}
    end)
    |> then(fn {pages, _processed_count} -> Enum.reverse(pages) end)
  end

  defp maybe_broadcast_crawl_progress(project_id, processed_count, total) do
    message = "Đã crawl #{processed_count}/#{total} URLs..."
    Cachex.put(:cache, {:cannibalization_progress, project_id}, message)
    broadcast_status(project_id, "running", message)
  end

  defp page_data_to_map(%PageData{} = page_data) do
    %{
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
  end

  defp crawl_single_url(url, base_domain) do
    case HtmlParser.fetch_and_parse(url, base_domain: base_domain) do
      {:ok, page_data} ->
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

  defp scrape_and_score_keywords(keywords, domain, max_results, crawled_data, project_id) do
    # Get ScrapingDog API key
    admin_setting = Repo.all(AdminSetting)

    case admin_setting do
      [%AdminSetting{scraping_dog_api_key: api_key} | _]
      when is_binary(api_key) and api_key != "" ->
        scraping_dog =
          %ScrapingDog{}
          |> ScrapingDog.put_apikey(api_key)

        total_keywords = length(keywords)

        broadcast_status(
          project_id,
          "running",
          "Đang phân tích #{total_keywords} từ khóa..."
        )

        # Scrape keywords concurrently
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

        # Score each keyword
        cannibalization_results =
          results
          |> Enum.reduce([], fn
            {:ok, {keyword, {:ok, urls}}}, acc ->
              result = score_keyword_result(keyword, urls, crawled_data)
              [result | acc]

            {:ok, {keyword, {:error, reason}}}, acc ->
              result = error_result(keyword, reason)
              [result | acc]

            {:exit, _reason}, acc ->
              acc

            _other, acc ->
              acc
          end)
          |> Enum.sort_by(& &1.keyword)

        cannibalization_count =
          Enum.count(cannibalization_results, fn r -> r[:status] == "cannibalization" end)

        broadcast_status(
          project_id,
          "running",
          "Tìm thấy #{cannibalization_count} từ khóa có vấn đề cannibalization..."
        )

        cannibalization_results

      _ ->
        Logger.error("[CANNIBALIZATION_WORKER] API key not configured for project #{project_id}")

        []
    end
  end

  defp score_keyword_result(keyword, urls, crawled_data) do
    cond do
      # No URLs found
      length(urls) == 0 ->
        no_results_result(keyword)

      # Only 1 URL - safe
      length(urls) == 1 ->
        safe_result(keyword, urls)

      # 2+ URLs - check with Scorer
      true ->
        case Scorer.score_keyword(keyword, urls, crawled_data) do
          nil ->
            # Scorer returned nil -> not enough data
            no_results_result(keyword, urls)

          score_result ->
            # Keep status from Scorer (cannibalization or mention_only)
            score_result
        end
    end
  end

  defp no_results_result(keyword, urls \\ []) do
    %{
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
      status: "no_results"
    }
  end

  defp safe_result(keyword, urls) do
    %{
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
      status: "safe"
    }
  end

  defp error_result(keyword, reason) do
    %{
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
      status: "error",
      error_message: reason
    }
  end

  defp broadcast_status(project_id, status, message) do
    Phoenix.PubSub.broadcast(
      Levanngoc.PubSub,
      "cannibalization_project:#{project_id}",
      {:project_status, %{project_id: project_id, status: status, message: message}}
    )
  end
end
