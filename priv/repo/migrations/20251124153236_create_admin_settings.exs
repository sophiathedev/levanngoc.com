defmodule Levanngoc.Repo.Migrations.CreateAdminSettings do
  use Ecto.Migration

  def change do
    create table(:admin_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scraping_dog_api_key, :string, size: 1024
      add :mailgun_api_key, :string, size: 1024

      timestamps(type: :utc_datetime)
    end
  end
end
