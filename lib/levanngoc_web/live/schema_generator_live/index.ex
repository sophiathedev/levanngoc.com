defmodule LevanngocWeb.SchemaGeneratorLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tạo Schema")
     |> LevanngocWeb.TrackToolVisit.track_visit("/schema-generator")}
  end
end
