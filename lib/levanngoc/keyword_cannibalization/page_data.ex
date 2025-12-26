defmodule Levanngoc.KeywordCannibalization.PageData do
  @moduledoc """
  Represents data extracted from a webpage for keyword cannibalization analysis.
  """

  alias Levanngoc.KeywordCannibalization.InternalLink

  @type t :: %__MODULE__{
          url: String.t(),
          title: String.t() | nil,
          h1: String.t() | nil,
          description: String.t() | nil,
          canonical_url: String.t() | nil,
          internal_links: list(InternalLink.t())
        }

  defstruct [
    :url,
    :title,
    :h1,
    :description,
    :canonical_url,
    internal_links: []
  ]

  @doc """
  Creates a new PageData struct.

  ## Examples

      iex> PageData.new("https://example.com/page")
      %PageData{url: "https://example.com/page", internal_links: []}

      iex> PageData.new("https://example.com/page", title: "My Page", h1: "Welcome")
      %PageData{url: "https://example.com/page", title: "My Page", h1: "Welcome", internal_links: []}
  """
  def new(url, attrs \\ []) do
    struct(__MODULE__, [{:url, url} | attrs])
  end

  @doc """
  Adds an internal link to the page data.

  ## Examples

      iex> page = PageData.new("https://example.com/page")
      iex> link = InternalLink.new("https://example.com/other", "Other Page")
      iex> PageData.add_link(page, link)
      %PageData{url: "https://example.com/page", internal_links: [%InternalLink{...}]}
  """
  def add_link(%__MODULE__{} = page_data, %InternalLink{} = link) do
    %{page_data | internal_links: page_data.internal_links ++ [link]}
  end

  @doc """
  Adds multiple internal links to the page data.

  ## Examples

      iex> page = PageData.new("https://example.com/page")
      iex> links = [
      ...>   InternalLink.new("https://example.com/page1", "Page 1"),
      ...>   InternalLink.new("https://example.com/page2", "Page 2")
      ...> ]
      iex> PageData.add_links(page, links)
      %PageData{url: "https://example.com/page", internal_links: [...]}
  """
  def add_links(%__MODULE__{} = page_data, links) when is_list(links) do
    %{page_data | internal_links: page_data.internal_links ++ links}
  end

  @doc """
  Returns the number of internal links on the page.

  ## Examples

      iex> page = PageData.new("https://example.com/page")
      iex> PageData.link_count(page)
      0
  """
  def link_count(%__MODULE__{internal_links: links}) do
    length(links)
  end
end
