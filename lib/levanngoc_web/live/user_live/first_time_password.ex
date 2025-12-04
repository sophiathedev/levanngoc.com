defmodule LevanngocWeb.UserLive.FirstTimePassword do
  use LevanngocWeb, :live_view

  import Ecto.Query
  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
      <div class="text-center">
        <.header>
          <p>Đặt mật khẩu lần đầu</p>
          <:subtitle>
            Vui lòng đặt mật khẩu mới cho tài khoản của bạn để tiếp tục.
          </:subtitle>
        </.header>
      </div>

      <.form
        for={@form}
        id="first_time_password_form"
        phx-submit="update_password"
      >
        <.input
          field={@form[:password]}
          type="password"
          label="Mật khẩu mới"
          autocomplete="new-password"
          required
        />

        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Xác nhận mật khẩu"
          autocomplete="new-password"
          required
        />

        <.button class="btn btn-primary w-full mt-6">
          Đặt mật khẩu
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, session, socket) do
    user = socket.assigns.current_scope.user

    # Validate token from cache
    case Cachex.get(:cache, "first-time:#{user.email}") do
      {:ok, nil} ->
        # Cache key doesn't exist - login success, redirect to home
        {:ok,
         socket
         |> put_flash(:info, "Đăng nhập thành công!")
         |> push_navigate(to: ~p"/")}

      {:ok, cached_token} when cached_token == token ->
        # Token is valid - show the form
        form = to_form(%{"password" => "", "password_confirmation" => ""}, as: "user")
        {:ok, assign(socket, form: form, token: token, valid_token: true)}

      {:ok, _different_token} ->
        # Token exists but doesn't match - clear session and redirect to login
        logout_user_and_redirect(socket, session)

      {:error, _} ->
        # Cache error - redirect to home
        {:ok,
         socket
         |> put_flash(:info, "Đăng nhập thành công!")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("update_password", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    # Update password without logging out
    changeset = Accounts.User.password_changeset(user, user_params)

    case Levanngoc.Repo.update(changeset) do
      {:ok, _updated_user} ->
        # Clear the first-time token from cache
        Cachex.del(:cache, "first-time:#{user.email}")

        {:noreply,
         socket
         |> put_flash(:info, "Mật khẩu đã được đặt thành công. Chào mừng bạn!")
         |> push_navigate(to: ~p"/")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end

  defp logout_user_and_redirect(socket, session) do
    user = socket.assigns.current_scope.user

    # Delete user's session token
    if user do
      Levanngoc.Repo.delete_all(
        from(t in Levanngoc.Accounts.UserToken, where: t.user_id == ^user.id)
      )
    end

    # Disconnect the LiveView socket using session's live_socket_id
    if live_socket_id = session["live_socket_id"] do
      LevanngocWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    {:ok,
     socket
     |> put_flash(:error, "Token không hợp lệ. Vui lòng đăng nhập lại.")
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
