defmodule Levanngoc.EmailTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "email_templates" do
    field :template_id, :integer
    field :title, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  @template_types %{
    0 => :registration
  }

  @doc """
  Returns the template type atom for a given template_id integer.
  """
  def template_type(template_id) when is_integer(template_id) do
    Map.get(@template_types, template_id)
  end

  @doc """
  Returns the template_id integer for a given template type atom.
  """
  def template_id(template_type) when is_atom(template_type) do
    Enum.find_value(@template_types, fn {id, type} ->
      if type == template_type, do: id
    end)
  end

  @doc """
  Returns all template types.
  """
  def template_types, do: @template_types

  @doc false
  def changeset(email_template, attrs) do
    email_template
    |> cast(attrs, [:template_id, :title, :content])
    |> validate_required([:template_id, :title, :content])
    |> validate_length(:title, max: 512)
    |> validate_inclusion(:template_id, Map.keys(@template_types))
    |> unique_constraint(:template_id)
  end
end
