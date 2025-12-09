defmodule LevanngocWeb.AdminLive.PopupManagement do
  use LevanngocWeb, :live_view

  alias Levanngoc.Popup
  alias Levanngoc.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Quản lý Popup")
     |> assign(:popups, load_popups())
     |> assign(:delete_modal_open, false)
     |> assign(:popup_to_delete, nil)
     |> assign(:preview_modal_open, false)
     |> assign(:preview_content, nil)
     |> assign(:preview_title, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Quản lý Popup")
    |> assign(:popups, load_popups())
  end

  defp apply_action(socket, :new, _params) do
    changeset = Popup.changeset(%Popup{}, %{})

    socket
    |> assign(:page_title, "Tạo Popup mới")
    |> assign(:form, to_form(changeset))
    |> assign(:trigger_types, Popup.trigger_types())
    |> assign(:status_types, Popup.status_types())
    |> assign(:delete_modal_open, false)
    |> assign(:popup_to_delete, nil)
    |> assign(:popup, nil)
    |> assign(:preview_modal_open, false)
    |> assign(:preview_content, nil)
    |> assign(:preview_title, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    popup = Repo.get!(Popup, id)
    changeset = Popup.changeset(popup, %{})

    socket
    |> assign(:page_title, "Chỉnh sửa Popup")
    |> assign(:popup, popup)
    |> assign(:form, to_form(changeset))
    |> assign(:trigger_types, Popup.trigger_types())
    |> assign(:status_types, Popup.status_types())
    |> assign(:delete_modal_open, false)
    |> assign(:popup_to_delete, nil)
    |> assign(:preview_modal_open, false)
    |> assign(:preview_content, nil)
    |> assign(:preview_title, nil)
  end

  @impl true
  def handle_event("save_popup", %{"popup" => popup_params}, socket) do
    save_popup(socket, socket.assigns.live_action, popup_params)
  end

  def handle_event("open_delete_modal", %{"popup-id" => popup_id}, socket) do
    popup = Repo.get!(Popup, popup_id)

    {:noreply,
     socket
     |> assign(:delete_modal_open, true)
     |> assign(:popup_to_delete, popup)}
  end

  def handle_event("close_delete_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:delete_modal_open, false)
     |> assign(:popup_to_delete, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    popup = socket.assigns.popup_to_delete

    case Repo.delete(popup) do
      {:ok, _popup} ->
        # Cache published popups after deletion
        cache_published_popups()

        {:noreply,
         socket
         |> assign(:delete_modal_open, false)
         |> assign(:popup_to_delete, nil)
         |> assign(:popups, load_popups())
         |> put_flash(:info, "Popup đã được xóa thành công!")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Không thể xóa popup!")}
    end
  end

  def handle_event("toggle_publish_status", %{"popup-id" => popup_id}, socket) do
    popup = Repo.get!(Popup, popup_id)
    new_status = if popup.status == 0, do: 1, else: 0

    case update_popup(popup, %{"status" => new_status}) do
      {:ok, _popup} ->
        status_message = if new_status == 1, do: "đã được xuất bản", else: "đã chuyển về nháp"

        # Cache published popups after status change
        cache_published_popups()

        {:noreply,
         socket
         |> assign(:popups, load_popups())
         |> put_flash(:info, "Popup #{status_message}!")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Không thể cập nhật trạng thái popup!")}
    end
  end

  def handle_event("open_preview", %{"content" => content, "title" => title}, socket) do
    # Get content and title from the params (sent from JavaScript)
    actual_content = if content && content != "", do: content, else: ""
    raw_title = if title && title != "", do: title, else: "Preview Popup"

    # Capitalize first character of title
    actual_title = String.capitalize(raw_title)

    # Wrap content in a full HTML document with site styles
    wrapped_content = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="stylesheet" href="/assets/css/app.css" />
      </head>
      <body class="antialiased p-4">
        #{actual_content}
      </body>
    </html>
    """

    {:noreply,
     socket
     |> assign(:preview_modal_open, true)
     |> assign(:preview_content, wrapped_content)
     |> assign(:preview_title, actual_title)}
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply,
     socket
     |> assign(:preview_modal_open, false)
     |> assign(:preview_content, nil)
     |> assign(:preview_title, nil)}
  end

  defp save_popup(socket, :new, popup_params) do
    case create_popup(popup_params) do
      {:ok, _popup} ->
        # Cache published popups after creating
        cache_published_popups()

        {:noreply,
         socket
         |> put_flash(:info, "Popup đã được tạo thành công!")
         |> push_navigate(to: ~p"/admin/popups")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_popup(socket, :edit, popup_params) do
    popup = socket.assigns.popup

    case update_popup(popup, popup_params) do
      {:ok, _popup} ->
        # Cache published popups after updating
        cache_published_popups()

        {:noreply,
         socket
         |> put_flash(:info, "Popup đã được cập nhật thành công!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp create_popup(attrs) do
    %Popup{}
    |> Popup.changeset(attrs)
    |> Repo.insert()
  end

  defp update_popup(popup, attrs) do
    popup
    |> Popup.changeset(attrs)
    |> Repo.update()
  end

  defp cache_published_popups do
    import Ecto.Query

    # Query all published popups with trigger_when = visiting_site (0)
    visiting_site_popups =
      Repo.all(
        from p in Popup,
          where: p.status > 0 and p.trigger_when == 0,
          order_by: [desc: p.inserted_at]
      )

    # Cache the visiting_site popups
    Cachex.put(:popup_cache, "visiting_site", visiting_site_popups)
  end

  defp load_popups do
    import Ecto.Query

    Repo.all(from p in Popup, order_by: [desc: p.inserted_at])
  end

  defp format_trigger_type(trigger_type) when is_atom(trigger_type) do
    case trigger_type do
      :visiting_site -> "Khi vào trang web"
      _ -> trigger_type |> to_string() |> String.capitalize()
    end
  end

  defp format_trigger_type(trigger_type) when is_integer(trigger_type) do
    case Popup.trigger_type(trigger_type) do
      nil -> nil
      type -> format_trigger_type(type)
    end
  end

  defp format_trigger_type(nil), do: nil

  defp format_status_type(status_type) when is_atom(status_type) do
    case status_type do
      :draft -> "Bản nháp"
      :published -> "Đã xuất bản"
      :published_for_all -> "Xuất bản cho tất cả"
      _ -> status_type |> to_string() |> String.capitalize()
    end
  end

  defp format_status_type(status_type) when is_integer(status_type) do
    case Popup.status_type(status_type) do
      nil -> nil
      type -> format_status_type(type)
    end
  end

  defp format_status_type(nil), do: nil

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={
      if @live_action in [:new, :edit], do: "flex flex-col h-full space-y-6", else: "space-y-6"
    }>
      <%= if @live_action == :index do %>
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-bold">Quản lý Popup</h1>
          <.link navigate={~p"/admin/popups/new"} class="btn btn-primary">
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
                d="M12 4v16m8-8H4"
              />
            </svg>
            Tạo Popup mới
          </.link>
        </div>
      <% else %>
        <div class="flex-shrink-0">
          <.link
            navigate={~p"/admin/popups"}
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
          <h1 class="text-2xl font-bold mt-2">{@page_title}</h1>
        </div>
      <% end %>

      <%= if @live_action == :index do %>
        <!-- Popups Table -->
        <div class="border border-base-300 rounded-lg shadow-lg bg-base-100 overflow-visible">
          <div class="overflow-visible">
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Tiêu đề</th>
                  <th>Trạng thái</th>
                  <th>Ngày tạo</th>
                  <th>Kích hoạt khi</th>
                  <th class="text-right">Hành động</th>
                </tr>
              </thead>
              <tbody>
                <%= if Enum.empty?(@popups) do %>
                  <tr>
                    <td colspan="5" class="text-center text-base-content/60 py-8">
                      <div class="flex flex-col items-center gap-2">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-12 w-12 text-base-content/40"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
                          />
                        </svg>
                        <p class="text-lg">Chưa có popup nào</p>
                        <p class="text-sm">Nhấn "Tạo Popup mới" để bắt đầu</p>
                      </div>
                    </td>
                  </tr>
                <% else %>
                  <%= for popup <- @popups do %>
                    <tr class="hover">
                      <td>
                        <span class="font-medium">{popup.title}</span>
                      </td>
                      <td>
                        <span class={
                          case Popup.status_type(popup.status) do
                            :draft -> "badge badge-ghost"
                            :published -> "badge badge-success"
                            :published_for_all -> "badge badge-info"
                            _ -> "badge"
                          end
                        }>
                          {format_status_type(popup.status)}
                        </span>
                      </td>
                      <td>
                        {format_datetime(popup.inserted_at)}
                      </td>
                      <td>
                        <%= if popup.trigger_when do %>
                          <div class="flex items-center gap-2">
                            <span class="badge badge-primary">
                              {format_trigger_type(popup.trigger_when)}
                            </span>
                          </div>
                        <% else %>
                          <span class="italic opacity-85">Không có</span>
                        <% end %>
                      </td>
                      <td class="text-right">
                        <div class="dropdown dropdown-end">
                          <button tabindex="0" class="btn btn-sm btn-ghost btn-square">
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
                                d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
                              />
                            </svg>
                          </button>
                          <ul
                            tabindex="0"
                            class="dropdown-content z-[9999] menu p-2 shadow bg-base-100 rounded-box w-52 border border-base-300"
                          >
                            <li>
                              <.link navigate={~p"/admin/popups/#{popup.id}/edit"}>
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
                            </li>
                            <div class="divider my-0"></div>
                            <%= if Popup.status_type(popup.status) == :draft do %>
                              <li>
                                <a phx-click="toggle_publish_status" phx-value-popup-id={popup.id}>
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
                                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                                    />
                                  </svg>
                                  Xuất bản
                                </a>
                              </li>
                            <% else %>
                              <li>
                                <a phx-click="toggle_publish_status" phx-value-popup-id={popup.id}>
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
                                      d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                                    />
                                  </svg>
                                  Chuyển về nháp
                                </a>
                              </li>
                            <% end %>
                            <div class="divider my-0"></div>
                            <li>
                              <a
                                phx-click="open_delete_modal"
                                phx-value-popup-id={popup.id}
                                class="text-error"
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
                                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                                  />
                                </svg>
                                Xóa
                              </a>
                            </li>
                          </ul>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% else %>
        <!-- New Popup Form -->
        <.form
          for={@form}
          id="popup-form"
          phx-submit="save_popup"
          class="flex flex-col h-full space-y-3"
        >
          <!-- Title Field -->
          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Tiêu đề</span>
              <span class="label-text-alt text-error">*</span>
            </label>
            <input
              type="text"
              name="popup[title]"
              value={@form[:title].value}
              class="input input-bordered w-full"
              placeholder="Nhập tiêu đề popup..."
              required
              maxlength="1024"
            />
          </div>
          
    <!-- Slug Field -->
          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Đường dẫn (Slug)</span>
              <span class="label-text-alt text-error">*</span>
            </label>
            <div class="flex gap-2">
              <input
                type="text"
                id="popup-slug-input"
                name="popup[slug]"
                value={@form[:slug].value}
                class="input input-bordered w-full font-mono text-xs"
                placeholder="someSpecial"
                required
                pattern="^[a-zA-Z0-9]+$"
                title="Chỉ được chứa chữ cái và số"
                oninput="this.value = this.value.replace(/[^a-zA-Z0-9]/g, '')"
              />
              <button
                type="button"
                class="btn btn-info"
                onclick="
                  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
                  let result = '';
                  for (let i = 0; i < 16; i++) {
                    result += chars.charAt(Math.floor(Math.random() * chars.length));
                  }
                  document.getElementById('popup-slug-input').value = result;
                "
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
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                  />
                </svg>
                Ngẫu nhiên
              </button>
            </div>
            <%= if @form[:slug].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {translate_error(List.first(@form[:slug].errors))}
                </span>
              </label>
            <% end %>
          </div>
          
    <!-- Trigger When and Status Fields (on same row) -->
          <div class="flex gap-4">
            <!-- Trigger When Field -->
            <div class="form-control flex-1">
              <label class="label">
                <span class="label-text font-semibold">Kích hoạt khi</span>
              </label>
              <select name="popup[trigger_when]" class="select select-bordered w-full">
                <option value="">-- Chọn điều kiện kích hoạt --</option>
                <%= for {id, type} <- @trigger_types do %>
                  <option value={id} selected={@form[:trigger_when].value == id}>
                    {format_trigger_type(type)}
                  </option>
                <% end %>
              </select>
            </div>
            
    <!-- Status Field -->
            <div class="form-control flex-1">
              <label class="label">
                <span class="label-text font-semibold">Trạng thái</span>
              </label>
              <select name="popup[status]" class="select select-bordered w-full">
                <%= for {id, type} <- @status_types do %>
                  <option value={id} selected={@form[:status].value == id}>
                    {format_status_type(type)}
                  </option>
                <% end %>
              </select>
            </div>
          </div>
          
    <!-- Content Field -->
          <div class="form-control flex-1 flex flex-col">
            <label class="label">
              <span class="label-text font-semibold">Nội dung (HTML)</span>
              <span class="label-text-alt text-error">*</span>
            </label>
            <textarea
              id="popup-content-textarea"
              name="popup[content]"
              class="textarea textarea-bordered w-full font-mono flex-1"
              style="font-size: 11px;"
              placeholder="Nhập nội dung HTML của popup..."
              required
            >{@form[:content].value}</textarea>
          </div>
          
    <!-- Action Buttons -->
          <div class="flex gap-2 justify-end">
            <button
              type="button"
              class="btn btn-info"
              phx-click="open_preview"
              onclick="this.setAttribute('phx-value-content', document.getElementById('popup-content-textarea').value); this.setAttribute('phx-value-title', document.querySelector('input[name=\'popup[title]\']').value)"
            >
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
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                />
              </svg>
              Preview
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
              {if @live_action == :new, do: "Tạo Popup", else: "Cập nhật"}
            </button>
          </div>
        </.form>
      <% end %>
      
    <!-- Delete Confirmation Modal -->
      <%= if @delete_modal_open do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <!-- Backdrop with blur -->
          <div
            class="fixed inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_delete_modal"
          >
          </div>
          
    <!-- Modal Content -->
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-base-100 rounded-lg shadow-xl w-full max-w-2xl">
              <!-- Modal Header -->
              <div class="flex justify-between items-center p-4 border-b border-base-300">
                <h3 class="text-lg font-bold">Xác nhận xóa</h3>
                <button
                  type="button"
                  phx-click="close_delete_modal"
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
                <%= if @popup_to_delete do %>
                  <p class="text-base mb-4">
                    Bạn đang chuẩn bị xóa popup:
                  </p>
                  <div class="bg-base-200 p-4 rounded-lg mb-4">
                    <p class="font-semibold text-lg">{@popup_to_delete.title}</p>
                  </div>
                  <div class="alert alert-warning">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                      />
                    </svg>
                    <span>Hành động này không thể hoàn tác!</span>
                  </div>
                <% end %>
              </div>
              
    <!-- Modal Footer -->
              <div class="flex gap-2 justify-end p-4 border-t border-base-300">
                <button
                  type="button"
                  phx-click="close_delete_modal"
                  class="btn btn-ghost"
                >
                  Hủy
                </button>
                <button type="button" phx-click="confirm_delete" class="btn btn-error">
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
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                  Xóa
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Preview Modal -->
      <%= if @preview_modal_open do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <!-- Backdrop with blur -->
          <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" phx-click="close_preview"></div>
          
    <!-- Modal Content - 85% of screen -->
          <div class="flex min-h-full items-center justify-center p-[7.5vh]">
            <div class="relative bg-base-100 rounded-lg shadow-xl w-[85vw] h-[85vh] flex flex-col">
              <!-- Modal Header -->
              <div class="flex justify-between items-center p-4 border-b border-base-300 flex-shrink-0">
                <h3 class="text-lg font-bold">{@preview_title || "Preview Popup"}</h3>
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
              
    <!-- Iframe Content -->
              <div class="flex-1 overflow-hidden border-b border-base-300 rounded-b-lg">
                <iframe
                  srcdoc={@preview_content}
                  class="w-full h-full border-0"
                  sandbox="allow-same-origin allow-popups"
                  title="Popup Preview"
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
end
