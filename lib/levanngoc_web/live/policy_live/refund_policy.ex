defmodule LevanngocWeb.PolicyLive.RefundPolicy do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  @impl true
  def mount(_params, _session, socket) do
    settings = get_settings()
    content = if settings, do: settings.refund_policy, else: nil

    {:ok, assign(socket, :content, content)}
  end

  defp get_settings do
    Repo.all(AdminSetting) |> List.first()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="prose prose-lg max-w-none">
        <h1 class="text-4xl font-bold mb-6">Chính sách hoàn tiền</h1>

        <%= if @content && @content != "" do %>
          {Phoenix.HTML.raw(@content)}
        <% else %>
          <div class="bg-base-200 p-6 rounded-lg">
            <p class="text-base-content/70">
              Nội dung chính sách hoàn tiền sẽ được cập nhật sớm.
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
