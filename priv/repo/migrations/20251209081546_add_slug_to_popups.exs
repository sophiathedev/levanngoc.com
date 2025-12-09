defmodule Levanngoc.Repo.Migrations.AddSlugToPopups do
  use Ecto.Migration

  def change do
    alter table(:popups) do
      add :slug, :string
    end

    # Generate slugs for existing records
    execute(
      """
      UPDATE popups
      SET slug = lower(regexp_replace(title, '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE slug IS NULL
      """,
      ""
    )

    alter table(:popups) do
      modify :slug, :string, null: false
    end

    create unique_index(:popups, [:slug])
  end
end
