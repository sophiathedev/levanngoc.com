defmodule LevanngocWeb.UserLive.Login do
  use LevanngocWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
      <div class="text-center">
        <.header>
          <p>Đăng nhập</p>
          <:subtitle>
            <%= if @current_scope do %>
              Bạn cần xác thực lại để thực hiện các hành động nhạy cảm trên tài khoản của mình.
            <% else %>
              Chưa có tài khoản? <.link
                navigate={~p"/users/register"}
                class="font-semibold text-brand hover:underline"
                phx-no-format
              >Đăng ký</.link> tài khoản ngay.
            <% end %>
          </:subtitle>
        </.header>
      </div>

      <div :if={local_mail_adapter?()} class="alert alert-info">
        <.icon name="hero-information-circle" class="size-6 shrink-0" />
        <div>
          <p>Bạn đang chạy bộ chuyển tiếp email cục bộ.</p>
          <p>
            Để xem email đã gửi, truy cập <.link href="/dev/mailbox" class="underline">trang hộp thư</.link>.
          </p>
        </div>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"/users/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label="Mật khẩu"
          autocomplete="current-password"
        />
        <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
          Đăng nhập và giữ đăng nhập <span aria-hidden="true">→</span>
        </.button>
        <.button class="btn btn-primary btn-soft w-full mt-2">
          Chỉ đăng nhập lần này
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:levanngoc, Levanngoc.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
