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

  def check_keyword_ranking(%__MODULE__{} = state, keyword, url) do
    params = build_params(state, :check_keyword_ranking, keyword)

    query_string = URI.encode_query(params)
    full_url = "#{@check_index_url_endpoint}?#{query_string}"

    case HTTPoison.get(full_url, [], recv_timeout: :timer.seconds(60)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            organic_results = Map.get(data, "organic_results", [])

            results =
              Enum.find(organic_results, fn result ->
                String.contains?(result["link"], url)
              end)

            results["rank"]

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
      domain: "google.com",
      language: "en"
    }
  end

  defp build_params(%__MODULE__{} = state, :check_allintitle, keyword) do
    %{
      api_key: state.api_key,
      query: "allintitle:#{keyword}",
      country: "vn",
      advance_search: "true",
      domain: "google.com",
      language: "en"
    }
  end

  defp build_params(%__MODULE__{} = state, :check_keyword_ranking, keyword) do
    %{
      api_key: state.api_key,
      query: "#{keyword}",
      country: "vn",
      advance_search: "true",
      domain: "google.com",
      language: "vn"
    }
  end
end
