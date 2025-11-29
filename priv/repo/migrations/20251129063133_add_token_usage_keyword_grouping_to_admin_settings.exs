defmodule Levanngoc.Repo.Migrations.AddTokenUsageKeywordGroupingToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :token_usage_keyword_grouping, :integer
    end
  end
end
