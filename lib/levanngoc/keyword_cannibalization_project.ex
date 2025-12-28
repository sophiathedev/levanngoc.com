defmodule Levanngoc.KeywordCannibalizationProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "keyword_cannibalization_projects" do
    field :name, :string
    field :domain, :string
    field :keywords, {:array, :string}
    field :result_limit, :integer, default: 20
    field :status, :string, default: "pending"
    field :crawled_data, :map
    field :cannibalization_results, {:array, :map}
    field :error_message, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, Levanngoc.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :domain,
      :keywords,
      :result_limit,
      :status,
      :crawled_data,
      :cannibalization_results,
      :error_message,
      :started_at,
      :completed_at,
      :user_id
    ])
    |> validate_required([:name, :domain, :user_id], message: "không được để trống")
    |> validate_length(:name,
      min: 1,
      max: 255,
      too_short: "phải có ít nhất %{count} ký tự",
      too_long: "không được vượt quá %{count} ký tự"
    )
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
    |> assoc_constraint(:user)
  end
end
