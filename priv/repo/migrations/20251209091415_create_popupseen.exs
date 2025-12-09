defmodule Levanngoc.Repo.Migrations.CreatePopupseen do
  use Ecto.Migration

  def change do
    create table(:popupseen, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :popup_id, references(:popups, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:popupseen, [:popup_id])
    create index(:popupseen, [:user_id])
    create unique_index(:popupseen, [:popup_id, :user_id])
  end
end
