defmodule Levanngoc.Repo.Migrations.AddSepayFieldsToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :sepay_merchant_id, :string
      add :sepay_api_key, :string
    end
  end
end
