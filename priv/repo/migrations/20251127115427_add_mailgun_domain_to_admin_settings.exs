defmodule Levanngoc.Repo.Migrations.AddMailgunDomainToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :mailgun_domain, :string
    end
  end
end
