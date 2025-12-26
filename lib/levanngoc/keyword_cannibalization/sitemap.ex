defmodule Levanngoc.KeywordCannibalization.Sitemap do
  @moduledoc """
  Module for crawling and extracting URLs from XML sitemaps.
  Supports both regular sitemaps and sitemap index files.
  """

  require Logger

  @doc """
  Fetches and extracts all URLs from a sitemap.

  ## Parameters
    - url: The sitemap URL (e.g., "https://example.com/sitemap.xml")
    - opts: Optional configuration
      - :follow_index - Whether to follow sitemap index files (default: true)
      - :timeout - HTTP request timeout in milliseconds (default: 30000)
      - :max_retries - Maximum number of retries (default: 3)

  ## Returns
    - `{:ok, urls}` - List of URLs extracted from the sitemap
    - `{:error, reason}` - Error tuple with reason

  ## Examples
      iex> Levanngoc.KeywordCannibalization.Sitemap.fetch("https://example.com/sitemap.xml")
      {:ok, ["https://example.com/page1", "https://example.com/page2"]}

      iex> Levanngoc.KeywordCannibalization.Sitemap.fetch("https://example.com/sitemap_index.xml")
      {:ok, ["https://example.com/page1", "https://example.com/page2", "https://example.com/page3"]}
  """
  def fetch(url, opts \\ []) do
    follow_index = Keyword.get(opts, :follow_index, true)
    timeout = Keyword.get(opts, :timeout, 30_000)
    max_retries = Keyword.get(opts, :max_retries, 3)

    with {:ok, xml_content} <- fetch_url(url, timeout, max_retries),
         {:ok, parsed} <- parse_xml(xml_content) do
      case detect_sitemap_type(parsed) do
        :sitemap_index when follow_index ->
          extract_and_fetch_index(parsed, timeout, max_retries)

        :sitemap_index ->
          {:ok, extract_sitemap_urls(parsed)}

        :urlset ->
          {:ok, extract_urls(parsed)}

        :unknown ->
          {:error, :invalid_sitemap_format}
      end
    end
  end

  @doc """
  Extracts URLs from already parsed sitemap XML content.

  ## Parameters
    - xml_content: The XML content as string

  ## Returns
    - `{:ok, urls}` - List of URLs
    - `{:error, reason}` - Error tuple
  """
  def extract_from_xml(xml_content) when is_binary(xml_content) do
    with {:ok, parsed} <- parse_xml(xml_content) do
      {:ok, extract_urls(parsed)}
    end
  end

  # Private functions

  defp fetch_url(url, timeout, max_retries, retry_count \\ 0)

  defp fetch_url(url, timeout, max_retries, retry_count) when retry_count < max_retries do
    Logger.info("Fetching sitemap from: #{url} (attempt #{retry_count + 1})")

    case HTTPoison.get(url, [], timeout: timeout, recv_timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.warning("Failed to fetch sitemap: HTTP #{status_code}")
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warning("Error fetching sitemap: #{inspect(reason)}, retrying...")
        :timer.sleep(1000 * (retry_count + 1))
        fetch_url(url, timeout, max_retries, retry_count + 1)
    end
  end

  defp fetch_url(_url, _timeout, _max_retries, _retry_count) do
    {:error, :max_retries_exceeded}
  end

  defp parse_xml(xml_content) do
    try do
      xml_content
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(quiet: true)
      |> case do
        {doc, _} -> {:ok, doc}
        _ -> {:error, :parse_error}
      end
    rescue
      e ->
        Logger.error("XML parsing error: #{inspect(e)}")
        {:error, :parse_error}
    end
  end

  defp detect_sitemap_type(parsed_xml) do
    case parsed_xml do
      {:xmlElement, :sitemapindex, _, _, _, _, _, _, _, _, _, _} -> :sitemap_index
      {:xmlElement, :urlset, _, _, _, _, _, _, _, _, _, _} -> :urlset
      _ -> :unknown
    end
  end

  defp extract_urls(parsed_xml) do
    parsed_xml
    |> extract_elements(:url)
    |> Enum.map(&extract_loc/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_sitemap_urls(parsed_xml) do
    parsed_xml
    |> extract_elements(:sitemap)
    |> Enum.map(&extract_loc/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_and_fetch_index(parsed_xml, timeout, max_retries) do
    sitemap_urls = extract_sitemap_urls(parsed_xml)
    Logger.info("Found #{length(sitemap_urls)} sitemaps in index")

    results =
      sitemap_urls
      |> Enum.map(fn sitemap_url ->
        case fetch(sitemap_url, follow_index: false, timeout: timeout, max_retries: max_retries) do
          {:ok, urls} ->
            urls

          {:error, reason} ->
            Logger.warning("Failed to fetch sitemap #{sitemap_url}: #{inspect(reason)}")
            []
        end
      end)
      |> List.flatten()
      |> Enum.uniq()

    {:ok, results}
  end

  defp extract_elements(parsed_xml, element_name) do
    :xmerl_xpath.string(~c"//#{element_name}", parsed_xml)
  end

  defp extract_loc(element) do
    case :xmerl_xpath.string(~c"loc/text()", element) do
      [] ->
        nil

      [loc_node | _] ->
        case loc_node do
          {:xmlText, _, _, _, value, _} ->
            List.to_string(value)

          _ ->
            nil
        end
    end
  end

  @doc """
  Automatically discovers and fetches sitemap from a domain.
  Tries common sitemap locations: /sitemap.xml, /sitemap_index.xml, /sitemap.xml.gz

  ## Parameters
    - domain: The domain URL (e.g., "https://example.com")
    - opts: Optional configuration (same as fetch/2)

  ## Returns
    - `{:ok, urls}` - List of URLs
    - `{:error, reason}` - Error tuple

  ## Examples
      iex> Levanngoc.KeywordCannibalization.Sitemap.discover("https://example.com")
      {:ok, ["https://example.com/page1", "https://example.com/page2"]}
  """
  def discover(domain, opts \\ []) do
    domain = String.trim_trailing(domain, "/")

    common_paths = [
      "/sitemap.xml",
      "/sitemap_index.xml",
      "/sitemap-index.xml",
      "/sitemap1.xml"
    ]

    Enum.reduce_while(common_paths, {:error, :not_found}, fn path, acc ->
      sitemap_url = domain <> path
      Logger.info("Trying sitemap at: #{sitemap_url}")

      case fetch(sitemap_url, opts) do
        {:ok, urls} when urls != [] ->
          {:halt, {:ok, urls}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  @doc """
  Filters URLs by pattern.

  ## Parameters
    - urls: List of URLs
    - pattern: Regex pattern or string to match

  ## Examples
      iex> urls = ["https://example.com/blog/post1", "https://example.com/page1"]
      iex> Levanngoc.KeywordCannibalization.Sitemap.filter_urls(urls, ~r/blog/)
      ["https://example.com/blog/post1"]
  """
  def filter_urls(urls, pattern) when is_list(urls) do
    regex = if is_binary(pattern), do: Regex.compile!(pattern), else: pattern

    Enum.filter(urls, fn url ->
      Regex.match?(regex, url)
    end)
  end

  @doc """
  Groups URLs by path depth.

  ## Examples
      iex> urls = ["https://example.com/", "https://example.com/blog", "https://example.com/blog/post1"]
      iex> Levanngoc.KeywordCannibalization.Sitemap.group_by_depth(urls)
      %{1 => ["https://example.com/"], 2 => ["https://example.com/blog"], 3 => ["https://example.com/blog/post1"]}
  """
  def group_by_depth(urls) when is_list(urls) do
    Enum.group_by(urls, fn url ->
      uri = URI.parse(url)
      path = uri.path || "/"

      path
      |> String.split("/", trim: true)
      |> length()
      |> Kernel.+(1)
    end)
  end
end
