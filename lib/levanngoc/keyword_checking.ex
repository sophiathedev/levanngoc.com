defmodule Levanngoc.KeywordChecking do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "keyword_checkings" do
    field :keyword, :string
    field :website_url, :string
    belongs_to :user, Levanngoc.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(keyword_checking, attrs) do
    keyword_checking
    |> cast(attrs, [:keyword, :website_url, :user_id])
    |> validate_required([:keyword, :website_url, :user_id])
    |> normalize_url()
    |> validate_length(:keyword, max: 500)
    |> validate_length(:website_url, max: 1000)
    |> validate_format(:website_url, ~r/^(https?:\/\/)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}([\/\w.-]*)*$/i, message: "must be a valid URL format")
    |> assoc_constraint(:user)
  end

  # Normalize URL by returning as-is (no automatic protocol addition)
  defp normalize_url(changeset) do
    case get_change(changeset, :website_url) do
      nil ->
        changeset

      url ->
        normalized_url =
          url
          |> String.trim()
          |> add_protocol_if_missing()

        put_change(changeset, :website_url, normalized_url)
    end
  end

  defp add_protocol_if_missing(url) do
    url
  end
end