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

    # Add LoggerFileBackend for file logging
    :logger.add_handler(:file_log, LoggerFileBackend, %{
      config: %{
        path: Application.get_env(:logger, :file_log)[:path] || "production.log",
        level: Application.get_env(:logger, :file_log)[:level] || :info,
        format:
          Application.get_env(:logger, :file_log)[:format] || "$time $metadata[$level] $message\n",
        metadata: Application.get_env(:logger, :file_log)[:metadata] || [:request_id]
      }
    })

    # Google Authentication via service account
    google_credentials =
      Application.get_env(:levanngoc, :google_application_credentials)
      |> File.read!()
      |> Jason.decode!()

    google_authentication_scopes = [
      # Allow for drive
      "https://www.googleapis.com/auth/drive",
      # Allow for sheets
      "https://www.googleapis.com/auth/spreadsheets"
    ]

    google_authentication_source =
      {:service_account, google_credentials, [scopes: google_authentication_scopes]}

    children = [
      LevanngocWeb.Telemetry,
      Levanngoc.Repo,
      {DNSCluster, query: Application.get_env(:levanngoc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Levanngoc.PubSub},
      {Cachex, [:cache]},
      # Start Mailgun settings cache
      Levanngoc.Settings.MailgunCache,
      # Start a worker by calling: Levanngoc.Worker.start_link(arg)
      # {Levanngoc.Worker, arg},
      # Start to serve requests, typically the last entry
      LevanngocWeb.Endpoint,
      Supervisor.child_spec({Task, fn -> ensure_default_free_plan() end},
        id: :ensure_free_plan_task
      ),
      Supervisor.child_spec({Task, fn -> ensure_default_admin_setting() end},
        id: :ensure_admin_setting_task
      ),
      {Goth, name: Levanngoc.Goth, source: google_authentication_source}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Levanngoc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Create a default free plan if none exists
  defp ensure_default_free_plan do
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
            {:error, changeset} ->
              IO.puts("Failed to create default free plan:")

              Enum.each(changeset.errors, fn {field, {message, _opts}} ->
                IO.puts("- #{field}: #{message}")
              end)

            _ ->
              nil
          end

        _ ->
          nil
      end
    rescue
      e ->
        IO.puts("Error creating default free plan: #{inspect(e)}")
    end
  end

  # Create a default admin setting record if none exists
  defp ensure_default_admin_setting do
    # Wait a bit for the database to be ready
    Process.sleep(2000)

    alias Levanngoc.Settings.AdminSetting
    alias Levanngoc.Repo

    try do
      case Repo.all(AdminSetting) |> List.first() do
        nil ->
          case %AdminSetting{}
               |> AdminSetting.changeset(%{})
               |> Repo.insert() do
            {:error, changeset} ->
              IO.puts("Failed to create default admin setting:")

              Enum.each(changeset.errors, fn {field, {message, _opts}} ->
                IO.puts("- #{field}: #{message}")
              end)

            _ ->
              nil
          end

        _ ->
          nil
      end
    rescue
      e ->
        IO.puts("Error creating default admin setting: #{inspect(e)}")
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
