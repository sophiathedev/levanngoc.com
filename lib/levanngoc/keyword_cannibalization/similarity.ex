defmodule Levanngoc.KeywordCannibalization.Similarity do
  @moduledoc """
  Module for calculating text similarity using Jaro-Winkler distance.
  """

  @doc """
  Calculate Jaro-Winkler similarity between two strings.
  Returns a float between 0.0 (completely different) and 1.0 (identical).
  """
  def jaro_winkler(s1, s2) when is_binary(s1) and is_binary(s2) do
    s1 = String.downcase(s1)
    s2 = String.downcase(s2)

    if s1 == s2 do
      1.0
    else
      String.jaro_distance(s1, s2)
    end
  end

  def jaro_winkler(nil, _), do: 0.0
  def jaro_winkler(_, nil), do: 0.0

  @doc """
  Check if two strings are similar (>= threshold).
  Default threshold is 0.8 (80%).
  """
  def similar?(s1, s2, threshold \\ 0.8) do
    jaro_winkler(s1, s2) >= threshold
  end

  @doc """
  Calculate average similarity between all pairs in a list of strings.
  Returns a float between 0.0 and 1.0.
  """
  def average_similarity([]), do: 0.0
  def average_similarity([_]), do: 1.0

  def average_similarity(strings) do
    # Filter and sort to ensure consistent results
    strings =
      strings
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    if length(strings) < 2 do
      1.0
    else
      pairs =
        for i <- 0..(length(strings) - 2),
            j <- (i + 1)..(length(strings) - 1) do
          {Enum.at(strings, i), Enum.at(strings, j)}
        end

      similarities = Enum.map(pairs, fn {s1, s2} -> jaro_winkler(s1, s2) end)
      Enum.sum(similarities) / length(similarities)
    end
  end
end
