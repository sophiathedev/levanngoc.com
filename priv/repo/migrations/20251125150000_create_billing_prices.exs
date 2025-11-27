defmodule Levanngoc.Repo.Migrations.CreateBillingPrices do
  use Ecto.Migration

  def change do
    create table(:billing_prices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :price, :decimal, null: false
      add :token_amount_provide, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:billing_prices, [:name])
  end
end