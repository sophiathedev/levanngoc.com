defmodule Levanngoc.Popup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "popups" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :trigger_when, :integer
    field :status, :integer, default: 0

    has_many :popup_seens, Levanngoc.PopupSeen

    timestamps(type: :utc_datetime)
  end

  @trigger_types %{
    0 => :visiting_site
  }

  @status_types %{
    0 => :draft,
    1 => :published,
    2 => :published_for_all
  }

  @doc """
  Returns the trigger type atom for a given trigger_when integer.
  """
  def trigger_type(trigger_when) when is_integer(trigger_when) do
    Map.get(@trigger_types, trigger_when)
  end

  @doc """
  Returns the trigger_when integer for a given trigger type atom.
  """
  def trigger_when(trigger_type) when is_atom(trigger_type) do
    Enum.find_value(@trigger_types, fn {id, type} ->
      if type == trigger_type, do: id
    end)
  end

  @doc """
  Returns all trigger types.
  """
  def trigger_types, do: @trigger_types

  @doc """
  Returns the status type atom for a given status integer.
  """
  def status_type(status) when is_integer(status) do
    Map.get(@status_types, status)
  end

  @doc """
  Returns the status integer for a given status type atom.
  """
  def status_value(status_type) when is_atom(status_type) do
    Enum.find_value(@status_types, fn {id, type} ->
      if type == status_type, do: id
    end)
  end

  @doc """
  Returns all status types.
  """
  def status_types, do: @status_types

  @doc false
  def changeset(popup, attrs) do
    popup
    |> cast(attrs, [:title, :slug, :content, :trigger_when, :status])
    |> validate_required([:title, :slug, :content])
    |> validate_length(:title, max: 1024)
    |> validate_format(:slug, ~r/^[a-zA-Z0-9]+$/, message: "chỉ được chứa chữ cái và số")
    |> unique_constraint(:slug, message: "đã được sử dụng bởi popup khác")
    |> validate_inclusion(:trigger_when, Map.keys(@trigger_types), message: "không hợp lệ")
    |> validate_inclusion(:status, Map.keys(@status_types), message: "không hợp lệ")
  end
end
