defmodule LevanngocWeb.PageController do
  use LevanngocWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
