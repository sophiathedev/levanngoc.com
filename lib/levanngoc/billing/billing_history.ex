defmodule Levanngoc.Billing.BillingHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_histories" do
    field :total_pricing, :decimal
    field :billing_ended_at, :utc_datetime
    field :is_current, :boolean, default: false
    field :next_subscription_at, :utc_datetime

    field :status, Ecto.Enum,
      values: [pending: 0, success: 1, cancel: 2, error: 3],
      default: :pending

    field :invoice_number, :string
    field :tokens_per_month, :integer
    belongs_to :user, Levanngoc.Accounts.User
    belongs_to :billing_price, Levanngoc.Billing.BillingPrice

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(billing_history, attrs) do
    billing_history
    |> cast(attrs, [
      :total_pricing,
      :billing_ended_at,
      :user_id,
      :is_current,
      :next_subscription_at,
      :status,
      :invoice_number,
      :tokens_per_month,
      :billing_price_id
    ])
    |> validate_required([:total_pricing, :billing_ended_at, :user_id])
  end
end
