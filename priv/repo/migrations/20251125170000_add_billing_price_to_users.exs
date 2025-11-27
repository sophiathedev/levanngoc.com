defmodule Levanngoc.Repo.Migrations.AddBillingPriceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :billing_price_id, references(:billing_prices, type: :binary_id, on_delete: :nilify_all)
    end
  end
end