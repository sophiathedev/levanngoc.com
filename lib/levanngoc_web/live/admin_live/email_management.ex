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
     |> assign(:preview_content, nil)
     |> assign(:info_modal_open, false)
     |> assign(:allowed_fields, [])}
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
        default_title = EmailTemplate.default_title(template_type)

        %{
          id: nil,
          template_id: template_id,
          type: template_type,
          type_label: format_type_label(template_type),
          title: default_title,
          content: default_content,
          exists: false
        }
      end

    page_title =
      if template_data.exists && template_data.title && template_data.title != "" do
        "Chỉnh sửa \"#{template_data.title}\" Template"
      else
        "Chỉnh sửa Email Template - #{template_data.type_label}"
      end

    socket
    |> assign(:page_title, page_title)
    |> assign(:template_data, template_data)
    |> assign(
      :form,
      to_form(%{"title" => template_data.title || "", "content" => template_data.content || ""})
    )
    # nil, :content, or :preview
    |> assign(:expanded_view, nil)
    |> assign(:allowed_fields, EmailTemplate.template_fields(template_type))
  end

  @impl true
  def handle_event("open_preview", %{"template_id" => template_id_str}, socket) do
    template_id = String.to_integer(template_id_str)
    template = Repo.get_by(EmailTemplate, template_id: template_id)

    content = case template do
      nil ->
        # Load default template from file
        template_type = EmailTemplate.template_type(template_id)
        load_default_template(template_type)

      %EmailTemplate{} = tmpl ->
        tmpl.content
    end

    {:noreply,
     socket
     |> assign(:preview_modal_open, true)
     |> assign(:preview_content, content)}
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply,
     socket
     |> assign(:preview_modal_open, false)
     |> assign(:preview_content, nil)}
  end

  def handle_event("open_info", _params, socket) do
    {:noreply, assign(socket, :info_modal_open, true)}
  end

  def handle_event("close_info", _params, socket) do
    {:noreply, assign(socket, :info_modal_open, false)}
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

    # Validate required fields are present in content
    required_fields = EmailTemplate.required_template_fields(template_data.type)

    missing_fields =
      Enum.filter(required_fields, fn field ->
        !String.contains?(content, "<<[#{field}]>>")
      end)

    if Enum.empty?(missing_fields) do
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
        {:ok, saved_template} ->
          # Update template_data to reflect it now exists
          updated_template_data =
            Map.merge(template_data, %{
              id: saved_template.id,
              title: saved_template.title,
              content: saved_template.content,
              exists: true
            })

          # Update page title if template has a title
          page_title =
            if saved_template.title && saved_template.title != "" do
              "Chỉnh sửa \"#{saved_template.title}\" Template"
            else
              "Chỉnh sửa Email Template - #{template_data.type_label}"
            end

          {:noreply,
           socket
           |> put_flash(:info, "Email template đã được lưu thành công!")
           |> assign(:template_data, updated_template_data)
           |> assign(:page_title, page_title)}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Lỗi khi lưu template: #{inspect(changeset.errors)}")}
      end
    else
      # Missing required fields
      missing_fields_str =
        missing_fields
        |> Enum.map(&"<<[#{&1}]>>")
        |> Enum.join(", ")

      {:noreply,
       socket
       |> put_flash(:error, "Template thiếu các trường bắt buộc: #{missing_fields_str}")}
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
        
    <!-- Email Templates Table -->
        <div class="overflow-x-auto border border-base-300 rounded-lg shadow-lg bg-base-100">
          <table class="table w-full">
            <thead>
              <tr>
                <th>Loại Template</th>
                <th>Tiêu đề</th>
                <th>Trạng thái</th>
                <th class="text-right">Hành động</th>
              </tr>
            </thead>
            <tbody>
              <%= for template <- @templates do %>
                <tr class="hover">
                  <td>
                    <div class="flex items-center gap-2">
                      <span class="badge badge-primary">
                        {template.type_label}
                      </span>
                    </div>
                  </td>
                  <td>
                    <%= if template.exists do %>
                      <span class="font-medium">{template.title}</span>
                    <% else %>
                      <span class="text-base-content/40 italic">Chưa cấu hình</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if template.exists do %>
                      <div class="flex items-center gap-2">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-5 w-5 text-success"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                            clip-rule="evenodd"
                          />
                        </svg>
                        <span class="text-success font-medium">Đã cấu hình</span>
                      </div>
                    <% else %>
                      <div class="flex items-center gap-2">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-5 w-5 text-warning"
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
                        <span class="text-warning font-medium">Chưa cấu hình</span>
                      </div>
                    <% end %>
                  </td>
                  <td class="text-right">
                    <div class="flex gap-2 justify-end">
                      <button
                        class="btn btn-sm btn-ghost btn-square"
                        phx-click="open_preview"
                        phx-value-template_id={template.template_id}
                        title="Xem trước"
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
                        class="btn btn-sm btn-primary"
                        title="Chỉnh sửa"
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
                        Chỉnh sửa
                      </.link>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
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
              <div class="flex items-center gap-2 mt-2">
                <h1 class="text-2xl font-bold">{@page_title}</h1>
                <button
                  type="button"
                  phx-click="open_info"
                  class="btn btn-circle btn-ghost btn-sm"
                  title="Thông tin các trường cho phép"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 text-info"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </button>
              </div>
              <p class="text-base-content/60 mt-1">
                <span class="badge badge-primary">{@template_data.type_label}</span>
                <%= if @template_data.exists do %>
                  <span class="text-success ml-2">✓ Đã cấu hình</span>
                <% else %>
                  <span class="text-warning ml-2">⚠ Chưa cấu hình (dùng template mặc định)</span>
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
      
    <!-- Info Modal -->
      <%= if @info_modal_open do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <!-- Backdrop with blur -->
          <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" phx-click="close_info"></div>
          
    <!-- Modal Content -->
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-base-100 rounded-lg shadow-xl w-full max-w-2xl">
              <!-- Modal Header -->
              <div class="flex justify-between items-center p-4 border-b border-base-300">
                <h3 class="text-lg font-bold">Các trường cho phép</h3>
                <button
                  type="button"
                  phx-click="close_info"
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
              <div class="p-6">
                <p class="text-sm text-base-content/70 mb-4">
                  Bạn có thể sử dụng các trường sau trong nội dung email của mình:
                </p>
                <table class="table w-full">
                  <tbody>
                    <%= for field <- @allowed_fields do %>
                      <% is_required =
                        field in EmailTemplate.required_template_fields(@template_data.type) %>
                      <tr class="hover">
                        <td class="w-32">
                          <div class="flex flex-col gap-1">
                            <div class="badge badge-primary">
                              {field}
                            </div>
                            <%= if is_required do %>
                              <div class="badge badge-error badge-xs">
                                Bắt buộc
                              </div>
                            <% end %>
                          </div>
                        </td>
                        <td>
                          <p class="text-sm font-medium">
                            {format_field_name(field)}
                            <%= if is_required do %>
                              <span class="text-error">*</span>
                            <% end %>
                          </p>
                          <p class="text-xs text-base-content/60 mt-1">
                            {format_field_description(field)}
                          </p>
                        </td>
                        <td class="w-40 text-right">
                          <code class="text-xs bg-base-300 px-2 py-1 rounded">
                            {"<<[#{field}]>>"}
                          </code>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
                <div class="mt-4 p-3 bg-info/10 rounded-lg space-y-2">
                  <p class="text-xs text-base-content/70">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4 inline mr-1"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    Sử dụng cú pháp <code class="bg-base-300 px-1 rounded">{"<<[tên_trường]>>"}</code>
                    để chèn giá trị động vào email.
                  </p>
                  <%= if !Enum.empty?(EmailTemplate.required_template_fields(@template_data.type)) do %>
                    <p class="text-xs text-error/90">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4 inline mr-1"
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
                      Các trường có dấu <span class="text-error font-bold">*</span>
                      là bắt buộc phải có trong template.
                    </p>
                  <% end %>
                </div>
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
      :forgot_password -> "quên mật khẩu"
      :activation -> "kích hoạt tài khoản"
      :keyword_ranking_report -> "báo cáo thứ hạng từ khóa"
      :insufficient_tokens_for_scheduled_report -> "không đủ token cho báo cáo tự động"
      _ -> type |> to_string() |> String.capitalize()
    end
  end

  defp load_default_template(type) when is_atom(type) or is_binary(type) do
    filename = "#{type}_email.html"
    template_path = Path.join(:code.priv_dir(:levanngoc), "template/#{filename}")

    case File.read(template_path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp format_field_name(field) do
    case field do
      :email -> "Email"
      :password -> "Mật khẩu"
      :reset_url -> "Liên kết đặt lại mật khẩu"
      :otp -> "Mã OTP"
      :total_keywords -> "Tổng số từ khóa"
      :ranked_count -> "Số từ khóa có thứ hạng"
      :not_ranked_count -> "Số từ khóa không có thứ hạng"
      :processing_time -> "Thời gian xử lý"
      :timestamp -> "Thời gian kiểm tra"
      :required_tokens -> "Số token cần thiết"
      :current_tokens -> "Số token hiện tại"
      :missing_tokens -> "Số token thiếu"
      :billing_url -> "Liên kết nâng cấp gói"
      _ -> field |> to_string() |> String.capitalize()
    end
  end

  defp format_field_description(field) do
    case field do
      :email -> "Địa chỉ email của người dùng"
      :password -> "Mật khẩu của người dùng (chỉ hiển thị khi đăng ký)"
      :reset_url -> "URL để người dùng đặt lại mật khẩu"
      :otp -> "Mã OTP 8 chữ số để kích hoạt tài khoản"
      :total_keywords -> "Tổng số từ khóa được kiểm tra"
      :ranked_count -> "Số lượng từ khóa có thứ hạng trong top 100"
      :not_ranked_count -> "Số lượng từ khóa không có thứ hạng"
      :processing_time -> "Thời gian xử lý việc kiểm tra thứ hạng"
      :timestamp -> "Thời gian bắt đầu kiểm tra thứ hạng (định dạng: DD/MM/YYYY HH:MM)"
      :required_tokens -> "Số lượng token cần thiết để gửi báo cáo"
      :current_tokens -> "Số lượng token hiện tại trong tài khoản người dùng"
      :missing_tokens -> "Số lượng token còn thiếu (số âm)"
      :billing_url -> "URL để người dùng nâng cấp gói dịch vụ"
      _ -> "Mô tả chưa có sẵn"
    end
  end
end
