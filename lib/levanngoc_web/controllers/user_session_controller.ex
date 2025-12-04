defmodule LevanngocWeb.UserSessionController do
  use LevanngocWeb, :controller

  alias Levanngoc.Accounts
  alias LevanngocWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Xác nhận người dùng thành công.")
  end

  def create(conn, params) do
    create(conn, params, "Chào mừng quay trở lại!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        cond do
          user.banned_at ->
            conn
            |> put_flash(
              :error,
              "Người dùng này hiện đã bị ban, vui lòng liên hệ admin để được xử lý"
            )
            |> redirect(to: ~p"/users/log-in")

          !user.is_active ->
            # Store random key in cache before activating
            random_key = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
            Cachex.put(:cache, "first-time:#{user.email}", random_key, expire: :timer.seconds(90))

            {:ok, activated_user} = Accounts.activate_user(user)
            UserAuth.disconnect_sessions(tokens_to_disconnect)

            conn
            |> put_flash(:info, "Vui lòng đặt mật khẩu mới cho tài khoản của bạn")
            |> put_session(:user_return_to, ~p"/users/first-time-password/#{random_key}")
            |> UserAuth.log_in_user(activated_user, user_params)

          true ->
            UserAuth.disconnect_sessions(tokens_to_disconnect)

            # Check if there's a first-time token in cache for this user
            case Cachex.get(:cache, "first-time:#{user.email}") do
              {:ok, token} when not is_nil(token) ->
                # User has a first-time token, redirect to password reset
                conn
                |> put_flash(:info, "Vui lòng đặt mật khẩu mới cho tài khoản của bạn")
                |> put_session(:user_return_to, ~p"/users/first-time-password/#{token}")
                |> UserAuth.log_in_user(user, user_params)

              _ ->
                # Normal login flow
                conn
                |> put_flash(:info, info)
                |> UserAuth.log_in_user(user, user_params)
            end
        end

      _ ->
        conn
        |> put_flash(:error, "Liên kết không hợp lệ hoặc đã hết hạn.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    user = Accounts.get_user_by_email(email)

    cond do
      user && user.banned_at ->
        conn
        |> put_flash(
          :error,
          "Người dùng này hiện đã bị ban, vui lòng liên hệ admin để được xử lý"
        )
        |> redirect(to: ~p"/users/log-in")

      user && !user.is_active && Levanngoc.Accounts.User.valid_password?(user, password) ->
        # User is not active, store random key in cache then activate and redirect
        random_key = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
        Cachex.put(:cache, "first-time:#{user.email}", random_key)

        {:ok, activated_user} = Accounts.activate_user(user)

        conn
        |> put_flash(:info, "Vui lòng đặt mật khẩu mới cho tài khoản của bạn")
        |> put_session(:user_return_to, ~p"/users/first-time-password/#{random_key}")
        |> UserAuth.log_in_user(activated_user, user_params)

      user && Levanngoc.Accounts.User.valid_password?(user, password) ->
        # Check if there's a first-time token in cache for this user
        case Cachex.get(:cache, "first-time:#{user.email}") do
          {:ok, token} when not is_nil(token) ->
            # User has a first-time token, redirect to password reset
            conn
            |> put_flash(:info, "Vui lòng đặt mật khẩu mới cho tài khoản của bạn")
            |> put_session(:user_return_to, ~p"/users/first-time-password/#{token}")
            |> UserAuth.log_in_user(user, user_params)

          _ ->
            # Normal login flow
            conn
            |> put_flash(:info, info)
            |> UserAuth.log_in_user(user, user_params)
        end

      true ->
        conn
        |> put_flash(:error, "Email hoặc mật khẩu không hợp lệ")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Cập nhật mật khẩu thành công!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Đăng xuất thành công.")
    |> UserAuth.log_out_user()
  end
end
