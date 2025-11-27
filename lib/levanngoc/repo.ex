defmodule Levanngoc.Repo do
  use Ecto.Repo,
    otp_app: :levanngoc,
    adapter: Ecto.Adapters.Postgres
end
