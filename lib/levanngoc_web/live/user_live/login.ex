defmodule LevanngocWeb.UserLive.Login do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts

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
        id="login_form_magic"
        action={~p"/users/log-in"}
        phx-submit="submit_magic"
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />
        <.button class="btn btn-primary w-full">
          Đăng nhập bằng email <span aria-hidden="true">→</span>
        </.button>
      </.form>

      <div class="divider">hoặc</div>

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

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    user = Accounts.get_user_by_email(email)

    cond do
      user && user.banned_at ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Người dùng này hiện đã bị ban, vui lòng liên hệ admin để được xử lý"
         )}

      user ->
        Accounts.deliver_login_instructions(
          user,
          &url(~p"/users/log-in/#{&1}")
        )

        info =
          "Nếu email của bạn có trong hệ thống, bạn sẽ nhận được hướng dẫn đăng nhập trong thời gian ngắn."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: ~p"/users/log-in")}

      true ->
        info =
          "Nếu email của bạn có trong hệ thống, bạn sẽ nhận được hướng dẫn đăng nhập trong thời gian ngắn."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:levanngoc, Levanngoc.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
