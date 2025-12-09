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
          template_path = Application.app_dir(:levanngoc, "priv/template/registration_email.html")

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
            Application.app_dir(:levanngoc, "priv/template/forgot_password_email.html")

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
          template_path = Application.app_dir(:levanngoc, "priv/template/activation_email.html")

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

  @doc """
  Deliver keyword ranking report with Excel attachment.
  """
  def deliver_keyword_ranking_report(user, report_data, xlsx_content) do
    # Get template from file
    template_path =
      Application.app_dir(:levanngoc, "priv/template/keyword_ranking_report_email.html")

    {:ok, html_content} = File.read(template_path)

    # Replace placeholders with actual values
    html_body =
      html_content
      |> String.replace("<<[email]>>", user.email)
      |> String.replace("<<[total_keywords]>>", to_string(report_data.total_keywords))
      |> String.replace("<<[ranked_count]>>", to_string(report_data.ranked_count))
      |> String.replace("<<[not_ranked_count]>>", to_string(report_data.not_ranked_count))
      |> String.replace("<<[processing_time]>>", report_data.processing_time)
      |> String.replace("<<[timestamp]>>", report_data.timestamp_display)

    subject = "[levanngoc.com] Báo cáo kiểm tra thứ hạng từ khóa"

    # Create email with attachment
    email =
      new()
      |> to(user.email)
      |> from(get_from_email())
      |> subject(subject)
      |> html_body(html_body)
      |> attachment(
        Swoosh.Attachment.new(
          {:data, xlsx_content},
          filename: "keyword_ranking_report_#{report_data.timestamp}.xlsx",
          content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
      )

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver insufficient tokens notification email.
  """
  def deliver_insufficient_tokens_notification(user, token_data) do
    # Get the insufficient_tokens_for_scheduled_report template from database or use default file template
    template_id = EmailTemplate.template_id(:insufficient_tokens_for_scheduled_report)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    {title, html_content} =
      case template do
        nil ->
          # No template in database, use the default file template
          template_path =
            Application.app_dir(
              :levanngoc,
              "priv/template/insufficient_tokens_for_scheduled_report_email.html"
            )

          {:ok, content} = File.read(template_path)
          {"[levanngoc.com] Không đủ token để gửi báo cáo tự động", content}

        %EmailTemplate{} = tmpl ->
          # Use template from database
          {tmpl.title, tmpl.content}
      end

    # Replace placeholders with actual values
    html_body =
      html_content
      |> String.replace("<<[email]>>", user.email)
      |> String.replace("<<[required_tokens]>>", to_string(token_data.required_tokens))
      |> String.replace("<<[current_tokens]>>", to_string(token_data.current_tokens))
      |> String.replace("<<[missing_tokens]>>", to_string(token_data.missing_tokens))
      |> String.replace("<<[billing_url]>>", token_data.billing_url)

    # Replace placeholders in title as well
    subject =
      title
      |> String.replace("<<[email]>>", user.email)
      |> String.replace("<<[required_tokens]>>", to_string(token_data.required_tokens))
      |> String.replace("<<[current_tokens]>>", to_string(token_data.current_tokens))
      |> String.replace("<<[missing_tokens]>>", to_string(token_data.missing_tokens))
      |> String.replace("<<[billing_url]>>", token_data.billing_url)

    deliver_html(user.email, subject, html_body)
  end
end
