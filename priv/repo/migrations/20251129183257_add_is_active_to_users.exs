defmodule Levanngoc.Repo.Migrations.AddIsActiveToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_active, :boolean, default: false, null: false
    end
  end
end
