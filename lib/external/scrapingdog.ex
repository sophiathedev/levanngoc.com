defmodule Levanngoc.External.ScrapingDog do
  defstruct api_key: nil

  @check_index_url_endpoint "https://api.scrapingdog.com/google"

  def put_apikey(%__MODULE__{} = state, api_key) do
    %__MODULE__{state | api_key: api_key}
  end

  def check_url_index(%__MODULE__{} = state, url) do
    params = build_params(state, :check_url_index, url)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(20)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            case Map.get(data, "organic_results", []) do
              [] -> false
              [_ | _] -> true
            end

          {:error, reason} ->
            raise "Failed to parse JSON response: #{inspect(reason)}"
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        raise "Request failed with status code #{status_code}: #{body}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  def check_allintitle(%__MODULE__{} = state, keyword) do
    params = build_params(state, :check_allintitle, keyword)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(20)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            case Map.get(data, "search_information", %{}) do
              %{"total_results" => total_results} ->
                total_results

              _ ->
                0
            end

          {:error, reason} ->
            raise "Failed to parse JSON response: #{inspect(reason)}"
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        raise "Request failed with status code #{status_code}: #{body}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  def scrape_serp_for_grouping(%__MODULE__{} = state, keyword) do
    params = build_params(state, :scrape_serp_for_grouping, keyword)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(20)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            organic_results = Map.get(data, "organic_results", [])

            # Extract relevant information: title, link, position
            Enum.map(organic_results, fn result ->
              %{
                title: Map.get(result, "title"),
                link: Map.get(result, "link"),
                position: Map.get(result, "rank")
              }
            end)

          {:error, reason} ->
            raise "Failed to parse JSON response: #{inspect(reason)}"
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        raise "Request failed with status code #{status_code}: #{body}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  def check_keyword_ranking(%__MODULE__{} = state, keyword, url) do
    check_keyword_ranking_with_pagination(state, keyword, url, 0)
  end

  def scraping_cannibal(%__MODULE__{} = state, url, keyword, max_results) do
    scraping_cannibal_with_pagination(state, url, keyword, max_results, 0, [])
  end

  defp check_keyword_ranking_with_pagination(_state, _keyword, _url, page) when page > 10 do
    nil
  end

  defp check_keyword_ranking_with_pagination(state, keyword, url, page) do
    params = build_params(state, :check_keyword_ranking, keyword, page)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(60)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            organic_results = Map.get(data, "organic_results", [])

            result =
              Enum.find(organic_results, fn result ->
                String.contains?(result["link"], url)
              end)

            case result do
              nil ->
                check_keyword_ranking_with_pagination(state, keyword, url, page + 1)

              result ->
                Map.get(result, "page_rank")
            end

          {:error, reason} ->
            raise "Failed to parse JSON response: #{inspect(reason)}"
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        raise "Request failed with status code #{status_code}: #{body}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  defp scraping_cannibal_with_pagination(_state, _url, _keyword, max_results, _page, acc)
       when length(acc) >= max_results do
    Enum.take(acc, max_results)
  end

  defp scraping_cannibal_with_pagination(_state, _url, _keyword, _max_results, page, acc)
       when page > 10 do
    acc
  end

  defp scraping_cannibal_with_pagination(state, url, keyword, max_results, page, acc) do
    params = build_params(state, :scraping_cannibal, url, keyword, page)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(60)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            organic_results = Map.get(data, "organic_results", [])

            # Extract URLs from organic results
            urls = Enum.map(organic_results, fn result -> Map.get(result, "link") end)

            new_acc = acc ++ urls

            # Continue pagination if we haven't reached max_results
            if length(new_acc) >= max_results do
              Enum.take(new_acc, max_results)
            else
              scraping_cannibal_with_pagination(
                state,
                url,
                keyword,
                max_results,
                page + 1,
                new_acc
              )
            end

          {:error, reason} ->
            raise "Failed to parse JSON response: #{inspect(reason)}"
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        raise "Request failed with status code #{status_code}: #{body}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "HTTP request failed: #{inspect(reason)}"
    end
  end

  defp build_params(%__MODULE__{} = state, :check_url_index, url) do
    %{
      api_key: state.api_key,
      query: "site:#{url}",
      country: "vn",
      advance_search: "false",
      domain: "google.com"
    }
  end

  defp build_params(%__MODULE__{} = state, :check_allintitle, keyword) do
    %{
      api_key: state.api_key,
      query: "allintitle:#{keyword}",
      country: "vn",
      advance_search: "true",
      domain: "google.com"
    }
  end

  defp build_params(%__MODULE__{} = state, :scrape_serp_for_grouping, keyword) do
    %{
      api_key: state.api_key,
      query: keyword,
      country: "vn",
      language: "en",
      advance_search: "true",
      domain: "google.com"
    }
  end

  defp build_params(%__MODULE__{} = state, :check_keyword_ranking, keyword, page) do
    %{
      api_key: state.api_key,
      query: "#{keyword}",
      country: "vn",
      advance_search: "true",
      domain: "google.com",
      page: page
    }
  end

  defp build_params(%__MODULE__{} = state, :scraping_cannibal, url, keyword, page) do
    %{
      api_key: state.api_key,
      query: "site:#{url} \"#{keyword}\"",
      country: "vn",
      advance_search: "true",
      domain: "google.com",
      page: page
    }
  end
end
