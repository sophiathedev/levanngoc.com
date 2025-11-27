defmodule Levanngoc.Repo.Migrations.CreateBillingHistories do
  use Ecto.Migration

  def change do
    create table(:billing_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :total_pricing, :decimal
      add :billing_ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:billing_histories, [:user_id])
    create index(:billing_histories, [:billing_ended_at])
  end
end
