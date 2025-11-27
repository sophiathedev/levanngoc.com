defmodule Levanngoc.Repo.Migrations.AddIndexToBillingHistoriesInvoiceNumber do
  use Ecto.Migration

  def change do
    create index(:billing_histories, [:invoice_number])
  end
end
