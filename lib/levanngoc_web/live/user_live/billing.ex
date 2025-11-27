defmodule LevanngocWeb.UserLive.Billing do
  use LevanngocWeb, :live_view

  alias Levanngoc.Billing
  alias Levanngoc.Repo
  alias Levanngoc.Utils.DateHelper

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    # Ensure billing_price is preloaded
    user = Levanngoc.Repo.preload(user, [:billing_price, current_billing: :billing_price])
    billing_prices = Billing.list_billing_prices()

    socket =
      socket
      |> assign(:current_user, user)
      |> assign(:billing_prices, billing_prices)
      |> assign(:selected_plan, nil)
      |> assign(:months, 1)
      |> assign(:sepay_params, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_plan", %{"id" => id}, socket) do
    plan = Enum.find(socket.assigns.billing_prices, &(&1.id == id))
    months = 1
    sepay_params = build_sepay_params(plan, months, socket.assigns.current_user)
    {:noreply, assign(socket, selected_plan: plan, months: months, sepay_params: sepay_params)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, selected_plan: nil, sepay_params: nil)}
  end

  def handle_event("update_months", %{"months" => months}, socket) do
    months =
      case Integer.parse(months) do
        {m, _} when m >= 1 -> m
        _ -> 1
      end

    sepay_params =
      build_sepay_params(socket.assigns.selected_plan, months, socket.assigns.current_user)

    {:noreply, assign(socket, months: months, sepay_params: sepay_params)}
  end

  def handle_event("subscribe", _, socket) do
    # This event is now triggered by the form submission, but since we are using a real form post
    # to an external URL, this might not be needed if we use a standard form submit.
    # However, the user request says "khi ấn submit thì sẽ submit cho cả form này nhé".
    # If we use a standard <form action="...">, the browser will handle the POST.
    # We can keep this for now or remove it if we change the button to type="submit" inside the form.
    # Let's assume the button outside the form triggers the form submission via JS or is inside the form.
    # Given the structure, I will put the button inside the form or use form="form_id".

    # Actually, to submit the hidden form, we can just let the button be a submit button inside the form.
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="text-center mb-6">
        <.header>
          Gói & Thanh toán
          <:subtitle>Quản lý gói dịch vụ và thanh toán của bạn</:subtitle>
        </.header>
      </div>

      <div class="space-y-6">
        <!-- Current Plan -->
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Gói hiện tại</h2>
            <%= if @current_user.current_billing do %>
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-2xl font-bold text-primary">
                    {@current_user.current_billing.billing_price.name}
                  </p>
                  <p class="text-sm opacity-70">
                    Token hiện tại:
                    <span class="font-semibold">{format_number(@current_user.token_amount)}</span>
                  </p>
                  <p class="text-sm opacity-70">
                    Hết hạn:
                    <span class="font-semibold">
                      {Calendar.strftime(@current_user.current_billing.billing_ended_at, "%d/%m/%Y")}
                    </span>
                  </p>
                  <%= if @current_user.current_billing.next_subscription_at &&
                         DateTime.compare(@current_user.current_billing.next_subscription_at, @current_user.current_billing.billing_ended_at) == :lt do %>
                    <p class="text-sm opacity-70">
                      Gia hạn tiếp theo:
                      <span class="font-semibold text-success">
                        {Calendar.strftime(
                          @current_user.current_billing.next_subscription_at,
                          "%d/%m/%Y"
                        )}
                      </span>
                    </p>
                  <% end %>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold">
                    {format_price(@current_user.current_billing.billing_price.price)} VNĐ<span class="text-sm font-normal opacity-70">
                      / tháng
                    </span>
                  </p>
                  <p class="text-sm opacity-70">
                    {format_number(@current_user.current_billing.billing_price.token_amount_provide)} tokens<span class="opacity-50">
                      / tháng
                    </span>
                  </p>
                </div>
              </div>
            <% else %>
              <p class="text-sm opacity-70">Bạn chưa có gói dịch vụ nào</p>
            <% end %>
          </div>
        </div>
        
    <!-- Available Plans -->
        <div>
          <h2 class="text-xl font-bold mb-4">Các gói dịch vụ</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for plan <- @billing_prices do %>
              <div class={"card bg-base-100 border-2 #{if @current_user.current_billing && @current_user.current_billing.billing_price_id == plan.id, do: "border-primary", else: "border-base-300"}"}>
                <div class="card-body">
                  <h3 class="card-title">
                    {plan.name}
                    <%= if @current_user.current_billing && @current_user.current_billing.billing_price_id == plan.id do %>
                      <span class="badge badge-primary">Hiện tại</span>
                    <% end %>
                  </h3>
                  <div class="my-4">
                    <div class="text-3xl font-bold">
                      {format_price(plan.price)}
                      <span class="text-sm font-normal opacity-70">VNĐ</span>
                    </div>
                    <div class="text-xs opacity-60">/ tháng</div>
                  </div>
                  <div class="space-y-2">
                    <div class="flex items-center gap-2">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5 text-success"
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
                      <span class="text-sm">
                        {format_number(plan.token_amount_provide)} tokens
                        <span class="opacity-60">/ tháng</span>
                      </span>
                    </div>
                  </div>
                  <div class="card-actions justify-end mt-4">
                    <%= if @current_user.current_billing && @current_user.current_billing.billing_price_id == plan.id do %>
                      <button class="btn btn-disabled btn-sm">Đang sử dụng</button>
                    <% else %>
                      <button
                        class="btn btn-primary btn-sm"
                        phx-click="select_plan"
                        phx-value-id={plan.id}
                      >
                        Chọn gói
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Subscription Modal -->
      <%= if @selected_plan do %>
        <div class="modal modal-open">
          <div class="modal-box relative">
            <button class="btn btn-sm btn-circle absolute right-2 top-2" phx-click="close_modal">
              ✕
            </button>
            <h3 class="text-lg font-bold">Đăng ký gói {@selected_plan.name}</h3>

            <div class="py-4 space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Thời hạn (tháng)</span>
                </label>
                <form phx-change="update_months" onsubmit="return false;">
                  <input
                    type="number"
                    name="months"
                    value={@months}
                    min="1"
                    class="input input-bordered w-full"
                  />
                </form>
              </div>

              <div class="bg-base-200 p-4 rounded-lg space-y-2">
                <div class="flex justify-between">
                  <span>Đơn giá:</span>
                  <span class="font-semibold">{format_price(@selected_plan.price)} VNĐ/tháng</span>
                </div>
                <div class="flex justify-between">
                  <span>Thời hạn:</span>
                  <span class="font-semibold">{@months} tháng</span>
                </div>
                <div class="divider my-1"></div>
                <div class="flex justify-between text-lg font-bold text-primary">
                  <span>Tổng cộng:</span>
                  <span>{format_price(Decimal.mult(@selected_plan.price, @months))} VNĐ</span>
                </div>
              </div>
            </div>

            <div class="modal-action">
              <button class="btn" phx-click="close_modal">Hủy</button>

              <form
                id="sepay-form"
                method="POST"
                action="https://pay-sandbox.sepay.vn/v1/checkout/init"
              >
                <%= for {key, value} <- @sepay_params do %>
                  <input type="hidden" name={key} value={value} />
                <% end %>
                <button type="button" phx-click="create_order" class="btn btn-primary">
                  Xác nhận đăng ký
                </button>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("create_order", _, socket) do
    plan = socket.assigns.selected_plan
    months = socket.assigns.months
    user = socket.assigns.current_user
    total_price = Decimal.mult(plan.price, months)

    # Generate invoice_number
    invoice_number = "INV_#{DateTime.utc_now() |> DateTime.to_unix()}"

    # Calculate billing_ended_at
    billing_ended_at = DateHelper.shift_months(DateTime.utc_now(), months)

    billing_history_params = %{
      user_id: user.id,
      total_pricing: total_price,
      billing_ended_at: billing_ended_at,
      status: :pending,
      is_current: false,
      invoice_number: invoice_number,
      tokens_per_month: plan.token_amount_provide,
      billing_price_id: plan.id
    }

    case Billing.create_billing_history(billing_history_params) do
      {:ok, _billing_history} ->
        # Re-build params with the generated invoice_number
        sepay_params = build_sepay_params(plan, months, user, invoice_number)

        {:noreply,
         socket
         |> assign(:sepay_params, sepay_params)
         |> push_event("submit_sepay_form", %{id: "sepay-form"})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Có lỗi xảy ra khi tạo đơn hàng. Vui lòng thử lại.")}
    end
  end

  defp format_price(price) do
    price
    |> Decimal.to_string()
    |> String.to_integer()
    |> Number.Delimit.number_to_delimited(precision: 0)
  end

  defp format_number(number) do
    Number.Delimit.number_to_delimited(number, precision: 0)
  end

  defp build_sepay_params(plan, months, user, invoice_number \\ nil) do
    total_price = Decimal.mult(plan.price, months) |> Decimal.to_integer()

    # Generate a unique invoice number if not provided (for initial render)
    invoice_number = invoice_number || "INV_#{DateTime.utc_now() |> DateTime.to_unix()}"

    query =
      Levanngoc.Settings.AdminSetting
      |> select([s], %{sepay_merchant_id: s.sepay_merchant_id, sepay_api_key: s.sepay_api_key})

    result = Repo.one(query)

    merchant_id = result.sepay_merchant_id
    secret_key = result.sepay_api_key

    Levanngoc.External.Sepay.build_params(%{
      merchant: merchant_id,
      secret_key: secret_key,
      order_amount: total_price,
      order_description: "Thanh toán gói #{plan.name} (#{months} tháng)",
      order_invoice_number: invoice_number,
      payment_method: "BANK_TRANSFER",
      customer_id: user.id
    })
  end
end
