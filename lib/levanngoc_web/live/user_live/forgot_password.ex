defmodule LevanngocWeb.UserLive.ForgotPassword do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
      <div class="text-center">
        <.header>
          <p>Quên mật khẩu?</p>
          <:subtitle>
            Nhập email của bạn và chúng tôi sẽ gửi cho bạn hướng dẫn đặt lại mật khẩu.
          </:subtitle>
        </.header>
      </div>

      <.form
        for={@form}
        id="forgot_password_form"
        phx-submit="send_reset_link"
      >
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="email@example.com"
          autocomplete="email"
          required
        />

        <.button class="btn btn-primary w-full mt-6">
          Gửi liên kết đặt lại mật khẩu
        </.button>
      </.form>

      <div class="text-center mt-4">
        <.link navigate={~p"/users/log-in"} class="text-sm font-semibold text-brand hover:underline">
          Quay lại đăng nhập
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    # Redirect if user is already logged in (check session token)
    if session["user_token"] do
      {:ok, push_navigate(socket, to: "/")}
    else
      form = to_form(%{"email" => ""}, as: "user")
      {:ok, assign(socket, form: form, page_title: "Quên mật khẩu")}
    end
  end

  @impl true
  def handle_event("send_reset_link", %{"user" => %{"email" => email}}, socket) do
    # Check if user exists and send reset email if they do
    # But always show the same success message for security
    case Accounts.get_user_by_email(email) do
      nil ->
        # User doesn't exist, but don't reveal this
        :ok

      user ->
        # Send password reset email
        Accounts.deliver_user_reset_password_instructions(
          user,
          fn token -> url(~p"/users/reset-password/#{token}") end
        )
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Email với liên kết đặt lại mật khẩu đã được gửi đến email của bạn."
     )
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
