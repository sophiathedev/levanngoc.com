defmodule LevanngocWeb.UserLive.Confirmation do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div class="text-center">
        <.header>Chào mừng {@user.email}</.header>
      </div>

      <.form
        :if={!@user.confirmed_at}
        for={@form}
        id="confirmation_form"
        phx-mounted={JS.focus_first()}
        phx-submit="submit"
        action={~p"/users/log-in?_action=confirmed"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <.button
          name={@form[:remember_me].name}
          value="true"
          phx-disable-with="Đang xác nhận..."
          class="btn btn-primary w-full"
        >
          Xác nhận và giữ đăng nhập
        </.button>
        <.button phx-disable-with="Đang xác nhận..." class="btn btn-primary btn-soft w-full mt-2">
          Xác nhận và chỉ đăng nhập lần này
        </.button>
      </.form>

      <.form
        :if={@user.confirmed_at}
        for={@form}
        id="login_form"
        phx-submit="submit"
        phx-mounted={JS.focus_first()}
        action={~p"/users/log-in"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <%= if @current_scope do %>
          <.button phx-disable-with="Đang đăng nhập..." class="btn btn-primary w-full">
            Đăng nhập
          </.button>
        <% else %>
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Đang đăng nhập..."
            class="btn btn-primary w-full"
          >
            Giữ tôi đăng nhập trên thiết bị này
          </.button>
          <.button
            phx-disable-with="Đang đăng nhập..."
            class="btn btn-primary btn-soft w-full mt-2"
          >
            Chỉ đăng nhập lần này
          </.button>
        <% end %>
      </.form>

      <p :if={!@user.confirmed_at} class="alert alert-outline mt-8">
        Mẹo: Nếu bạn thích mật khẩu, bạn có thể bật chúng trong cài đặt người dùng.
      </p>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Liên kết magic không hợp lệ hoặc đã hết hạn.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
