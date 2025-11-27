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
end
