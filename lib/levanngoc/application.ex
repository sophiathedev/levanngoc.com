defmodule Levanngoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize hackney pool for HTTPoison connection pooling
    :hackney_pool.start_pool(:scrapingdog_pool,
      timeout: 150_000,
      max_connections: 50
    )

    children = [
      LevanngocWeb.Telemetry,
      Levanngoc.Repo,
      {DNSCluster, query: Application.get_env(:levanngoc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Levanngoc.PubSub},
      # Start a worker by calling: Levanngoc.Worker.start_link(arg)
      # {Levanngoc.Worker, arg},
      # Start to serve requests, typically the last entry
      LevanngocWeb.Endpoint,
      {Task, fn -> ensure_default_free_plan() end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Levanngoc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Create a default free plan if none exists
  defp ensure_default_free_plan do
    # Wait a bit for the database to be ready
    Process.sleep(2000)

    try do
      case Levanngoc.Billing.get_free_plan() do
        nil ->
          free_plan_attrs = %{
            name: "Free",
            price: 0,
            token_amount_provide: 0
          }

          case Levanngoc.Billing.create_billing_price(free_plan_attrs) do
            {:ok, plan} ->
              IO.puts("Successfully created default free plan with ID: #{plan.id}")

            {:error, changeset} ->
              IO.puts("Failed to create default free plan:")

              Enum.each(changeset.errors, fn {field, {message, _opts}} ->
                IO.puts("- #{field}: #{message}")
              end)
          end

        _ ->
          nil
      end
    rescue
      e ->
        IO.puts("Error creating default free plan: #{inspect(e)}")
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LevanngocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
