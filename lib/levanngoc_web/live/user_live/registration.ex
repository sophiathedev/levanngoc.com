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
    # User is already authenticated, redirect to home
    {:ok, push_navigate(socket, to: "/")}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Generate a random password
    generated_password = generate_password()

    # Add the generated password to user params
    user_params_with_password = Map.merge(user_params, %{
      "password" => generated_password,
      "password_confirmation" => generated_password
    })

    case Accounts.register_user(user_params_with_password) do
      {:ok, _user} ->
        # Send email with the generated password
        email = user_params["email"]
        Levanngoc.Accounts.UserNotifier.deliver_generated_password(email, generated_password)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Email đã được gửi đến tài khoản email của bạn, vui lòng kiểm tra hộp thư đến hoặc thư mục spam."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
