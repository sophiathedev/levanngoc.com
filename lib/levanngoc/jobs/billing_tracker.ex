defmodule Levanngoc.Jobs.BillingTracker do
  @moduledoc """
  Oban worker that tracks billing plans daily.

  This job runs at the beginning of each day and performs the following:
  1. Checks all users with current billing plans
  2. If billing_ended_at has passed, resets user to free plan
  3. If next_subscription_at has passed (but not billing_ended_at), renews the subscription
  """
  use Oban.Worker, queue: :default

  import Ecto.Query
  alias Levanngoc.Repo
  alias Levanngoc.Accounts.User
  alias Levanngoc.Billing
  alias Levanngoc.Billing.BillingHistory
  alias Levanngoc.Utils.DateHelper

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()
    today = DateTime.to_date(now)

    Logger.info("Starting billing tracker job at #{now} (comparing date: #{today})")

    # Get all users with current billing
    users_with_billing =
      from(u in User,
        join: bh in BillingHistory,
        on: bh.user_id == u.id and bh.is_current == true,
        preload: [current_billing: :billing_price]
      )
      |> Repo.all()

    Logger.info("Found #{length(users_with_billing)} users with active billing")

    results =
      Enum.map(users_with_billing, fn user ->
        process_user_billing(user, today)
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    Logger.info(
      "Billing tracker job completed. Success: #{success_count}, Errors: #{error_count}"
    )

    :ok
  end

  defp process_user_billing(user, today) do
    billing = user.current_billing
    billing_end_date = DateTime.to_date(billing.billing_ended_at)

    cond do
      # Case 1: billing_ended_at has passed - switch to free plan
      Date.compare(today, billing_end_date) == :gt ->
        Logger.info("User #{user.id}: Billing expired, switching to free plan")
        switch_to_free_plan(user)

      # Case 2: next_subscription_at has passed - renew subscription
      billing.next_subscription_at != nil ->
        next_subscription_date = DateTime.to_date(billing.next_subscription_at)

        if Date.compare(today, next_subscription_date) == :gt do
          Logger.info("User #{user.id}: Renewing subscription")
          renew_subscription(user, billing)
        else
          {:ok, :no_action}
        end

      # Case 3: No action needed
      true ->
        {:ok, :no_action}
    end
  end

  defp switch_to_free_plan(user) do
    free_plan = Billing.get_free_plan()

    if free_plan do
      case Billing.switch_to_free_plan(user, free_plan) do
        {:ok, {_billing_history, _updated_user}} ->
          Logger.info("User #{user.id}: Successfully switched to free plan")
          {:ok, :switched_to_free}

        {:error, reason} ->
          Logger.error("User #{user.id}: Failed to switch to free plan - #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("Free plan not found in database")
      {:error, :free_plan_not_found}
    end
  end

  defp renew_subscription(user, billing) do
    Repo.transaction(fn ->
      # Calculate next subscription date by adding one month
      new_next_subscription_at = DateHelper.shift_months(billing.next_subscription_at, 1)

      # Update billing history with new next_subscription_at
      billing_changeset =
        billing
        |> BillingHistory.changeset(%{
          next_subscription_at: new_next_subscription_at
        })

      case Repo.update(billing_changeset) do
        {:ok, _updated_billing} ->
          # Reset user's token amount to the plan's token_amount_provide
          token_amount = billing.billing_price.token_amount_provide

          user_changeset =
            user
            |> Ecto.Changeset.change(token_amount: token_amount)

          case Repo.update(user_changeset) do
            {:ok, _updated_user} ->
              Logger.info(
                "User #{user.id}: Subscription renewed. Next renewal: #{new_next_subscription_at}"
              )

              :subscription_renewed

            {:error, changeset} ->
              Logger.error("User #{user.id}: Failed to update token amount - #{inspect(changeset)}")
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Logger.error(
            "User #{user.id}: Failed to update next_subscription_at - #{inspect(changeset)}"
          )

          Repo.rollback(changeset)
      end
    end)
  end
end
