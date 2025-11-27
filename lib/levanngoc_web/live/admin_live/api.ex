defmodule LevanngocWeb.AdminLive.Api do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo
  alias Levanngoc.Accounts.UserNotifier

  @impl true
  def mount(_params, _session, socket) do
    # Get existing settings (don't create if doesn't exist)
    settings = get_settings() || %AdminSetting{}

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(
        :scrapingdog_form,
        to_form(%{"api_key" => get_api_key(settings, :scraping_dog_api_key)})
      )
      |> assign(
        :mailgun_form,
        to_form(%{
          "api_key" => get_api_key(settings, :mailgun_api_key),
          "domain" => get_api_key(settings, :mailgun_domain)
        })
      )
      |> assign(
        :sepay_form,
        to_form(%{
          "merchant_id" => get_api_key(settings, :sepay_merchant_id),
          "api_key" => get_api_key(settings, :sepay_api_key)
        })
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("save_scrapingdog", %{"api_key" => api_key}, socket) do
    case save_or_update_setting(:scraping_dog_api_key, api_key) do
      {:ok, updated_settings} ->
        {:noreply,
         socket
         |> assign(:settings, updated_settings)
         |> put_flash(:info, "Lưu API key ScrapingDog thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Lưu API key ScrapingDog thất bại")}
    end
  end

  @impl true
  def handle_event("save_mailgun", %{"api_key" => api_key, "domain" => domain}, socket) do
    mailgun_attrs = %{
      mailgun_api_key: api_key,
      mailgun_domain: domain
    }

    case save_or_update_mailgun_settings(mailgun_attrs) do
      {:ok, updated_settings} ->
        {:noreply,
         socket
         |> assign(:settings, updated_settings)
         |> put_flash(:info, "Lưu cấu hình Mailgun thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Lưu cấu hình Mailgun thất bại")}
    end
  end

  @impl true
  def handle_event("test_mailgun", _params, socket) do
    user = socket.assigns.current_scope.user

    case UserNotifier.deliver_test_email(user) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Đã gửi email test đến #{user.email}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gửi email thất bại: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("save_sepay", params, socket) do
    sepay_attrs = %{
      sepay_merchant_id: params["merchant_id"],
      sepay_api_key: params["api_key"]
    }

    case save_or_update_sepay_settings(sepay_attrs) do
      {:ok, updated_settings} ->
        {:noreply,
         socket
         |> assign(:settings, updated_settings)
         |> put_flash(:info, "Lưu cấu hình SePay thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Lưu cấu hình SePay thất bại")}
    end
  end

  defp get_settings do
    Repo.all(AdminSetting) |> List.first()
  end

  defp get_api_key(nil, _field), do: ""
  defp get_api_key(settings, field), do: Map.get(settings, field) || ""

  defp save_or_update_setting(field, value) do
    case get_settings() do
      nil ->
        # Create new record
        %AdminSetting{}
        |> AdminSetting.changeset(%{field => value})
        |> Repo.insert()

      existing_settings ->
        # Update existing record
        existing_settings
        |> Ecto.Changeset.change(%{field => value})
        |> Repo.update()
    end
  end

  defp save_or_update_mailgun_settings(mailgun_attrs) do
    case get_settings() do
      nil ->
        # Create new record
        %AdminSetting{}
        |> AdminSetting.changeset(mailgun_attrs)
        |> Repo.insert()

      existing_settings ->
        # Update existing record
        existing_settings
        |> AdminSetting.changeset(mailgun_attrs)
        |> Repo.update()
    end
  end

  defp save_or_update_sepay_settings(sepay_attrs) do
    case get_settings() do
      nil ->
        # Create new record
        %AdminSetting{}
        |> AdminSetting.changeset(sepay_attrs)
        |> Repo.insert()

      existing_settings ->
        # Update existing record
        existing_settings
        |> AdminSetting.changeset(sepay_attrs)
        |> Repo.update()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold">Quản lý API</h1>
        <p class="text-neutral-content mt-2">Cấu hình API keys cho các dịch vụ bên ngoài</p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- ScrapingDog API Form -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"
                />
              </svg>
              ScrapingDog API
            </h2>
            <p class="text-sm text-black-content mb-4">
              API key cho dịch vụ ScrapingDog web scraping
            </p>

            <.form for={@scrapingdog_form} phx-submit="save_scrapingdog" class="space-y-4">
              <div class="form-control">
                <label class="label font-semibold text-black">
                  <span class="label-text">API Key</span>
                </label>
                <input
                  type="text"
                  name="api_key"
                  value={@settings.scraping_dog_api_key || ""}
                  placeholder="Nhập ScrapingDog API key"
                  class="input input-bordered w-full font-mono"
                  maxlength="1024"
                />
                <label class="label">
                  <span class="label-text-alt text-black-content">
                    Tối đa 1024 ký tự
                  </span>
                </label>
              </div>

              <div class="card-actions justify-end">
                <button type="submit" class="btn btn-primary">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                  Lưu API Key
                </button>
              </div>
            </.form>
          </div>
        </div>
        
    <!-- Mailgun API Form -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                />
              </svg>
              Mailgun API
            </h2>
            <p class="text-sm text-black-content mb-4">
              API key cho dịch vụ Mailgun email delivery
            </p>

            <.form for={@mailgun_form} phx-submit="save_mailgun" class="space-y-4">
              <div class="form-control">
                <label class="label font-semibold text-black">
                  <span class="label-text">API Key</span>
                </label>
                <input
                  type="text"
                  name="api_key"
                  value={@settings.mailgun_api_key || ""}
                  placeholder="Nhập Mailgun API key"
                  class="input input-bordered w-full font-mono"
                  maxlength="1024"
                />
                <label class="label">
                  <span class="label-text-alt text-black-content">
                    Tối đa 1024 ký tự
                  </span>
                </label>
              </div>

              <div class="form-control">
                <label class="label font-semibold text-black">
                  <span class="label-text">Mailgun Host</span>
                </label>
                <input
                  type="text"
                  name="domain"
                  value={@settings.mailgun_domain || ""}
                  placeholder="Nhập Mailgun Domain (ví dụ: mg.example.com)"
                  class="input input-bordered w-full font-mono"
                  maxlength="255"
                />
                <label class="label">
                  <span class="label-text-alt text-black-content">
                    Tối đa 255 ký tự
                  </span>
                </label>
              </div>

              <div class="card-actions justify-end">
                <button type="button" class="btn" phx-click="test_mailgun">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="h-5 w-5 mr-2"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23-.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5"
                    />
                  </svg>
                  Test
                </button>
                <button type="submit" class="btn btn-primary">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                  Lưu API Key
                </button>
              </div>
            </.form>
          </div>
        </div>
        
    <!-- SePay Configuration Form -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
                />
              </svg>
              SePay Configuration
            </h2>
            <p class="text-sm text-black-content mb-4">
              Cấu hình SePay payment gateway
            </p>

            <.form for={@sepay_form} phx-submit="save_sepay" class="space-y-4">
              <div class="form-control">
                <label class="label font-semibold text-black">
                  <span class="label-text">Merchant ID</span>
                </label>
                <input
                  type="text"
                  name="merchant_id"
                  value={@settings.sepay_merchant_id || ""}
                  placeholder="Nhập SePay Merchant ID"
                  class="input input-bordered w-full font-mono"
                  maxlength="512"
                />
                <label class="label">
                  <span class="label-text-alt text-black-content">
                    Tối đa 512 ký tự
                  </span>
                </label>
              </div>

              <div class="form-control">
                <label class="label font-semibold text-black">
                  <span class="label-text">API Key</span>
                </label>
                <input
                  type="text"
                  name="api_key"
                  value={@settings.sepay_api_key || ""}
                  placeholder="Nhập SePay API key"
                  class="input input-bordered w-full font-mono"
                  maxlength="512"
                />
                <label class="label">
                  <span class="label-text-alt text-black-content">
                    Tối đa 512 ký tự
                  </span>
                </label>
              </div>

              <div class="card-actions justify-end">
                <button type="submit" class="btn btn-primary">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                  Lưu SePay
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
