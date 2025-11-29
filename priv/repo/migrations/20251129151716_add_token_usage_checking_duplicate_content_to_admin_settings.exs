defmodule Levanngoc.Repo.Migrations.AddTokenUsageCheckingDuplicateContentToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :token_usage_checking_duplicate_content, :integer
    end
  end
end
