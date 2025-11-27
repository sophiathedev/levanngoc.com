defmodule Levanngoc.Repo.Migrations.AddBannedAtAndTokenAmountToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :banned_at, :utc_datetime
      add :token_amount, :integer, default: 0
    end

    create index(:users, [:banned_at])
  end
end