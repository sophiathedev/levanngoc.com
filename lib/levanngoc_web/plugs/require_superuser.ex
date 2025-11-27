defmodule LevanngocWeb.Plugs.RequireSuperuser do
  @moduledoc """
  Plug to restrict access to superuser-only routes.

  Returns 404 (not found) if the user is not authenticated or not a superuser.
  This provides security through obscurity - unauthorized users won't know
  the route exists.

  ## Usage

  In your router:

      scope "/admin", LevanngocWeb do
        pipe_through [:browser, :require_authenticated_user, :require_superuser]

        get "/dashboard", AdminController, :dashboard
      end

  Or as a plug in a controller:

      defmodule LevanngocWeb.AdminController do
        use LevanngocWeb, :controller

        plug LevanngocWeb.Plugs.RequireSuperuser
      end
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Levanngoc.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = get_current_user(conn)

    if User.superuser?(current_user) do
      conn
    else
      conn
      |> put_status(:not_found)
      |> put_view(html: LevanngocWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    end
  end

  defp get_current_user(conn) do
    case conn.assigns do
      %{current_scope: %{user: user}} -> user
      _ -> nil
    end
  end
end
