defmodule Levanngoc.Repo.Migrations.AddTokenUsageCheckAllintitleToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :token_usage_check_allintitle, :integer
    end
  end
end
