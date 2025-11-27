defmodule Levanngoc.Billing.BillingPrice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_prices" do
    field :name, :string
    field :price, :decimal
    field :token_amount_provide, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(billing_price, attrs) do
    billing_price
    |> cast(attrs, [:name, :price, :token_amount_provide])
    |> validate_required([:name, :price, :token_amount_provide])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:token_amount_provide, greater_than_or_equal_to: 0)
    |> validate_length(:name, max: 255)
  end
end