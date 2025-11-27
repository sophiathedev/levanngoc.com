defmodule Levanngoc.Repo.Migrations.RemoveProxyConfigFromAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      remove :proxy_host
      remove :proxy_port
      remove :proxy_username
      remove :proxy_password
    end
  end
end
