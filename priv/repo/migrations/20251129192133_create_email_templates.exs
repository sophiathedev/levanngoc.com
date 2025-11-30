defmodule Levanngoc.Repo.Migrations.CreateEmailTemplates do
  use Ecto.Migration

  def change do
    create table(:email_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, :integer, null: false
      add :title, :string, size: 512, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_templates, [:template_id])
  end
end
