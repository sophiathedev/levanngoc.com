defmodule LevanngocWeb.SchemaGeneratorLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Tạo Schema")}
  end
end
