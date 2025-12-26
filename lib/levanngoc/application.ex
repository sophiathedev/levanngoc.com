defmodule Levanngoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Cachex.Spec

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

    # google_authentication_scopes = [
    #   # Allow for drive
    #   "https://www.googleapis.com/auth/drive",
    #   # Allow for sheets
    #   "https://www.googleapis.com/auth/spreadsheets"
    # ]

    google_oauth_config = Application.get_env(:levanngoc, :google_oauth)
    google_client_id = google_oauth_config[:client_id]
    google_client_secret = google_oauth_config[:client_secret]
    google_refresh_token = google_oauth_config[:refresh_token]

    google_authentication_source =
      {:refresh_token,
       %{
         "client_id" => google_client_id,
         "client_secret" => google_client_secret,
         "refresh_token" => google_refresh_token
       }, []}

    children = [
      LevanngocWeb.Telemetry,
      Levanngoc.Repo,
      {DNSCluster, query: Application.get_env(:levanngoc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Levanngoc.PubSub},
      Supervisor.child_spec({Cachex, [:cache]}, id: :cachex_cache),
      Supervisor.child_spec(
        {Cachex,
         [name: :popup_cache, expiration: Cachex.Spec.expiration(default: :timer.minutes(30))]},
        id: :cachex_popup_cache
      ),
      Supervisor.child_spec(
        {Cachex,
         [
           name: :crawl_cache,
           expiration: Cachex.Spec.expiration(default: :timer.hours(2))
         ]},
        id: :cachex_crawl_cache
      ),
      # Start Mailgun settings cache
      Levanngoc.Settings.MailgunCache,
      # Start Oban
      {Oban, Application.fetch_env!(:levanngoc, Oban)},
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
      {Goth, name: Levanngoc.Goth, source: google_authentication_source},
      Supervisor.child_spec({Task, fn -> perform_google_drive_cleanup() end},
        id: :google_drive_cleanup_task
      )
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

  # Perform Google Drive cleanup on application start
  defp perform_google_drive_cleanup do
    # Wait for Goth to be ready
    Process.sleep(3000)

    try do
      conn = Levanngoc.External.GoogleDrive.get_conn()

      case Levanngoc.External.GoogleDrive.bulk_clean_up(conn) do
        {:ok, _} ->
          # Create reports folder with current date
          folder_name = "reports_#{Date.utc_today() |> Calendar.strftime("%Y%m%d")}"

          case Levanngoc.External.GoogleDrive.create_new_folder(conn, folder_name) do
            {:ok, %{id: folder_id}} ->
              # Cache the folder ID
              Cachex.put(:cache, :reports_folder_id, folder_id)

            {:error, _reason} ->
              :error
          end

        {:error, _reason} ->
          :error
      end
    rescue
      _e ->
        :error
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
