defmodule Mix.Tasks.CreateDefaultFreePlan do
  use Mix.Task

  alias Levanngoc.Billing

  @shortdoc "Creates a default free plan if one doesn't already exist"

  @moduledoc """
  Creates a default free plan with 0 price and 0 token provide if no plan with the name 'free' exists (case insensitive).
  """

  def run(_args) do
    Mix.Task.run("app.start")

    case Billing.get_free_plan() do
      nil ->
        create_free_plan()
      plan ->
        Mix.shell().info(IO.ANSI.format([:yellow, "A free plan already exists with ID: #{plan.id}"]))
    end
  end

  defp create_free_plan do
    free_plan_attrs = %{
      name: "Free",
      price: 0,
      token_amount_provide: 0
    }

    case Billing.create_billing_price(free_plan_attrs) do
      {:ok, plan} ->
        Mix.shell().info(IO.ANSI.format([:green, "Successfully created free plan with ID: #{plan.id}"]))
      {:error, changeset} ->
        Mix.shell().error("Failed to create free plan:")
        display_errors(changeset)
        System.halt(1)
    end
  end

  defp display_errors(changeset) do
    changeset.errors
    |> Enum.each(fn {field, {message, _opts}} ->
      Mix.shell().error("- #{field}: #{message}")
    end)
  end
end

# Add helper function to Billing context
# We need to add this to the Billing module