defmodule LevanngocWeb.UserLive.Activation do
  use LevanngocWeb, :live_view

  import Phoenix.Controller, only: [get_csrf_token: 0]

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
        <div class="min-h-screen flex items-center justify-center p-4">
          <div class="card w-full max-w-md bg-white shadow-xl">
            <div class="card-body items-center text-center">
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

              <h2 class="card-title text-2xl mb-2">Tài khoản chưa được kích hoạt</h2>

              <div class="space-y-4 text-base-content/80">
                <p>
                  Tài khoản của bạn hiện chưa được kích hoạt và không thể truy cập vào hệ thống.
                </p>

                <div class="alert alert-info">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    class="stroke-current shrink-0 w-6 h-6"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    >
                    </path>
                  </svg>
                  <div class="text-left">
                    <p class="font-semibold">Để kích hoạt tài khoản:</p>
                    <p class="text-sm">
                      Chúng tôi đã gửi một mã gồm 8 chữ số đến email của bạn.
                    </p>
                  </div>
                </div>

                <%= if @current_user do %>
                  <div class="text-sm">
                    <p class="font-medium">Email tài khoản:</p>
                    <p class="text-base-content/60">{@current_user.email}</p>
                  </div>
                <% end %>
              </div>

              <div class="card-actions justify-center mt-6 w-full">
                <.link
                  href={~p"/users/log-out"}
                  method="delete"
                  class="btn btn-primary btn-block"
                >
                  Đăng xuất
                </.link>
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = get_current_user(socket)

    # If user is already active, redirect to home
    if current_user && current_user.is_active do
      {:ok, push_navigate(socket, to: "/")}
    else
      {:ok, assign(socket, :current_user, current_user)}
    end
  end

  defp get_current_user(socket) do
    case socket.assigns do
      %{current_scope: %{user: user}} -> user
      _ -> nil
    end
  end
end
