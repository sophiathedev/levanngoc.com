defmodule Levanngoc.Repo.Migrations.AddPolicyFieldsToAdminSettings do
  use Ecto.Migration

  def change do
    alter table(:admin_settings) do
      add :privacy_policy, :text
      add :refund_policy, :text
      add :terms_of_service, :text
    end
  end
end
