defmodule Levanngoc.Settings do
  @moduledoc """
  The Settings context.
  """

  import Ecto.Query, warn: false
  alias Levanngoc.Repo
  alias Levanngoc.Settings.AdminSetting

  @doc """
  Gets the admin setting.
  """
  def get_admin_setting do
    Repo.one(from s in AdminSetting, limit: 1)
  end
end
