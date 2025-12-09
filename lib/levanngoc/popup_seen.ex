defmodule Levanngoc.PopupSeen do
  use Ecto.Schema
  import Ecto.Changeset
  alias Levanngoc.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "popupseen" do
    belongs_to :popup, Levanngoc.Popup
    belongs_to :user, Levanngoc.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(popup_seen, attrs) do
    popup_seen
    |> cast(attrs, [:popup_id, :user_id])
    |> validate_required([:popup_id, :user_id])
    |> foreign_key_constraint(:popup_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:popup_id, :user_id], message: "người dùng đã xem popup này")
  end

  @doc """
  Marks a popup as seen by a user.
  Returns {:ok, popup_seen} on success or {:error, changeset} on failure.
  """
  def mark_popup_as_seen(popup_id, user_id) do
    %__MODULE__{}
    |> changeset(%{popup_id: popup_id, user_id: user_id})
    |> Repo.insert()
  end
end
