defmodule Levanngoc.Billing do
  @moduledoc """
  The Billing context.
  """

  import Ecto.Query, warn: false
  alias Levanngoc.Repo
  alias Levanngoc.Billing.BillingPrice

  @doc """
  Returns the list of billing_prices.

  ## Examples

      iex> list_billing_prices()
      [%BillingPrice{}, ...]

  """
  def list_billing_prices do
    # iwant sort this by price
    import Ecto.Query

    query = from bp in BillingPrice, order_by: [asc: bp.price]
    Repo.all(query)
  end

  @doc """
  Gets a single billing_price.

  Raises `Ecto.NoResultsError` if the Billing price does not exist.

  ## Examples

      iex> get_billing_price!(123)
      %BillingPrice{}

      iex> get_billing_price!(456)
      ** (Ecto.NoResultsError)

  """
  def get_billing_price!(id), do: Repo.get!(BillingPrice, id)

  @doc """
  Creates a billing_price.

  ## Examples

      iex> create_billing_price(%{field: value})
      {:ok, %BillingPrice{}}

      iex> create_billing_price(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_billing_price(attrs \\ %{}) do
    %BillingPrice{}
    |> BillingPrice.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:billing_price_created)
  end

  @doc """
  Updates a billing_price.

  ## Examples

      iex> update_billing_price(billing_price, %{field: new_value})
      {:ok, %BillingPrice{}}

      iex> update_billing_price(billing_price, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_billing_price(%BillingPrice{} = billing_price, attrs) do
    billing_price
    |> BillingPrice.changeset(attrs)
    |> Repo.update()
    |> broadcast(:billing_price_updated)
  end

  @doc """
  Deletes a billing_price.

  ## Examples

      iex> delete_billing_price(billing_price)
      {:ok, %BillingPrice{}}

      iex> delete_billing_price(billing_price)
      {:error, %Ecto.Changeset{}}

  """
  def delete_billing_price(%BillingPrice{} = billing_price) do
    Repo.delete(billing_price)
    |> broadcast(:billing_price_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking billing_price changes.

  ## Examples

      iex> change_billing_price(billing_price)
      %Ecto.Changeset{data: %BillingPrice{}}

  """
  def change_billing_price(%BillingPrice{} = billing_price, attrs \\ %{}) do
    BillingPrice.changeset(billing_price, attrs)
  end

  # PubSub functions for LiveView updates
  def subscribe do
    Phoenix.PubSub.subscribe(Levanngoc.PubSub, "billing")
  end

  defp broadcast({:ok, result}, event) do
    Phoenix.PubSub.broadcast(Levanngoc.PubSub, "billing", {__MODULE__, [event], result})
    {:ok, result}
  end

  defp broadcast({:error, reason}, _event) do
    {:error, reason}
  end

  @doc """
  Gets the free plan (case insensitive name matching 'free').
  """
  def get_free_plan do
    import Ecto.Query

    query =
      from bp in BillingPrice,
        where: fragment("LOWER(?)", bp.name) == ^"free"

    Repo.one(query)
  end

  alias Levanngoc.Billing.BillingHistory

  def create_billing_history(attrs \\ %{}) do
    %BillingHistory{}
    |> BillingHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Sets is_current to false for all billing histories of a user.
  """
  def deactivate_all_user_billing_histories(user_id) do
    from(bh in BillingHistory,
      where: bh.user_id == ^user_id and bh.is_current == true
    )
    |> Repo.update_all(set: [is_current: false])
  end

  @doc """
  Switches user to free plan. This will:
  1. Set is_current to false for all existing billing histories
  2. Create a new billing history for the free plan
  3. Update user's token_amount to 0
  """
  def switch_to_free_plan(user, free_plan) do
    Repo.transaction(fn ->
      # Step 1: Deactivate all current billing histories
      deactivate_all_user_billing_histories(user.id)

      # Step 2: Create new billing history for free plan
      billing_ended_at = DateTime.utc_now() |> DateTime.add(365, :day)

      billing_history_params = %{
        user_id: user.id,
        total_pricing: Decimal.new(0),
        billing_ended_at: billing_ended_at,
        status: :success,
        is_current: true,
        invoice_number: "FREE_#{DateTime.utc_now() |> DateTime.to_unix()}",
        tokens_per_month: 0,
        billing_price_id: free_plan.id
      }

      case create_billing_history(billing_history_params) do
        {:ok, billing_history} ->
          # Step 3: Update user's token_amount to 0
          case Levanngoc.Accounts.update_user_admin(user, %{token_amount: 0}) do
            {:ok, updated_user} ->
              {billing_history, updated_user}

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
