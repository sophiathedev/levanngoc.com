defmodule LevanngocWeb.UserLive.Activation do
  use LevanngocWeb, :live_view
  import LevanngocWeb.Layouts, only: [flash_group: 1]

  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="vi" class="[scrollbar-gutter:stable]">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <.live_title>
          Kích hoạt tài khoản
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
        </script>
      </head>
      <body class="bg-base-300 antialiased">
        <.flash_group flash={@flash} />
        <div class="min-h-screen flex items-center justify-center">
          <div class="card w-full max-w-lg bg-white shadow-xl rounded-2xl overflow-hidden">
            <div class="card-body w-full items-center text-center !px-2 ">
              <!-- Warning Icon -->
              <div class="mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-24 w-24 text-warning"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              </div>

              <h2 class="card-title text-2xl mb-2">Kích hoạt tài khoản</h2>

              <div class="space-y-4 text-base-content/80">
                <p>
                  Vui lòng nhập mã OTP gồm 8 chữ số đã được gửi đến email của bạn.
                </p>

                <form phx-submit="verify_otp" class="space-y-6 flex flex-col">
                  <!-- OTP Input Fields -->
                  <div class="flex gap-2 justify-center">
                    <%= for i <- 1..8 do %>
                      <input
                        type="text"
                        inputmode="numeric"
                        maxlength="1"
                        id={"otp-#{i}"}
                        name={"digit_#{i}"}
                        class="input input-bordered w-12 h-14 text-center text-xl font-semibold"
                        phx-hook="OTPInput"
                        data-index={i}
                        autocomplete="off"
                        required
                      />
                    <% end %>
                  </div>

                  <div class="flex flex-col">
                    <button type="submit" class="btn btn-primary">
                      Xác thực
                    </button>

                    <div class="divider my-4">HOẶC</div>

                    <button
                      type="button"
                      class="btn btn-soft btn-primary"
                      phx-click="resend_otp"
                      disabled={@otp_resent}
                    >
                      <%= if @otp_resent do %>
                        Đã gửi lại
                      <% else %>
                        Gửi lại mã OTP
                      <% end %>
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    current_user = get_current_user(socket)

    # If user is already active, redirect to home
    if current_user && current_user.is_active do
      {:ok, push_navigate(socket, to: "/")}
    else
      # Get email from params or current_user (decode if from params)
      email =
        case params["email"] do
          nil -> current_user && current_user.email
          encoded_email -> URI.decode_www_form(encoded_email)
        end

      # Check if there's a valid OTP/registration session for this email
      if email do
        case Cachex.get(:cache, email) do
          {:ok, nil} ->
            # No OTP found, redirect to registration
            {:ok,
             socket
             |> put_flash(:error, "Không tìm thấy phiên kích hoạt. Vui lòng đăng ký lại.")
             |> push_navigate(to: ~p"/users/register")}

          {:ok, _otp} ->
            # Valid OTP session exists
            {:ok,
             socket
             |> assign(:current_user, current_user)
             |> assign(:email, email)
             |> assign(:otp_resent, false)}

          _ ->
            # Error checking cache, redirect to registration
            {:ok,
             socket
             |> put_flash(:error, "Đã xảy ra lỗi. Vui lòng đăng ký lại.")
             |> push_navigate(to: ~p"/users/register")}
        end
      else
        # No email provided, redirect to registration
        {:ok,
         socket
         |> put_flash(:error, "Không tìm thấy email. Vui lòng đăng ký lại.")
         |> push_navigate(to: ~p"/users/register")}
      end
    end
  end

  @impl true
  def handle_event("verify_otp", params, socket) do
    # Combine all 8 digits into a single OTP string
    otp =
      1..8
      |> Enum.map(&Map.get(params, "digit_#{&1}", ""))
      |> Enum.join("")

    email = socket.assigns.email

    if String.length(otp) == 8 && email do
      # Verify OTP from cache
      case Cachex.get(:cache, email) do
        {:ok, cached_otp} when cached_otp == otp ->
          # OTP is valid, get user data from cache
          case Cachex.get(:cache, "#{email}_user_data") do
            {:ok, user_data} ->
              # Create user account
              case Accounts.register_user(user_data) do
                {:ok, _user} ->
                  # Delete OTP and user data from cache
                  Cachex.del(:cache, email)
                  Cachex.del(:cache, "#{email}_user_data")

                  # Send registration email with password
                  Accounts.UserNotifier.deliver_generated_password(
                    user_data.email,
                    user_data.password
                  )

                  {:noreply,
                   socket
                   |> put_flash(
                     :info,
                     "Tài khoản đã được kích hoạt thành công! Email chứa mật khẩu đã được gửi đến #{email}."
                   )
                   |> push_navigate(to: ~p"/users/log-in")}

                {:error, _changeset} ->
                  {:noreply,
                   socket
                   |> put_flash(:error, "Không thể tạo tài khoản. Vui lòng thử lại.")}
              end

            {:ok, nil} ->
              {:noreply,
               socket
               |> put_flash(:error, "Phiên đăng ký đã hết hạn. Vui lòng đăng ký lại.")}

            _ ->
              {:noreply,
               socket
               |> put_flash(:error, "Không tìm thấy thông tin đăng ký. Vui lòng đăng ký lại.")}
          end

        {:ok, _different_otp} ->
          {:noreply,
           socket
           |> put_flash(:error, "Mã OTP không đúng. Vui lòng kiểm tra lại.")}

        {:ok, nil} ->
          {:noreply,
           socket
           |> put_flash(:error, "Mã OTP đã hết hạn. Vui lòng gửi lại mã OTP.")}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "Không tìm thấy mã OTP. Vui lòng gửi lại mã OTP.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Vui lòng nhập đủ 8 chữ số mã OTP.")}
    end
  end

  def handle_event("resend_otp", _params, socket) do
    email = socket.assigns.email

    if not socket.assigns.otp_resent && email do
      # Generate a new 8-digit OTP
      otp = generate_otp()

      # Replace old OTP with new OTP with 15-minute expiration
      Cachex.put(:cache, email, otp, expire: :timer.minutes(15))

      # Send activation email with new OTP
      Accounts.UserNotifier.deliver_activation_otp(email, otp)

      {:noreply,
       socket
       |> put_flash(
         :info,
         "Mã OTP mới đã được gửi đến #{email}. Vui lòng kiểm tra hộp thư đến hoặc thư mục spam."
       )
       |> assign(:otp_resent, true)}
    else
      {:noreply, socket}
    end
  end

  defp generate_otp do
    # Generate an 8-digit OTP
    :rand.uniform(99_999_999)
    |> Integer.to_string()
    |> String.pad_leading(8, "0")
  end

  defp get_current_user(socket) do
    case socket.assigns do
      %{current_scope: %{user: user}} -> user
      _ -> nil
    end
  end
end
