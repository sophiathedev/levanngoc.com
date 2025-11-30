defmodule LevanngocWeb.UserLive.ForgotPassword do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div class="w-full max-w-md">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="text-center mb-6">
              <.link navigate={~p"/"} class="inline-block mb-4">
                <img src={~p"/images/logo.svg"} width="48" alt="Logo" />
              </.link>
              <h1 class="text-2xl font-bold">Quên mật khẩu?</h1>
              <p class="text-base-content/60 mt-2">
                Nhập email của bạn và chúng tôi sẽ gửi cho bạn hướng dẫn đặt lại mật khẩu.
              </p>
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

              <div class="mt-6">
                <.button class="btn btn-primary w-full">
                  Quên mật khẩu
                </.button>
              </div>
            </.form>

            <div class="divider">HOẶC</div>

            <div class="text-center">
              <.link navigate={~p"/users/log-in"} class="text-sm text-primary underline">
                Quay lại đăng nhập
              </.link>
            </div>
          </div>
        </div>
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
        # TODO: Send password reset email
        # Accounts.UserNotifier.deliver_reset_password_instructions(user, url)
        :ok
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
