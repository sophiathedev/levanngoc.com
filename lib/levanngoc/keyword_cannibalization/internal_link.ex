defmodule Levanngoc.KeywordCannibalization.InternalLink do
  @moduledoc """
  Represents a link from a page to another internal page.
  """

  @type t :: %__MODULE__{
          target_url: String.t(),
          anchor_text: String.t()
        }

  defstruct [
    :target_url,
    :anchor_text
  ]

  @doc """
  Creates a new InternalLink struct.

  ## Examples

      iex> InternalLink.new("https://example.com/page", "Click here")
      %InternalLink{target_url: "https://example.com/page", anchor_text: "Click here"}
  """
  def new(target_url, anchor_text) do
    %__MODULE__{
      target_url: target_url,
      anchor_text: anchor_text
    }
  end
end
