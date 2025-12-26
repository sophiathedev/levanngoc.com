defmodule Levanngoc.KeywordCannibalization.Scorer do
  @moduledoc """
  Module for scoring keyword cannibalization severity.
  """

  alias Levanngoc.KeywordCannibalization.Similarity

  @doc """
  Score a keyword based on cannibalization criteria.

  Returns: %{
    score: integer,
    urls: list of URLs,
    details: %{
      base_score: integer,
      title_h1_similarity: float,
      same_page_type: boolean,
      anchor_text_conflicts: integer
    }
  }
  """
  def score_keyword(keyword, urls, crawled_data) do
    # Sort URLs first to ensure consistent ordering
    sorted_urls = Enum.sort(urls)

    # Filter to get only URLs that exist in crawled data
    url_details =
      sorted_urls
      |> Enum.map(fn url -> {url, find_page_data(url, crawled_data)} end)
      |> Enum.reject(fn {_url, data} -> is_nil(data) end)

    if length(url_details) < 2 do
      # Not a cannibalization case
      nil
    else
      # Base score based on number of URLs
      base_score = calculate_base_score(length(url_details))

      # Title/H1 similarity score
      {title_h1_score, avg_similarity} = calculate_title_h1_score(url_details)

      # Same page type score
      same_type_score = calculate_same_type_score(url_details)

      # Anchor text conflict score
      anchor_score = calculate_anchor_conflict_score(url_details, crawled_data)

      total_score = base_score + title_h1_score + same_type_score + anchor_score

      # Round similarity to 4 decimal places for consistency
      rounded_similarity = Float.round(avg_similarity, 4)

      # Calculate circle visualization values
      max_score = 10.0
      percentage = min(total_score / max_score * 100.0, 100.0)
      circumference = 2.0 * 3.14159 * 70.0
      stroke_dashoffset = Float.round(circumference - percentage / 100.0 * circumference, 2)

      %{
        keyword: keyword,
        score: total_score,
        urls: Enum.map(url_details, fn {url, _} -> url end),
        details: %{
          base_score: base_score,
          title_h1_similarity: rounded_similarity,
          same_page_type: same_type_score > 0,
          anchor_text_conflicts: anchor_score
        },
        visualization: %{
          percentage: Float.round(percentage, 2),
          circumference: Float.round(circumference, 2),
          stroke_dashoffset: stroke_dashoffset
        }
      }
    end
  end

  # Find page data from crawled data by URL
  defp find_page_data(url, crawled_data) do
    # Normalize URLs for comparison
    normalized_url = normalize_url(url)

    # First try exact match
    exact_match =
      Enum.find(crawled_data, fn page ->
        normalize_url(page["url"] || "") == normalized_url
      end)

    if exact_match do
      exact_match
    else
      # Try contains match as fallback
      Enum.find(crawled_data, fn page ->
        page_url = normalize_url(page["url"] || "")
        String.contains?(page_url, normalized_url) || String.contains?(normalized_url, page_url)
      end)
    end
  end

  # Normalize URL by removing protocol and trailing slash
  defp normalize_url(url) when is_binary(url) do
    url
    |> String.replace(~r/^https?:\/\//, "")
    |> String.replace(~r/\/$/, "")
    |> String.downcase()
  end

  defp normalize_url(_), do: ""

  # Calculate base score: 2 URLs = 2, >=3 URLs = 3+
  defp calculate_base_score(url_count) when url_count == 2, do: 2
  defp calculate_base_score(url_count) when url_count >= 3, do: 3 + (url_count - 3)

  # Calculate title/H1 similarity score
  # If avg similarity > 80%, add 2 points
  defp calculate_title_h1_score(url_details) do
    titles = Enum.map(url_details, fn {_url, data} -> data["title"] end)
    h1s = Enum.map(url_details, fn {_url, data} -> data["h1"] end)

    title_similarity = Similarity.average_similarity(titles)
    h1_similarity = Similarity.average_similarity(h1s)

    avg_similarity = (title_similarity + h1_similarity) / 2

    score = if avg_similarity > 0.8, do: 2, else: 0

    {score, avg_similarity}
  end

  # Calculate same page type score
  # If 2+ URLs are same type (blog post), add 1 point
  defp calculate_same_type_score(url_details) do
    page_types =
      url_details
      |> Enum.map(fn {url, _data} -> detect_page_type(url) end)
      |> Enum.frequencies()

    # Check if there are 2+ URLs of the same type
    has_duplicates =
      page_types
      |> Enum.any?(fn {_type, count} -> count >= 2 end)

    if has_duplicates, do: 1, else: 0
  end

  # Detect page type from URL structure
  defp detect_page_type(url) do
    cond do
      String.contains?(url, "/blog/") || String.contains?(url, "/post/") -> :blog_post
      String.contains?(url, "/category/") -> :category
      String.contains?(url, "/product/") -> :product
      String.contains?(url, "/tag/") -> :tag
      true -> :other
    end
  end

  # Calculate anchor text conflict score
  # Check if multiple pages link to competing URLs with same/similar anchor text
  defp calculate_anchor_conflict_score(url_details, crawled_data) do
    # Sort competing URLs for consistency
    competing_urls =
      url_details
      |> Enum.map(fn {url, _} -> url end)
      |> Enum.sort()

    # Normalize competing URLs for matching
    normalized_competing_urls = Enum.map(competing_urls, &normalize_url/1)

    # Find pages that link to multiple competing URLs with similar anchor text
    conflicts =
      crawled_data
      |> Enum.reduce(0, fn page, acc ->
        internal_links = page["internal_links"] || []

        # Get links pointing to competing URLs
        links_to_competitors =
          internal_links
          |> Enum.filter(fn link ->
            target = normalize_url(link["target_url"] || "")

            Enum.any?(normalized_competing_urls, fn norm_comp_url ->
              target == norm_comp_url || String.contains?(target, norm_comp_url) ||
                String.contains?(norm_comp_url, target)
            end)
          end)

        # If this page links to 2+ competing URLs, check anchor text similarity
        if length(links_to_competitors) >= 2 do
          anchor_texts =
            links_to_competitors
            |> Enum.map(fn link -> link["anchor_text"] end)
            |> Enum.reject(&is_nil/1)

          if length(anchor_texts) >= 2 do
            avg_similarity = Similarity.average_similarity(anchor_texts)

            # If anchor texts are similar (>70%), this is a conflict
            if avg_similarity > 0.7 do
              acc + 1
            else
              acc
            end
          else
            acc
          end
        else
          acc
        end
      end)

    # If there are conflicts, add 3 points
    if conflicts > 0, do: 3, else: 0
  end
end
