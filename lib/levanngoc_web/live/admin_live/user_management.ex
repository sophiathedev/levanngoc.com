defmodule LevanngocWeb.AdminLive.UserManagement do
  use LevanngocWeb, :live_view

  alias Levanngoc.Accounts
  alias Levanngoc.Accounts

  import Number.Delimit, only: [number_to_delimited: 2]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Quản lý Người dùng")
     |> assign(:users, Accounts.list_users())
     |> assign(:search_query, "")
     |> assign(:editing_user, nil)
     |> assign(:edit_form, nil)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    users = Accounts.list_users(%{"search" => search})
    {:noreply, assign(socket, users: users, search_query: search)}
  end

  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # We'll use a map for the form to avoid strict changeset validation on fields we don't want to validate yet
    # Or better, create a changeset for the admin update

    {:noreply,
     socket
     |> assign(:editing_user, user)
     |> assign(:edit_form, to_form(Ecto.Changeset.change(user)))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :editing_user, nil)}
  end

  def handle_event("save_user", %{"user" => user_params}, socket) do
    user = socket.assigns.editing_user

    case Accounts.update_user_admin(user, user_params) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cập nhật người dùng thành công")
         |> assign(:editing_user, nil)
         |> assign(:users, Accounts.list_users(%{"search" => socket.assigns.search_query}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset))}
    end
  end

  def handle_event("toggle_ban", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    new_banned_at = if user.banned_at, do: nil, else: DateTime.utc_now()

    case Accounts.update_user_admin(user, %{banned_at: new_banned_at}) do
      {:ok, _updated_user} ->
        msg = if new_banned_at, do: "Người dùng đã bị cấm", else: "Người dùng đã được bỏ cấm"

        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> assign(:users, Accounts.list_users(%{"search" => socket.assigns.search_query}))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cập nhật trạng thái cấm thất bại")}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Xóa người dùng thành công")
         |> assign(:users, Accounts.list_users(%{"search" => socket.assigns.search_query}))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Xóa người dùng thất bại")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold">Quản lý Người dùng</h1>
          <p class="text-neutral-content mt-2">Quản lý tài khoản người dùng</p>
        </div>
      </div>

      <div class="form-control w-full max-w-xs">
        <form phx-change="search" phx-submit="search">
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Tìm kiếm theo email..."
            class="input input-bordered w-full"
            phx-debounce="300"
          />
        </form>
      </div>

      <div class="overflow-x-auto min-h-[400px]">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Email</th>
              <th>Vai trò</th>
              <th>Tokens</th>
              <th>Trạng thái</th>
              <th>Hành động</th>
            </tr>
          </thead>
          <tbody>
            <%= for user <- @users do %>
              <tr>
                <td>{user.email}</td>
                <td>
                  <%= if user.role == 999_999 do %>
                    <span class="badge badge-primary">Superuser</span>
                  <% else %>
                    <span class="badge badge-ghost">User</span>
                  <% end %>
                </td>
                <td>{number_to_delimited(user.token_amount, precision: 0)}</td>
                <td>
                  <%= if user.banned_at do %>
                    <span class="badge badge-error">Đã cấm</span>
                  <% else %>
                    <span class="badge badge-success">Hoạt động</span>
                  <% end %>
                </td>
                <td>
                  <div class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-ghost btn-circle btn-sm">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        class="inline-block w-5 h-5 stroke-current"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 12h.01M12 12h.01M19 12h.01M6 12a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0z"
                        >
                        </path>
                      </svg>
                    </div>
                    <ul
                      tabindex="0"
                      class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52"
                    >
                      <li>
                        <button phx-click="edit_user" phx-value-id={user.id}>Sửa</button>
                      </li>
                      <li>
                        <button phx-click="toggle_ban" phx-value-id={user.id}>
                          {if user.banned_at, do: "Unban", else: "Ban"}
                        </button>
                      </li>
                      <li>
                        <button
                          phx-click="delete_user"
                          phx-value-id={user.id}
                          data-confirm="Bạn có chắc chắn muốn xóa người dùng này?"
                          class="text-error"
                        >
                          Xóa
                        </button>
                      </li>
                    </ul>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @editing_user do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Sửa Người dùng</h3>
            <.form for={@edit_form} phx-submit="save_user" class="space-y-4 py-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Vai trò</span>
                </label>
                <.input
                  field={@edit_form[:role]}
                  type="select"
                  options={[{"Người dùng", 0}, {"Superuser", 999_999}]}
                  class="select select-bordered"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Số lượng Token</span>
                </label>
                <.input field={@edit_form[:token_amount]} type="number" class="input input-bordered" />
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_modal">Hủy</button>
                <button type="submit" class="btn btn-primary">Lưu</button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="close_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end
end
