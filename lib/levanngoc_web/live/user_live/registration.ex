defmodule LevanngocWeb.UserLive.Registration do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts
  alias Levanngoc.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div class="text-center">
        <.header>
          Đăng ký tài khoản
          <:subtitle>
            Đã có tài khoản?
            <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
              Đăng nhập
            </.link>
            vào tài khoản của bạn ngay.
          </:subtitle>
        </.header>
      </div>

      <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />

        <p class="text-sm text-base-content/70 mb-4">
          Bằng việc đăng ký, bạn chấp nhận
          <.link navigate={~p"/privacy-policy"} class="text-primary">
            Chính sách bảo mật
          </.link>
          và
          <.link navigate={~p"/terms-of-service"} class="text-primary">
            Điều khoản sử dụng
          </.link>
          của chúng tôi.
        </p>

        <.button phx-disable-with="Đang tạo tài khoản..." class="btn btn-primary w-full">
          Đăng ký
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, push_navigate(socket, to: "/")}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.validate_email_for_registration(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Validate only the email (format and uniqueness)
    changeset = Accounts.validate_email_for_registration(%User{}, user_params)

    if changeset.valid? do
      # Generate a random password
      generated_password = generate_password()

      # Generate an 8-digit OTP
      otp = generate_otp()

      email = user_params["email"]

      # Prepare user data to cache for later registration
      user_data = %{
        email: email,
        password: generated_password,
        password_confirmation: generated_password
      }

      Cachex.put(:cache, email, otp, expire: :timer.minutes(15))
      Cachex.put(:cache, "#{email}_user_data", user_data, expire: :timer.minutes(15))
      Accounts.UserNotifier.deliver_activation_otp(email, otp)

      {:noreply,
       socket
       |> put_flash(
         :info,
         "Email kích hoạt với mã OTP đã được gửi đến #{email}. Vui lòng kiểm tra hộp thư đến hoặc thư mục spam."
       )
       |> push_navigate(
         to: ~p"/users/activation?email=#{URI.encode_www_form(email)}",
         replace: false
       )}
    else
      {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.validate_email_for_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp generate_password do
    # Generate a random 12-character password with letters and numbers
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    length = 12

    for _ <- 1..length, into: "" do
      <<Enum.random(String.to_charlist(chars))>>
    end
  end

  defp generate_otp do
    # Generate an 8-digit OTP
    :rand.uniform(99_999_999)
    |> Integer.to_string()
    |> String.pad_leading(8, "0")
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
