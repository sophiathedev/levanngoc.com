defmodule Levanngoc.Repo.Migrations.AddStatusToBillingHistories do
  use Ecto.Migration

  def change do
    alter table(:billing_histories) do
      add :status, :integer, default: 0
    end

    create index(:billing_histories, [:status])
  end
end
