defmodule Levanngoc.KeywordCannibalization.HtmlParser do
  @moduledoc """
  Module for parsing HTML content and extracting page data using Floki.
  """

  require Logger

  alias Levanngoc.KeywordCannibalization.{PageData, InternalLink}

  @doc """
  Fetches and parses HTML content from a URL.

  ## Parameters
    - url: The URL to fetch and parse
    - opts: Optional configuration
      - :timeout - HTTP request timeout in milliseconds (default: 30000)
      - :base_domain - Base domain for filtering internal links

  ## Returns
    - `{:ok, %PageData{}}` - Parsed page data
    - `{:error, reason}` - Error tuple
  """
  def fetch_and_parse(url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    base_domain = Keyword.get(opts, :base_domain)

    with {:ok, html} <- fetch_html(url, timeout),
         {:ok, page_data} <- parse_html(html, url, base_domain) do
      {:ok, page_data}
    else
      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Parses HTML content into PageData struct.

  ## Parameters
    - html: HTML content as string
    - url: The URL of the page
    - base_domain: Optional base domain for filtering internal links

  ## Returns
    - `{:ok, %PageData{}}` - Parsed page data
    - `{:error, reason}` - Error tuple
  """
  def parse_html(html, url, base_domain \\ nil) when is_binary(html) do
    try do
      document = Floki.parse_document!(html)

      page_data =
        PageData.new(url,
          title: extract_title(document),
          h1: extract_h1(document),
          description: extract_description(document),
          canonical_url: extract_canonical(document)
        )

      internal_links = extract_internal_links(document, url, base_domain)
      page_data = PageData.add_links(page_data, internal_links)

      {:ok, page_data}
    rescue
      _e ->
        {:error, :parse_error}
    end
  end

  # Private functions

  defp fetch_html(url, timeout) do
    headers = [
      {"User-Agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"}
    ]

    case HTTPoison.get(url, headers,
           timeout: timeout,
           recv_timeout: timeout,
           follow_redirect: true
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp extract_title(document) do
    case Floki.find(document, "title") do
      [] -> nil
      elements -> elements |> Floki.text() |> String.trim() |> String.downcase()
    end
  end

  defp extract_h1(document) do
    case Floki.find(document, "h1") do
      [] -> nil
      elements -> elements |> List.first() |> Floki.text() |> String.trim() |> String.downcase()
    end
  end

  defp extract_description(document) do
    case Floki.find(document, "meta[name='description']") do
      [] ->
        case Floki.find(document, "meta[property='og:description']") do
          [] ->
            nil

          elements ->
            elements
            |> Floki.attribute("content")
            |> List.first()
            |> case do
              nil -> nil
              text -> String.downcase(text)
            end
        end

      elements ->
        elements
        |> Floki.attribute("content")
        |> List.first()
        |> case do
          nil -> nil
          text -> String.downcase(text)
        end
    end
  end

  defp extract_canonical(document) do
    case Floki.find(document, "link[rel='canonical']") do
      [] -> nil
      elements -> elements |> Floki.attribute("href") |> List.first()
    end
  end

  defp extract_internal_links(document, page_url, base_domain) do
    base_domain = base_domain || extract_domain(page_url)

    document
    |> Floki.find("a[href]")
    |> Enum.map(fn link ->
      href = link |> Floki.attribute("href") |> List.first()
      anchor_text = link |> Floki.text() |> String.trim() |> String.downcase()

      {href, anchor_text}
    end)
    |> Enum.filter(fn {href, _anchor} -> href && href != "" && href != "#" end)
    |> Enum.map(fn {href, anchor} ->
      absolute_url = build_absolute_url(href, page_url)
      {absolute_url, anchor}
    end)
    |> Enum.filter(fn {url, _anchor} -> is_internal_link?(url, base_domain) end)
    |> Enum.map(fn {url, anchor} -> InternalLink.new(url, anchor) end)
    |> Enum.uniq_by(& &1.target_url)
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: nil} -> nil
      %URI{host: host} -> host
    end
  end

  defp build_absolute_url(href, base_url) do
    cond do
      # Already absolute URL
      String.starts_with?(href, "http://") or String.starts_with?(href, "https://") ->
        href

      # Protocol-relative URL
      String.starts_with?(href, "//") ->
        uri = URI.parse(base_url)
        "#{uri.scheme}:#{href}"

      # Absolute path
      String.starts_with?(href, "/") ->
        uri = URI.parse(base_url)
        "#{uri.scheme}://#{uri.host}#{if uri.port, do: ":#{uri.port}", else: ""}#{href}"

      # Relative path
      true ->
        base_uri = URI.parse(base_url)
        path = base_uri.path || "/"
        dir = Path.dirname(path)

        new_path =
          if dir == "/" do
            "/#{href}"
          else
            "#{dir}/#{href}"
          end

        "#{base_uri.scheme}://#{base_uri.host}#{if base_uri.port, do: ":#{base_uri.port}", else: ""}#{new_path}"
    end
  end

  defp is_internal_link?(_url, base_domain) when is_nil(base_domain), do: false

  defp is_internal_link?(url, base_domain) do
    case URI.parse(url) do
      %URI{host: nil} ->
        false

      %URI{host: host} ->
        String.contains?(host, base_domain) or String.contains?(base_domain, host)
    end
  end

  @doc """
  Extracts the base domain from a URL.

  ## Examples
      iex> HtmlParser.get_base_domain("https://example.com/page")
      "example.com"

      iex> HtmlParser.get_base_domain("https://www.example.com/page")
      "example.com"
  """
  def get_base_domain(url) do
    case URI.parse(url) do
      %URI{host: nil} ->
        nil

      %URI{host: host} ->
        # Remove www. prefix if present
        host
        |> String.replace_prefix("www.", "")
    end
  end

  @doc """
  Normalizes a domain string by adding protocol if missing.

  ## Examples
      iex> HtmlParser.normalize_domain("example.com")
      "https://example.com"

      iex> HtmlParser.normalize_domain("https://example.com")
      "https://example.com"
  """
  def normalize_domain(domain) do
    domain = String.trim(domain)

    cond do
      String.starts_with?(domain, "http://") or String.starts_with?(domain, "https://") ->
        domain

      true ->
        "https://#{domain}"
    end
  end
end
