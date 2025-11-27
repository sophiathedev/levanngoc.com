defmodule Levanngoc.Accounts.UserNotifier do
  import Swoosh.Email

  alias Levanngoc.Mailer
  alias Levanngoc.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Levanngoc", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Hướng dẫn cập nhật email", """

    ==============================

    Xin chào #{user.email},

    Bạn có thể thay đổi email bằng cách truy cập vào đường dẫn bên dưới:

    #{url}

    Nếu bạn không yêu cầu thay đổi này, vui lòng bỏ qua email này.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Hướng dẫn đăng nhập", """

    ==============================

    Xin chào #{user.email},

    Bạn có thể đăng nhập vào tài khoản của mình bằng cách truy cập vào đường dẫn bên dưới:

    #{url}

    Nếu bạn không yêu cầu email này, vui lòng bỏ qua.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Hướng dẫn xác nhận", """

    ==============================

    Xin chào #{user.email},

    Bạn có thể xác nhận tài khoản của mình bằng cách truy cập vào đường dẫn bên dưới:

    #{url}

    Nếu bạn không tạo tài khoản với chúng tôi, vui lòng bỏ qua email này.

    ==============================
    """)
  end
end
