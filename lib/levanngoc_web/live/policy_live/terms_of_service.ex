defmodule LevanngocWeb.PolicyLive.TermsOfService do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  @impl true
  def mount(_params, _session, socket) do
    settings = get_settings()
    content = if settings, do: settings.terms_of_service, else: nil

    {:ok, socket |> assign(:page_title, "Điều khoản sử dụng") |> assign(:content, content)}
  end

  defp get_settings do
    Repo.all(AdminSetting) |> List.first()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="prose prose-lg max-w-none">
        <h1 class="text-4xl font-bold mb-6">Điều khoản sử dụng</h1>

        <%= if @content && @content != "" do %>
          {Phoenix.HTML.raw(@content)}
        <% else %>
          <div class="bg-base-200 p-6 rounded-lg">
            <p class="text-base-content/70">
              Nội dung điều khoản sử dụng sẽ được cập nhật sớm.
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
