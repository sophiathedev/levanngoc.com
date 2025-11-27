defmodule Levanngoc.Repo.Migrations.AddTokenUsageKeywordRankingToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :token_usage_keyword_ranking, :integer
    end
  end
end