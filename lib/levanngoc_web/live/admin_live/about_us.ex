defmodule LevanngocWeb.AdminLive.AboutUs do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  @impl true
  def mount(_params, _session, socket) do
    # Get existing settings (don't create if doesn't exist)
    settings = get_settings() || %AdminSetting{}

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:page_title, "Thông tin giới thiệu")
      |> assign(:selected_policy, "privacy_policy")
      |> assign(:expanded_view, nil)
      |> assign(:form, to_form(%{"content" => get_policy_content(settings, "privacy_policy")}))

    {:ok, socket}
  end

  @impl true
  def handle_event("change_policy", %{"policy" => policy}, socket) do
    content = get_policy_content(socket.assigns.settings, policy)

    {:noreply,
     socket
     |> assign(:selected_policy, policy)
     |> assign(:form, to_form(%{"content" => content}))}
  end

  @impl true
  def handle_event("toggle_expand", %{"view" => view}, socket) do
    current_expanded = socket.assigns.expanded_view
    view_atom = String.to_existing_atom(view)

    new_expanded = if current_expanded == view_atom, do: nil, else: view_atom

    {:noreply, assign(socket, :expanded_view, new_expanded)}
  end

  @impl true
  def handle_event("update_preview", %{"content" => content}, socket) do
    # Update form data to refresh the preview
    {:noreply, assign(socket, :form, to_form(%{"content" => content}))}
  end

  @impl true
  def handle_event(
        "save_about_us",
        %{"selected_policy" => selected_policy, "content" => content},
        socket
      ) do
    content = content || ""

    about_us_attrs = %{String.to_atom(selected_policy) => content}

    case save_or_update_about_us(about_us_attrs) do
      {:ok, updated_settings} ->
        policy_name = get_policy_name(selected_policy)

        {:noreply,
         socket
         |> assign(:settings, updated_settings)
         |> put_flash(:info, "Lưu #{policy_name} thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Lưu thông tin thất bại")}
    end
  end

  defp get_settings do
    Repo.all(AdminSetting) |> List.first()
  end

  defp save_or_update_about_us(about_us_attrs) do
    case get_settings() do
      nil ->
        # Create new record
        %AdminSetting{}
        |> AdminSetting.changeset(about_us_attrs)
        |> Repo.insert()

      existing_settings ->
        # Update existing record
        existing_settings
        |> AdminSetting.changeset(about_us_attrs)
        |> Repo.update()
    end
  end

  defp get_policy_name("privacy_policy"), do: "chính sách bảo mật"
  defp get_policy_name("refund_policy"), do: "chính sách hoàn tiền"
  defp get_policy_name("terms_of_service"), do: "điều khoản sử dụng"

  defp get_policy_content(settings, "privacy_policy"), do: settings.privacy_policy || ""
  defp get_policy_content(settings, "refund_policy"), do: settings.refund_policy || ""
  defp get_policy_content(settings, "terms_of_service"), do: settings.terms_of_service || ""

  defp wrap_preview_content(content) do
    """
    <!DOCTYPE html>
    <html lang="vi">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="stylesheet" href="/assets/css/app.css" />
      </head>
      <body class="antialiased p-4">
        #{content || ""}
      </body>
    </html>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4" style="height: calc(100vh - 8rem);">
      <div class="flex-shrink-0 mb-6">
        <h1 class="text-3xl font-bold">Thông tin giới thiệu</h1>
      </div>
      
    <!-- Policy Selector -->
      <form phx-change="change_policy">
        <div class="form-control w-full max-w-full">
          <label class="label px-0">
            <span class="label-text font-semibold">Chọn trang cần chỉnh sửa</span>
          </label>
          <select
            class="select select-bordered bg-white w-full"
            name="policy"
          >
            <option value="privacy_policy" selected={@selected_policy == "privacy_policy"}>
              Chính sách bảo mật
            </option>
            <option value="terms_of_service" selected={@selected_policy == "terms_of_service"}>
              Điều khoản sử dụng
            </option>
            <option value="refund_policy" selected={@selected_policy == "refund_policy"}>
              Chính sách hoàn tiền
            </option>
          </select>
        </div>
      </form>
      
    <!-- Edit Form -->
      <.form
        for={@form}
        id="about-us-form"
        phx-submit="save_about_us"
        phx-change="update_preview"
        class="flex flex-col flex-1 gap-4"
      >
        <!-- Hidden field to pass selected policy -->
        <input type="hidden" name="selected_policy" value={@selected_policy} />
        
    <!-- Two Column Layout: Content Editor and Preview -->
        <div class={[
          "flex-1 flex overflow-hidden -mx-4 px-4 transition-all duration-300",
          (@expanded_view && "gap-0") || "gap-4"
        ]}>
          <!-- Left Column: Content Editor -->
          <div class={[
            "flex flex-col transition-all duration-300 ease-in-out",
            @expanded_view == :content && "flex-1",
            @expanded_view == :preview && "w-0 opacity-0 overflow-hidden",
            !@expanded_view && "flex-1"
          ]}>
            <!-- Content Editor -->
            <div class="flex flex-col flex-1">
              <label class="label flex justify-between items-center px-0">
                <span class="label-text font-semibold">
                  Nội dung (HTML) - {get_policy_name(@selected_policy) |> String.capitalize()}
                </span>
                <button
                  type="button"
                  phx-click="toggle_expand"
                  phx-value-view="content"
                  class="btn btn-xs btn-ghost"
                >
                  <%= if @expanded_view == :content do %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  <% else %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
                      />
                    </svg>
                  <% end %>
                </button>
              </label>
              <textarea
                name="content"
                key={@selected_policy}
                phx-debounce="500"
                class="textarea textarea-bordered bg-white w-full flex-1 font-mono text-sm"
                placeholder={"Nhập nội dung HTML cho #{get_policy_name(@selected_policy)}..."}
              ><%= @form[:content].value %></textarea>
            </div>
          </div>
          
    <!-- Right Column: Preview -->
          <div class={[
            "flex flex-col transition-all duration-300 ease-in-out",
            @expanded_view == :preview && "flex-1",
            @expanded_view == :content && "w-0 opacity-0 overflow-hidden",
            !@expanded_view && "flex-1"
          ]}>
            <label class="label flex justify-between items-center px-0">
              <span class="label-text font-semibold">Preview</span>
              <button
                type="button"
                phx-click="toggle_expand"
                phx-value-view="preview"
                class="btn btn-xs btn-ghost"
              >
                <%= if @expanded_view == :preview do %>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                <% else %>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
                    />
                  </svg>
                <% end %>
              </button>
            </label>
            <iframe
              id="policy-preview"
              srcdoc={wrap_preview_content(@form[:content].value)}
              class="w-full !bg-white flex-1 border border-base-300 rounded-lg"
              sandbox="allow-same-origin"
            >
            </iframe>
          </div>
        </div>

        <div class="flex justify-end gap-2">
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
            Lưu
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
