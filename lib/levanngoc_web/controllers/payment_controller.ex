defmodule LevanngocWeb.PaymentController do
  use LevanngocWeb, :controller

  alias Levanngoc.Repo
  import Ecto.Query, warn: false
  alias Levanngoc.Utils.DateHelper

  alias Levanngoc.Billing.BillingHistory

  def received_success_payment(conn, %{
        "customer" => %{"customer_id" => user_id},
        "notification_type" => "ORDER_PAID",
        "order" => %{"order_invoice_number" => invoice_number, "order_status" => "CAPTURED"}
      }) do
    Repo.update_all(
      BillingHistory |> where([b], b.user_id == ^user_id),
      set: [is_current: false]
    )

    billing_history =
      Repo.get_by(BillingHistory, invoice_number: invoice_number)
      |> Repo.preload(:billing_price)
      |> Repo.preload(:user)

    %BillingHistory{user: user, billing_price: billing_price} = billing_history

    user
    |> Ecto.Changeset.change(%{token_amount: billing_price.token_amount_provide})
    |> Repo.update!()

    next_subscription_datetime = DateHelper.shift_months(billing_history.inserted_at, 1)

    Repo.get_by(BillingHistory, invoice_number: invoice_number)
    |> Ecto.Changeset.change(%{
      status: :success,
      next_subscription_at: next_subscription_datetime,
      is_current: true
    })
    |> Repo.update!()

    text(conn, "success")
  end
end
