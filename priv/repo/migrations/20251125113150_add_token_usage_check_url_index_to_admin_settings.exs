defmodule Levanngoc.Repo.Migrations.AddTokenUsageCheckUrlIndexToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :token_usage_check_url_index, :integer
    end
  end
end
