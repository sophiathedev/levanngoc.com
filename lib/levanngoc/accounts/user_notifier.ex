defmodule Levanngoc.Accounts.UserNotifier do
  import Swoosh.Email

  alias Levanngoc.Mailer
  alias Levanngoc.Accounts.User
  alias Levanngoc.Settings

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Levanngoc", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    config = get_mailer_config()

    with {:ok, _metadata} <- Mailer.deliver(email, config) do
      {:ok, email}
    end
  end

  defp deliver_html(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Levanngoc", "contact@example.com"})
      |> subject(subject)
      |> html_body(body)

    config = get_mailer_config()

    with {:ok, _metadata} <- Mailer.deliver(email, config) do
      {:ok, email}
    end
  end

  defp get_mailer_config do
    case Settings.get_admin_setting() do
      %Settings.AdminSetting{mailgun_api_key: api_key, mailgun_domain: domain}
      when is_binary(api_key) and is_binary(domain) ->
        [api_key: api_key, domain: domain]

      _ ->
        []
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

  @doc """
  Deliver test email.
  """
  def deliver_test_email(user) do
    deliver_html(user.email, "Test Email from Levanngoc", """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Test Email</title>
      </head>
      <body style="font-family: sans-serif; line-height: 1.5; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #2563eb;">Xin chào #{user.email},</h1>
          <p>Đây là email test để kiểm tra cấu hình gửi mail.</p>
          <div style="background-color: #f3f4f6; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 0; font-weight: 600;">Nếu bạn nhận được email này, nghĩa là cấu hình gửi mail đã hoạt động chính xác.</p>
          </div>
          <p style="color: #6b7280; font-size: 0.875rem;">Sent from Levanngoc System</p>
        </div>
      </body>
    </html>
    """)
  end
end
