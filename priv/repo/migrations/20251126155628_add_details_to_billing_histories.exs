defmodule Levanngoc.Repo.Migrations.AddInvoiceNumberToBillingHistories do
  use Ecto.Migration

  def change do
    alter table(:billing_histories) do
      add :invoice_number, :string
      add :tokens_per_month, :integer
      add :billing_price_id, references(:billing_prices, type: :binary_id, on_delete: :nothing)
    end

    create index(:billing_histories, [:billing_price_id])
  end
end
