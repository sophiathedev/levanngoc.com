defmodule Levanngoc.Repo.Migrations.AddStatusToPopups do
  use Ecto.Migration

  def change do
    alter table(:popups) do
      add :status, :integer, default: 0, null: false
    end

    create index(:popups, [:status])
  end
end
