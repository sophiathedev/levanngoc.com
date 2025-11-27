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
          Tạo tài khoản
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: LevanngocWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Một email đã được gửi đến #{user.email}, vui lòng truy cập để xác nhận tài khoản của bạn."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
