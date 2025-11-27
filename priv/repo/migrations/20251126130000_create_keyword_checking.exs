defmodule Levanngoc.Repo.Migrations.CreateKeywordChecking do
  use Ecto.Migration

  def change do
    create table(:keyword_checkings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :keyword, :string, null: false
      add :website_url, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:keyword_checkings, [:user_id])
    create index(:keyword_checkings, [:keyword])
    create index(:keyword_checkings, [:website_url])
  end
end