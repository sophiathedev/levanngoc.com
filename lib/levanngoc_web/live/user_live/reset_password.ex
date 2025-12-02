defmodule LevanngocWeb.UserLive.ResetPassword do
  use LevanngocWeb, :live_view

  import Phoenix.Controller, only: [get_csrf_token: 0]

  alias Levanngoc.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="vi" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title>
          <%= assigns[:page_title] || "Đặt lại mật khẩu" %>
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
        </script>
      </head>
      <body class="bg-base-100 antialiased">
        <div class="h-screen flex items-center justify-center px-4 sm:px-6 lg:px-8">
          <div class="w-full max-w-md space-y-4">
            <.flash kind={:info} flash={@flash} />
            <.flash kind={:error} flash={@flash} />

            <%= if @valid_token do %>
              <div class="text-center">
                <.header>
                  <p>Đặt lại mật khẩu</p>
                  <:subtitle>
                    Nhập mật khẩu mới của bạn.
                  </:subtitle>
                </.header>
              </div>

              <.form
                for={@form}
                id="reset_password_form"
                phx-submit="reset_password"
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
                  Đặt lại mật khẩu
                </.button>
              </.form>

              <div class="text-center mt-4">
                <.link navigate={~p"/users/log-in"} class="text-sm font-semibold text-brand hover:underline">
                  Quay lại đăng nhập
                </.link>
              </div>
            <% else %>
              <div class="text-center">
                <.header>
                  <p>Liên kết không hợp lệ</p>
                  <:subtitle>
                    Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.
                  </:subtitle>
                </.header>
              </div>

              <div class="alert alert-error">
                <.icon name="hero-x-circle" class="size-6 shrink-0" />
                <div>
                  <p class="font-semibold">Liên kết đã hết hạn hoặc không hợp lệ</p>
                  <p class="text-sm">
                    Vui lòng yêu cầu liên kết đặt lại mật khẩu mới.
                  </p>
                </div>
              </div>

              <div class="text-center mt-6">
                <.link navigate={~p"/users/forgot-password"} class="btn btn-primary w-full">
                  Yêu cầu liên kết mới
                </.link>
              </div>

              <div class="text-center mt-4">
                <.link navigate={~p"/users/log-in"} class="text-sm font-semibold text-brand hover:underline">
                  Quay lại đăng nhập
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      </body>
    </html>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Validate the token and get the user
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(valid_token: false, token: nil, user: nil, page_title: "Liên kết không hợp lệ")
         |> assign_form(%{})}

      user ->
        form = to_form(%{"password" => "", "password_confirmation" => ""}, as: "user")

        {:ok,
         socket
         |> assign(
           valid_token: true,
           token: token,
           user: user,
           page_title: "Đặt lại mật khẩu"
         )
         |> assign(form: form)}
    end
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end

  defp assign_form(socket, params) when is_map(params) do
    form = to_form(params, as: "user")
    assign(socket, :form, form)
  end
end
