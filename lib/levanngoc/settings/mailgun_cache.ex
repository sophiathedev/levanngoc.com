defmodule Levanngoc.Settings.MailgunCache do
  @moduledoc """
  Cache for Mailgun settings to avoid excessive database queries.
  Settings are cached for 5 minutes by default.
  """
  use GenServer
  alias Levanngoc.Repo
  alias Levanngoc.Settings.AdminSetting

  @cache_ttl :timer.minutes(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Get Mailgun settings from cache or database.
  Returns {:ok, %{api_key: String.t(), domain: String.t(), from_email: String.t()}} or {:error, :not_configured}
  """
  def get_mailgun_settings do
    GenServer.call(__MODULE__, :get_mailgun_settings)
  end

  @doc """
  Clear the cache to force a refresh on next request.
  """
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end

  # Server callbacks

  @impl true
  def init(_) do
    {:ok, %{settings: nil, last_fetch: nil}}
  end

  @impl true
  def handle_call(:get_mailgun_settings, _from, state) do
    now = System.monotonic_time(:millisecond)

    should_refresh =
      is_nil(state.last_fetch) or
        now - state.last_fetch > @cache_ttl

    if should_refresh do
      case fetch_mailgun_settings_from_db() do
        {:ok, settings} ->
          new_state = %{settings: settings, last_fetch: now}
          {:reply, {:ok, settings}, new_state}

        {:error, reason} ->
          # Return cached settings if available, even if expired
          if state.settings do
            {:reply, {:ok, state.settings}, state}
          else
            {:reply, {:error, reason}, state}
          end
      end
    else
      {:reply, {:ok, state.settings}, state}
    end
  end

  @impl true
  def handle_cast(:clear_cache, _state) do
    {:noreply, %{settings: nil, last_fetch: nil}}
  end

  defp fetch_mailgun_settings_from_db do
    case Repo.all(AdminSetting) do
      [%AdminSetting{mailgun_api_key: api_key, mailgun_domain: domain} | _]
      when is_binary(api_key) and api_key != "" and is_binary(domain) and domain != "" ->
        # Use mailgun_domain as the from_email host (e.g., "mg.example.com" -> "noreply@mg.example.com")
        from_email = "noreply@#{domain}"
        {:ok, %{api_key: api_key, domain: domain, from_email: from_email}}

      _ ->
        {:error, :not_configured}
    end
  end
end
