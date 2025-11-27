defmodule LevanngocWeb.AdminLive.Pricing do
  use LevanngocWeb, :live_view

  alias Levanngoc.Billing
  alias Levanngoc.Billing.BillingPrice

  def mount(_params, _session, socket) do
    if connected?(socket), do: Billing.subscribe()

    {:ok,
     socket
     |> assign(:billing_prices, list_billing_prices())
     |> assign(:show_modal, false)
     |> assign(:modal_action, nil)
     |> assign(:billing_price, nil)
     |> assign(:form, nil)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_info({Levanngoc.Billing, _event, _data}, socket) do
    {:noreply, assign(socket, :billing_prices, list_billing_prices())}
  end

  def handle_event("open_new_modal", _params, socket) do
    billing_price = %BillingPrice{}
    form = to_form(Billing.change_billing_price(billing_price), as: "billing_price")

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:modal_action, :new)
     |> assign(:billing_price, billing_price)
     |> assign(:form, form)}
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    billing_price = Billing.get_billing_price!(id)

    # Prevent editing the free plan
    if String.downcase(billing_price.name) == "free" do
      {:noreply, socket |> put_flash(:error, "Cannot edit the Free plan")}
    else
      form = to_form(Billing.change_billing_price(billing_price), as: "billing_price")

      {:noreply,
       socket
       |> assign(:show_modal, true)
       |> assign(:modal_action, :edit)
       |> assign(:billing_price, billing_price)
       |> assign(:form, form)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:modal_action, nil)
     |> assign(:billing_price, nil)
     |> assign(:form, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    billing_price = Billing.get_billing_price!(id)

    # Prevent deleting the free plan
    if String.downcase(billing_price.name) == "free" do
      {:noreply, socket |> put_flash(:error, "Cannot delete the Free plan")}
    else
      {:ok, _} = Billing.delete_billing_price(billing_price)

      {:noreply, assign(socket, :billing_prices, list_billing_prices())}
    end
  end

  def handle_event("save", %{"billing_price" => billing_price_params}, socket) do
    # Check if trying to create or update to a "free" plan name
    new_name = Map.get(billing_price_params, "name", "")

    if String.downcase(new_name) == "free" do
      {:noreply, socket |> put_flash(:error, "Cannot create or rename to 'Free' plan - use the default Free plan instead")}
    else
      case socket.assigns.modal_action do
        :edit ->
          update_billing_price(socket, socket.assigns.billing_price, billing_price_params)

        :new ->
          create_billing_price(socket, billing_price_params)
      end
    end
  end

  def handle_event("validate", %{"billing_price" => billing_price_params}, socket) do
    changeset =
      socket.assigns.billing_price
      |> Billing.change_billing_price(billing_price_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "billing_price"))}
  end

  defp create_billing_price(socket, billing_price_params) do
    case Billing.create_billing_price(billing_price_params) do
      {:ok, _billing_price} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tạo gói pricing thành công")
         |> assign(:show_modal, false)
         |> assign(:modal_action, nil)
         |> assign(:billing_price, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "billing_price"))}
    end
  end

  defp update_billing_price(socket, billing_price, billing_price_params) do
    case Billing.update_billing_price(billing_price, billing_price_params) do
      {:ok, _billing_price} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cập nhật gói pricing thành công")
         |> assign(:show_modal, false)
         |> assign(:modal_action, nil)
         |> assign(:billing_price, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "billing_price"))}
    end
  end

  defp list_billing_prices do
    Billing.list_billing_prices()
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <header class="mb-6">
        <h2 class="text-2xl font-bold">Quản lý Pricing</h2>
      </header>

      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Tên</th>
              <th>Giá</th>
              <th>Số lượng token</th>
              <th>Ngày tạo</th>
              <th class="text-right">Hành động</th>
            </tr>
          </thead>
          <tbody>
            <%= for billing_price <- @billing_prices do %>
              <tr id={"billing_price-#{billing_price.id}"}>
                <td><%= billing_price.name %></td>
                <td><%= billing_price.price %></td>
                <td><%= billing_price.token_amount_provide %></td>
                <td><%= format_date(billing_price.inserted_at) %></td>
                <td class="text-right">
                  <%= if String.downcase(billing_price.name) != "free" do %>
                    <button
                      phx-click="open_edit_modal"
                      phx-value-id={billing_price.id}
                      class="btn btn-sm btn-outline"
                    >
                      Sửa
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={billing_price.id}
                      data-confirm="Bạn có chắc muốn xóa?"
                      class="btn btn-sm btn-error ml-2"
                    >
                      Xóa
                    </button>
                  <% else %>
                    <span class="text-gray-400 italic">Protected</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="mt-4">
        <button phx-click="open_new_modal" class="btn btn-primary">
          Thêm mới
        </button>
      </div>
    </div>

    <%= if @show_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-2xl">
          <h3 class="font-bold text-lg mb-4">
            <%= if @modal_action == :new, do: "Tạo mới gói pricing", else: "Sửa gói pricing" %>
          </h3>

          <.form for={@form} phx-change="validate" phx-submit="save">
            <div class="form-control mb-4">
              <label class="label font-semibold">Tên gói</label>
              <input
                type="text"
                name="billing_price[name]"
                value={@form[:name].value}
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="form-control mb-4">
              <label class="label font-semibold">Giá</label>
              <input
                type="number"
                step="0.01"
                name="billing_price[price]"
                value={@form[:price].value}
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="form-control mb-4">
              <label class="label font-semibold">Số lượng token</label>
              <input
                type="number"
                name="billing_price[token_amount_provide]"
                value={@form[:token_amount_provide].value}
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="modal-action">
              <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
                <%= if @modal_action == :new, do: "Tạo mới", else: "Cập nhật" %>
              </button>
              <button type="button" class="btn btn-ghost" phx-click="close_modal">
                Hủy
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_date(nil), do: ""
  defp format_date(datetime) do
    case datetime do
      %DateTime{} ->
        "#{datetime.year}-#{pad_zero(datetime.month)}-#{pad_zero(datetime.day)} #{pad_zero(datetime.hour)}:#{pad_zero(datetime.minute)}"
      %NaiveDateTime{} ->
        "#{datetime.year}-#{pad_zero(datetime.month)}-#{pad_zero(datetime.day)} #{pad_zero(datetime.hour)}:#{pad_zero(datetime.minute)}"
      _ ->
        ""
    end
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: "#{num}"
end