defmodule Levanngoc.Accounts.UserNotifier do
  import Swoosh.Email

  alias Levanngoc.Mailer
  alias Levanngoc.Accounts.User
  alias Levanngoc.Repo
  alias Levanngoc.EmailTemplate
  alias Levanngoc.Settings.MailgunCache

  # Get the from email address from Mailgun settings or use default
  defp get_from_email do
    case MailgunCache.get_mailgun_settings() do
      {:ok, %{from_email: from_email}} ->
        {"Levanngoc", from_email}

      {:ok, %{domain: domain}} ->
        # Fallback if from_email not in cache (old cache data)
        {"Levanngoc", "noreply@#{domain}"}

      {:error, :not_configured} ->
        {"Levanngoc", "contact@example.com"}
    end
  end

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(get_from_email())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp deliver_html(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(get_from_email())
      |> subject(subject)
      |> html_body(body)

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

  @doc """
  Deliver generated password to user email.
  """
  def deliver_generated_password(email, password) do
    # Get the registration template from database or use default file template
    template_id = EmailTemplate.template_id(:registration)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    {title, html_content} =
      case template do
        nil ->
          # No template in database, use the default file template
          template_path =
            Path.join(:code.priv_dir(:levanngoc), "../template/registration_email.html")

          {:ok, content} = File.read(template_path)
          {"[levanngoc.com] Thông tin đăng nhập tài khoản", content}

        %EmailTemplate{} = tmpl ->
          # Use template from database
          {tmpl.title, tmpl.content}
      end

    # Replace placeholders with actual values
    html_body =
      html_content
      |> String.replace("<<[email]>>", email)
      |> String.replace("<<[password]>>", password)

    # Replace placeholders in title as well
    subject =
      title
      |> String.replace("<<[email]>>", email)
      |> String.replace("<<[password]>>", password)

    deliver_html(email, subject, html_body)
  end

  @doc """
  Deliver password reset instructions to user email.
  """
  def deliver_reset_password_instructions(user, url) do
    # Get the forgot_password template from database or use default file template
    template_id = EmailTemplate.template_id(:forgot_password)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    {title, html_content} =
      case template do
        nil ->
          # No template in database, use the default file template
          template_path =
            Path.join(:code.priv_dir(:levanngoc), "../template/forgot_password_email.html")

          {:ok, content} = File.read(template_path)
          {"[levanngoc.com] Đặt lại mật khẩu", content}

        %EmailTemplate{} = tmpl ->
          # Use template from database
          {tmpl.title, tmpl.content}
      end

    # Replace placeholders with actual values
    html_body = String.replace(html_content, "<<[reset_url]>>", url)

    # Replace placeholders in title as well
    subject = String.replace(title, "<<[reset_url]>>", url)

    deliver_html(user.email, subject, html_body)
  end

  @doc """
  Deliver activation OTP to user email.
  """
  def deliver_activation_otp(email, otp) do
    # Get the activation template from database or use default file template
    template_id = EmailTemplate.template_id(:activation)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    {title, html_content} =
      case template do
        nil ->
          # No template in database, use the default file template
          template_path =
            Path.join(:code.priv_dir(:levanngoc), "../template/activation_email.html")

          {:ok, content} = File.read(template_path)
          {"[levanngoc.com] Kích hoạt tài khoản", content}

        %EmailTemplate{} = tmpl ->
          # Use template from database
          {tmpl.title, tmpl.content}
      end

    # Replace placeholders with actual values
    html_body = String.replace(html_content, "<<[otp]>>", otp)

    # Replace placeholders in title as well
    subject = String.replace(title, "<<[otp]>>", otp)

    deliver_html(email, subject, html_body)
  end
end
