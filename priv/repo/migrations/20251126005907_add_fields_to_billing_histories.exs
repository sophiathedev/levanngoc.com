defmodule Levanngoc.Repo.Migrations.AddFieldsToBillingHistories do
  use Ecto.Migration

  def change do
    alter table(:billing_histories) do
      add :is_current, :boolean, default: false, null: false
      add :next_subscription_at, :utc_datetime
    end

    create index(:billing_histories, [:next_subscription_at])
  end
end
