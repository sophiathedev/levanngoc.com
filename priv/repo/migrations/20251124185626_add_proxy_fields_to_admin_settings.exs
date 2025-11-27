defmodule Levanngoc.Repo.Migrations.AddProxyFieldsToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :proxy_host, :string
      add :proxy_port, :integer
      add :proxy_username, :string
      add :proxy_password, :string
    end
  end
end
