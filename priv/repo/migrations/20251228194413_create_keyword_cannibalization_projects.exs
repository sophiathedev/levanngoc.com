defmodule Levanngoc.Repo.Migrations.CreateKeywordCannibalizationProjects do
  use Ecto.Migration

  def change do
    create table(:keyword_cannibalization_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :domain, :string, null: false
      add :keywords, {:array, :string}, default: []
      add :result_limit, :integer, default: 20
      add :status, :string, default: "pending", null: false
      add :crawled_data, :map
      add :cannibalization_results, :map
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:keyword_cannibalization_projects, [:user_id])
    create index(:keyword_cannibalization_projects, [:status])
    create index(:keyword_cannibalization_projects, [:user_id, :status])
  end
end
