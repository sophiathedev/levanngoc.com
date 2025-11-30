defmodule LevanngocWeb.AdminLive.EmailManagement do
  use LevanngocWeb, :live_view

  alias Levanngoc.Repo
  alias Levanngoc.EmailTemplate

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Quản lý Email Templates")
     |> assign(:templates, load_templates())
     |> assign(:preview_modal_open, false)
     |> assign(:preview_content, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Quản lý Email Templates")
  end

  defp apply_action(socket, :edit, %{"template_id" => template_type_string}) do
    # Convert string to atom
    template_type = String.to_existing_atom(template_type_string)

    # Get template_id from type
    template_id = EmailTemplate.template_id(template_type)

    # Load existing template from database or create new
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    template_data =
      if template do
        %{
          id: template.id,
          template_id: template_id,
          type: template_type,
          type_label: format_type_label(template_type),
          title: template.title,
          content: template.content,
          exists: true
        }
      else
        # Load default from file if available
        default_content = load_default_template(template_type)

        %{
          id: nil,
          template_id: template_id,
          type: template_type,
          type_label: format_type_label(template_type),
          title: "",
          content: default_content,
          exists: false
        }
      end

    socket
    |> assign(:page_title, "Chỉnh sửa Email Template - #{template_data.type_label}")
    |> assign(:template_data, template_data)
    |> assign(
      :form,
      to_form(%{"title" => template_data.title || "", "content" => template_data.content || ""})
    )
    # nil, :content, or :preview
    |> assign(:expanded_view, nil)
  end

  @impl true
  def handle_event("open_preview", %{"template_id" => template_id_str}, socket) do
    template_id = String.to_integer(template_id_str)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    case template do
      nil ->
        {:noreply, put_flash(socket, :error, "Template chưa được cấu hình")}

      %EmailTemplate{} = tmpl ->
        {:noreply,
         socket
         |> assign(:preview_modal_open, true)
         |> assign(:preview_content, tmpl.content)}
    end
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply,
     socket
     |> assign(:preview_modal_open, false)
     |> assign(:preview_content, nil)}
  end

  def handle_event("toggle_expand", %{"view" => view}, socket) do
    current_expanded = socket.assigns.expanded_view
    view_atom = String.to_existing_atom(view)

    new_expanded = if current_expanded == view_atom, do: nil, else: view_atom

    {:noreply, assign(socket, :expanded_view, new_expanded)}
  end

  def handle_event("update_preview", %{"title" => title, "content" => content}, socket) do
    # Update form data to refresh the preview
    {:noreply,
     socket
     |> assign(:form, to_form(%{"title" => title, "content" => content}))}
  end

  def handle_event("save_template", %{"title" => title, "content" => content}, socket) do
    template_data = socket.assigns.template_data

    result =
      if template_data.exists do
        # Update existing template
        template = Repo.get_by!(EmailTemplate, template_id: template_data.template_id)

        template
        |> EmailTemplate.changeset(%{title: title, content: content})
        |> Repo.update()
      else
        # Create new template
        %EmailTemplate{}
        |> EmailTemplate.changeset(%{
          template_id: template_data.template_id,
          title: title,
          content: content
        })
        |> Repo.insert()
      end

    case result do
      {:ok, _template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email template đã được lưu thành công!")
         |> push_navigate(to: ~p"/admin/email-templates")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Lỗi khi lưu template: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @live_action == :edit, do: "h-full", else: "space-y-6"}>
      <%= if @live_action == :index do %>
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-bold">Quản lý Email Templates</h1>
        </div>
        
    <!-- Email Templates Grid -->
        <div class="grid grid-cols-5 gap-4">
          <%= for template <- @templates do %>
            <div class="card bg-base-100 shadow-xl aspect-square hover:shadow-2xl transition-shadow cursor-pointer">
              <div class="card-body p-4 flex flex-col justify-between">
                <div>
                  <div class="flex items-center justify-between mb-2">
                    <span class="badge badge-primary badge-sm">
                      {template.type_label}
                    </span>
                    <%= if template.exists do %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4 text-success"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    <% else %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4 text-base-content/30"
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
                    <% end %>
                  </div>
                  <h3 class="font-semibold text-sm mb-2 line-clamp-2">
                    Email {String.downcase(template.type_label)}
                  </h3>
                </div>
                <div class="flex gap-2 mt-auto">
                  <button
                    class="btn btn-sm btn-ghost flex-1"
                    phx-click="open_preview"
                    phx-value-template_id={template.template_id}
                    disabled={!template.exists}
                  >
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
                        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                      />
                    </svg>
                  </button>
                  <.link
                    navigate={~p"/admin/email-templates/#{template.type}"}
                    class="btn btn-sm btn-ghost flex-1"
                  >
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
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Edit Template Page -->
        <div class="flex flex-col" style="height: calc(100vh - 8rem);">
          <div class="flex-shrink-0 mb-6">
            <div>
              <.link
                navigate={~p"/admin/email-templates"}
                class="text-sm text-base-content/60 hover:text-base-content flex items-center gap-1"
              >
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
                    d="M15 19l-7-7 7-7"
                  />
                </svg>
                Quay lại
              </.link>
              <h1 class="text-2xl font-bold mt-2">Chỉnh sửa Email Template</h1>
              <p class="text-base-content/60 mt-1">
                <span class="badge badge-primary">{@template_data.type_label}</span>
                <%= if @template_data.exists do %>
                  <span class="text-success ml-2">✓ Đã cấu hình</span>
                <% else %>
                  <span class="text-warning ml-2">⚠ Chưa cấu hình</span>
                <% end %>
              </p>
            </div>
          </div>
          
    <!-- Edit Form -->
          <.form
            for={@form}
            id="template-form"
            phx-submit="save_template"
            phx-change="update_preview"
            class="flex flex-col flex-1 gap-4"
          >
            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Tiêu đề (Subject)</span>
              </label>
              <input
                type="text"
                name="title"
                value={@form[:title].value}
                class="input input-bordered w-full"
                placeholder="Nhập tiêu đề email..."
                required
              />
            </div>
            
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
                <label class="label flex justify-between items-center px-0">
                  <span class="label-text font-semibold">Nội dung (HTML)</span>
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
                  phx-debounce="500"
                  class="textarea textarea-bordered w-full flex-1 font-mono text-sm"
                  placeholder="Nhập nội dung HTML của email..."
                  required
                ><%= @form[:content].value %></textarea>
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
                  id="email-preview"
                  srcdoc={@form[:content].value || ""}
                  class="w-full flex-1 border border-base-300 rounded-lg bg-white"
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
                Lưu Template
              </button>
            </div>
          </.form>
        </div>
      <% end %>
      
    <!-- Preview Modal -->
      <%= if @preview_modal_open do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <!-- Backdrop with blur -->
          <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" phx-click="close_preview"></div>
          
    <!-- Modal Content -->
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-base-100 rounded-lg shadow-xl w-[90vw] h-[90vh] flex flex-col">
              <!-- Modal Header -->
              <div class="flex justify-between items-center p-4 border-b border-base-300">
                <h3 class="text-lg font-bold">Email Preview</h3>
                <button
                  type="button"
                  phx-click="close_preview"
                  class="btn btn-sm btn-ghost btn-circle"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
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
                </button>
              </div>
              
    <!-- Modal Body -->
              <div class="flex-1 p-4 overflow-hidden">
                <iframe
                  srcdoc={@preview_content}
                  class="w-full h-full border border-base-300 rounded-lg bg-white"
                  sandbox="allow-same-origin"
                >
                </iframe>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private functions

  defp load_templates do
    import Ecto.Query

    # Get all template types
    template_types = EmailTemplate.template_types()

    # Get existing templates from database
    existing_templates =
      Repo.all(from e in EmailTemplate, order_by: [asc: e.template_id])
      |> Enum.map(fn t -> {t.template_id, t} end)
      |> Map.new()

    # Build template list with all types, marking which exist in DB
    Enum.map(template_types, fn {template_id, type} ->
      case Map.get(existing_templates, template_id) do
        nil ->
          # Template doesn't exist in DB yet
          %{
            id: nil,
            template_id: template_id,
            type: type,
            type_label: format_type_label(type),
            title: nil,
            content: nil,
            exists: false
          }

        db_template ->
          # Template exists in DB
          %{
            id: db_template.id,
            template_id: template_id,
            type: type,
            type_label: format_type_label(type),
            title: db_template.title,
            content: db_template.content,
            exists: true
          }
      end
    end)
  end

  defp format_type_label(type) do
    case type do
      :registration -> "đăng ký"
      _ -> type |> to_string() |> String.capitalize()
    end
  end

  defp load_default_template(:registration) do
    # Load default registration template from file
    template_path = Path.join(:code.priv_dir(:levanngoc), "../template/registration_email.html")

    case File.read(template_path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp load_default_template(_type), do: ""
end
