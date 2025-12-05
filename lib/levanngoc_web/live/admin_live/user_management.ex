defmodule LevanngocWeb.AdminLive.UserManagement do
  use LevanngocWeb, :live_view
  import LevanngocWeb.CoreComponents, only: [input: 1]

  alias Levanngoc.Accounts
  alias Levanngoc.Accounts.User
  alias Levanngoc.Billing
  alias Levanngoc.Billing.BillingHistory
  alias Levanngoc.Repo
  alias Levanngoc.Utils.DateHelper
  import Ecto.Query

  @per_page 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Quản lý Người dùng",
       users: [],
       page: 1,
       per_page: @per_page,
       total_count: 0,
       total_pages: 0,
       search_query: "",
       editing_user: nil,
       edit_form: nil,
       changing_password_user: nil,
       password_form: nil,
       extending_user: nil,
       billing_prices: nil,
       extend_form: nil,
       creating_user: false,
       create_form: nil
     )
     |> load_users(1, "")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_params(params, socket)
    {:noreply, socket}
  end

  defp load_users(socket, page, search_query) do
    pagination_data =
      Accounts.paginate_users(%{
        "search" => search_query,
        "page" => page,
        "per_page" => @per_page
      })

    socket
    |> assign(
      users: pagination_data.users,
      page: pagination_data.page,
      per_page: pagination_data.per_page,
      total_count: pagination_data.total_count,
      total_pages: pagination_data.total_pages,
      search_query: search_query
    )
  end

  defp apply_params(params, socket) do
    search_query = Map.get(params, "search", "")
    page = Map.get(params, "page", "1") |> String.to_integer()

    load_users(socket, page, search_query)
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/users?search=#{query}&page=1"
     )}
  end

  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    {:noreply,
     socket
     |> assign(:editing_user, user)
     |> assign(:edit_form, to_form(Ecto.Changeset.change(user)))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :editing_user, nil)}
  end

  def handle_event("open_create_modal", _params, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:noreply,
     socket
     |> assign(:creating_user, true)
     |> assign(:create_form, to_form(changeset))}
  end

  def handle_event("close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:creating_user, false)
     |> assign(:create_form, nil)}
  end

  def handle_event(
        "validate_create_user",
        %{"user" => user_params},
        socket
      ) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :create_form, to_form(changeset))}
  end

  def handle_event("create_user", %{"user" => user_params}, socket) do
    # Merge role into params, default to 0 if not provided
    user_params = Map.put_new(user_params, "role", "0")

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Update user with role and set is_active to true
        role_value =
          case Map.get(user_params, "role") do
            "999999" -> 999_999
            999_999 -> 999_999
            _ -> 0
          end

        Accounts.update_user_admin(user, %{role: role_value, is_active: true})

        {:noreply,
         socket
         |> put_flash(:info, "Tạo người dùng thành công")
         |> assign(:creating_user, false)
         |> assign(:create_form, nil)
         |> then(
           &apply_params(
             %{
               "search" => socket.assigns.search_query,
               "page" => Integer.to_string(socket.assigns.page)
             },
             &1
           )
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :create_form, to_form(changeset))}
    end
  end

  def handle_event("change_password_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    changeset = User.admin_password_changeset(user, %{})

    {:noreply,
     socket
     |> assign(:changing_password_user, user)
     |> assign(:password_form, to_form(changeset))}
  end

  def handle_event("close_password_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:changing_password_user, nil)
     |> assign(:password_form, nil)}
  end

  def handle_event("extend_billing", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    billing_prices = Billing.list_billing_prices()

    {:noreply,
     socket
     |> assign(:extending_user, user)
     |> assign(:billing_prices, billing_prices)
     |> assign(:extend_form, to_form(%{"months" => "1"}))}
  end

  def handle_event("close_extend_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:extending_user, nil)
     |> assign(:billing_prices, nil)
     |> assign(:extend_form, nil)}
  end

  def handle_event(
        "save_extend_billing",
        %{"billing_price_id" => billing_price_id, "months" => months_str},
        socket
      ) do
    user = socket.assigns.extending_user
    months = String.to_integer(months_str)

    # Implement the actual billing extension logic
    case extend_user_billing(user, billing_price_id, months) do
      {:ok, _billing_history} ->
        {:noreply,
         socket
         |> put_flash(:info, "Đã gia hạn gói #{months} tháng thành công")
         |> assign(:extending_user, nil)
         |> assign(:billing_prices, nil)
         |> assign(:extend_form, nil)
         |> then(
           &apply_params(
             %{
               "search" => socket.assigns.search_query,
               "page" => Integer.to_string(socket.assigns.page)
             },
             &1
           )
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Lỗi khi gia hạn gói: #{inspect(reason)}")
         |> assign(:extending_user, nil)
         |> assign(:billing_prices, nil)
         |> assign(:extend_form, nil)}
    end
  end

  def handle_event(
        "validate_password",
        %{"user" => %{"password" => password, "password_confirmation" => password_confirmation}},
        socket
      ) do
    user = socket.assigns.changing_password_user

    changeset =
      user
      |> User.admin_password_changeset(%{
        password: password,
        password_confirmation: password_confirmation
      })
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :password_form, to_form(changeset))}
  end

  def handle_event(
        "save_password",
        %{"user" => %{"password" => password, "password_confirmation" => password_confirmation}},
        socket
      ) do
    user = socket.assigns.changing_password_user

    case Accounts.update_user_password_admin(user, %{
           password: password,
           password_confirmation: password_confirmation
         }) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Đổi mật khẩu thành công")
         |> assign(:changing_password_user, nil)
         |> assign(:password_form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset))}
    end
  end

  def handle_event("save_user", %{"user" => user_params}, socket) do
    user = socket.assigns.editing_user

    case Accounts.update_user_admin(user, user_params) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cập nhật người dùng thành công")
         |> assign(:editing_user, nil)}

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
         |> then(
           &apply_params(
             %{
               "search" => socket.assigns.search_query,
               "page" => Integer.to_string(socket.assigns.page)
             },
             &1
           )
         )}

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
         |> then(
           &apply_params(
             %{
               "search" => socket.assigns.search_query,
               "page" => Integer.to_string(socket.assigns.page)
             },
             &1
           )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Xóa người dùng thất bại")}
    end
  end

  defp extend_user_billing(user, billing_price_id, months) do
    Repo.transaction(fn ->
      # Get the billing price
      billing_price = Billing.get_billing_price!(billing_price_id)

      # Set all existing billing histories to is_current: false
      Repo.update_all(
        BillingHistory |> where([b], b.user_id == ^user.id),
        set: [is_current: false]
      )

      # Calculate dates
      now = DateTime.utc_now()
      billing_ended_at = DateHelper.shift_months(now, months)
      next_subscription_at = DateHelper.shift_months(now, 1)

      # Create invoice number
      invoice_number = "ADMIN_EXTEND_#{DateTime.to_unix(now)}"

      # Calculate total pricing
      total_pricing = Decimal.mult(billing_price.price, Decimal.new(months))

      # Create new billing history
      billing_history_attrs = %{
        user_id: user.id,
        billing_price_id: billing_price_id,
        total_pricing: total_pricing,
        billing_ended_at: billing_ended_at,
        next_subscription_at: next_subscription_at,
        invoice_number: invoice_number,
        tokens_per_month: billing_price.token_amount_provide,
        status: :success,
        is_current: true
      }

      case Billing.create_billing_history(billing_history_attrs) do
        {:ok, billing_history} ->
          # Update user's token amount
          case Accounts.update_user_admin(user, %{
                 token_amount: billing_price.token_amount_provide
               }) do
            {:ok, _updated_user} ->
              billing_history

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp pagination_component(assigns) do
    # Calculate start and end page numbers for pagination
    assigns =
      assigns
      |> assign(:start_page, max(1, assigns.page - 2))
      |> assign(:end_page, min(assigns.total_pages, assigns.page + 2))
      |> assign(
        :showing_from,
        if(assigns.total_count > 0, do: (assigns.page - 1) * assigns.per_page + 1, else: 0)
      )
      |> assign(:showing_to, min(assigns.page * assigns.per_page, assigns.total_count))

    ~H"""
    <div class="flex justify-between items-center px-4 py-3 bg-base-100 border-t border-base-300">
      <div>
        <p class="text-sm text-base-content/70">
          Hiển thị <span class="font-medium text-base-content">{@showing_from}</span>
          đến <span class="font-medium text-base-content">{@showing_to}</span>
          trong tổng số <span class="font-medium text-base-content">{@total_count}</span>
          kết quả <span class="text-xs text-base-content/50">(Trang {@page}/{@total_pages})</span>
        </p>
      </div>

      <div class="join">
        <!-- Previous Button -->
        <%= if @page > 1 do %>
          <.link
            patch={~p"/admin/users?page=#{@page - 1}&search=#{@search_query}"}
            class="join-item btn btn-sm"
          >
            «
          </.link>
        <% else %>
          <button class="join-item btn btn-sm btn-disabled" disabled>
            «
          </button>
        <% end %>

        <%= if @total_pages > 1 do %>
          <!-- First Page -->
          <%= if @start_page > 1 do %>
            <.link
              patch={~p"/admin/users?page=1&search=#{@search_query}"}
              class="join-item btn btn-sm"
            >
              1
            </.link>
            <%= if @start_page > 2 do %>
              <button class="join-item btn btn-sm btn-disabled">...</button>
            <% end %>
          <% end %>
          
    <!-- Page Numbers -->
          <%= for page_num <- @start_page..@end_page do %>
            <%= if page_num == @page do %>
              <button class="join-item btn btn-sm btn-active">
                {page_num}
              </button>
            <% else %>
              <.link
                patch={~p"/admin/users?page=#{page_num}&search=#{@search_query}"}
                class="join-item btn btn-sm"
              >
                {page_num}
              </.link>
            <% end %>
          <% end %>
          
    <!-- Last Page -->
          <%= if @end_page < @total_pages do %>
            <%= if @end_page < @total_pages - 1 do %>
              <button class="join-item btn btn-sm btn-disabled">...</button>
            <% end %>
            <.link
              patch={~p"/admin/users?page=#{@total_pages}&search=#{@search_query}"}
              class="join-item btn btn-sm"
            >
              {@total_pages}
            </.link>
          <% end %>
        <% else %>
          <!-- Single page - just show page 1 as active -->
          <button class="join-item btn btn-sm btn-active">
            1
          </button>
        <% end %>
        
    <!-- Next Button -->
        <%= if @page < @total_pages do %>
          <.link
            patch={~p"/admin/users?page=#{@page + 1}&search=#{@search_query}"}
            class="join-item btn btn-sm"
          >
            »
          </.link>
        <% else %>
          <button class="join-item btn btn-sm btn-disabled" disabled>
            »
          </button>
        <% end %>
      </div>
    </div>
    """
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

      <div class="flex gap-4 items-center">
        <div class="form-control flex-1">
          <form phx-change="search">
            <input
              name="search[query]"
              type="text"
              value={@search_query}
              placeholder="Tìm kiếm theo email..."
              class="input input-bordered w-full"
              phx-debounce="300"
            />
          </form>
        </div>
        <button class="btn btn-primary whitespace-nowrap" phx-click="open_create_modal">
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
              d="M12 4v16m8-8H4"
            />
          </svg>
          Thêm Người dùng
        </button>
      </div>

      <div class="border border-base-300 rounded-lg shadow-lg bg-base-100">
        <div class="overflow-visible">
          <table class="table w-full">
            <thead>
              <tr>
                <th class="bg-base-200">Email</th>
                <th class="bg-base-200">Vai trò</th>
                <th class="bg-base-200">Gói</th>
                <th class="bg-base-200">Hết hạn</th>
                <th class="bg-base-200">Trạng thái</th>
                <th class="bg-base-200 text-right">Hành động</th>
              </tr>
            </thead>
            <tbody>
              <%= if @users == [] do %>
                <tr>
                  <td colspan="6" class="text-center py-8 text-base-content/50">
                    Không tìm thấy người dùng nào
                  </td>
                </tr>
              <% else %>
                <%= for user <- @users do %>
                  <tr class="hover">
                    <td class="font-medium">{user.email}</td>
                    <td>
                      <%= if user.role == 999_999 do %>
                        <span class="badge badge-primary">Superuser</span>
                      <% else %>
                        <span class="badge badge-ghost">User</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.current_billing && user.current_billing.billing_price do %>
                        <span class="font-medium">{user.current_billing.billing_price.name}</span>
                      <% else %>
                        <span class="text-base-content/50">Free</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.current_billing && user.current_billing.billing_ended_at do %>
                        <div class="flex items-center gap-2">
                          <span>
                            {Calendar.strftime(user.current_billing.billing_ended_at, "%d/%m/%Y")}
                          </span>
                          <%= if user.current_billing.next_subscription_at do %>
                            <div
                              class="tooltip tooltip-top"
                              data-tip={
                                "Gia hạn tiếp theo: " <>
                                  Calendar.strftime(user.current_billing.next_subscription_at, "%d/%m/%Y")
                              }
                            >
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-4 w-4 text-info cursor-help"
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
                            </div>
                          <% end %>
                        </div>
                      <% else %>
                        <span class="text-base-content/50">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= cond do %>
                        <% user.banned_at != nil -> %>
                          <span class="badge badge-error">Đã cấm</span>
                        <% !user.is_active -> %>
                          <span class="badge badge-warning">Không hoạt động</span>
                        <% true -> %>
                          <span class="badge badge-success">Hoạt động</span>
                      <% end %>
                    </td>
                    <td class="text-right">
                      <div class="dropdown dropdown-left">
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
                          class="dropdown-content z-[9999] menu p-2 shadow bg-base-100 rounded-box w-52 border border-base-300"
                        >
                          <li>
                            <button phx-click="edit_user" phx-value-id={user.id}>
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
                              Sửa
                            </button>
                          </li>
                          <li>
                            <button phx-click="change_password_user" phx-value-id={user.id}>
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
                                  d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
                                />
                              </svg>
                              Đổi mật khẩu
                            </button>
                          </li>
                          <li>
                            <button phx-click="extend_billing" phx-value-id={user.id}>
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
                                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                                />
                              </svg>
                              Gia hạn gói
                            </button>
                          </li>
                          <div class="divider my-0"></div>
                          <li>
                            <button phx-click="toggle_ban" phx-value-id={user.id}>
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
                                  d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                                />
                              </svg>
                              {if user.banned_at, do: "Bỏ cấm", else: "Cấm"}
                            </button>
                          </li>
                          <div class="divider my-0"></div>
                          <li>
                            <button
                              phx-click="delete_user"
                              phx-value-id={user.id}
                              data-confirm="Bạn có chắc chắn muốn xóa người dùng này?"
                              class="text-error hover:text-white hover:bg-error"
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
                            </button>
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

        <.pagination_component
          page={@page}
          per_page={@per_page}
          total_count={@total_count}
          total_pages={@total_pages}
          search_query={@search_query}
        />
      </div>

      <%= if @editing_user do %>
        <div class="modal modal-open backdrop-blur-sm">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Sửa Người dùng</h3>
            <.form for={@edit_form} phx-submit="save_user" class="space-y-4 py-4">
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Vai trò</span>
                </label>
                <.input
                  field={@edit_form[:role]}
                  type="select"
                  options={[{"Người dùng", 0}, {"Superuser", 999_999}]}
                  class="select select-bordered w-full"
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Trạng thái</span>
                </label>
                <.input
                  field={@edit_form[:is_active]}
                  type="select"
                  options={[{"Không hoạt động", false}, {"Hoạt động", true}]}
                  class="select select-bordered w-full"
                />
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

      <%= if @changing_password_user do %>
        <div class="modal modal-open backdrop-blur-sm">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Đổi mật khẩu</h3>
            <p class="text-sm text-gray-500 mt-2">Người dùng: {@changing_password_user.email}</p>
            <.form
              for={@password_form}
              phx-change="validate_password"
              phx-submit="save_password"
              class="space-y-4 py-4"
            >
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Mật khẩu mới</span>
                </label>
                <.input
                  field={@password_form[:password]}
                  type="password"
                  class="input input-bordered w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Xác nhận mật khẩu</span>
                </label>
                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  class="input input-bordered w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_password_modal">Hủy</button>
                <button type="submit" class="btn btn-primary">Lưu</button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="close_password_modal"></div>
        </div>
      <% end %>

      <%= if @extending_user do %>
        <div class="modal modal-open backdrop-blur-sm">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Gia hạn gói</h3>
            <p class="text-sm text-gray-500 mt-2">Người dùng: {@extending_user.email}</p>
            <form phx-submit="save_extend_billing" class="space-y-4 py-4">
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Chọn gói</span>
                </label>
                <select
                  name="billing_price_id"
                  class="select select-bordered w-full"
                  required
                >
                  <option value="">-- Chọn gói --</option>
                  <%= for billing_price <- @billing_prices do %>
                    <option value={billing_price.id}>
                      {billing_price.name} - {Decimal.to_string(billing_price.price)} VNĐ ({billing_price.token_amount_provide} tokens)
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Số tháng gia hạn</span>
                </label>
                <input
                  type="number"
                  name="months"
                  value="1"
                  min="1"
                  max="12"
                  class="input input-bordered w-full"
                  required
                />
                <label class="label">
                  <span class="label-text-alt">Nhập số tháng muốn gia hạn (1-12 tháng)</span>
                </label>
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_extend_modal">Hủy</button>
                <button type="submit" class="btn btn-primary">Gia hạn</button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="close_extend_modal"></div>
        </div>
      <% end %>

      <%= if @creating_user do %>
        <div class="modal modal-open backdrop-blur-sm">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Thêm Người dùng</h3>
            <.form
              for={@create_form}
              phx-change="validate_create_user"
              phx-submit="create_user"
              class="space-y-4 py-4"
            >
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Email</span>
                </label>
                <.input
                  field={@create_form[:email]}
                  type="email"
                  class="input input-bordered w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Mật khẩu</span>
                </label>
                <.input
                  field={@create_form[:password]}
                  type="password"
                  class="input input-bordered w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Xác nhận mật khẩu</span>
                </label>
                <.input
                  field={@create_form[:password_confirmation]}
                  type="password"
                  class="input input-bordered w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Vai trò</span>
                </label>
                <.input
                  field={@create_form[:role]}
                  type="select"
                  options={[{"Người dùng", 0}, {"Superuser", 999_999}]}
                  class="select select-bordered w-full"
                />
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_create_modal">Hủy</button>
                <button type="submit" class="btn btn-primary">Tạo</button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="close_create_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end
end
