defmodule Levanngoc.Mailer do
  @moduledoc """
  Application mailer that dynamically uses Mailgun adapter with database settings.
  """

  alias Levanngoc.Settings.MailgunCache

  @doc """
  Deliver email using Mailgun adapter with settings from database.
  Falls back to configured adapter if Mailgun is not configured.
  """
  def deliver(email) do
    case MailgunCache.get_mailgun_settings() do
      {:ok, %{api_key: api_key, domain: domain}} ->
        # Use Mailgun adapter with settings from database
        config = [
          adapter: Swoosh.Adapters.Mailgun,
          api_key: api_key,
          domain: domain
        ]

        Swoosh.Mailer.deliver(email, config)

      {:error, :not_configured} ->
        # Fall back to default configured adapter from config
        default_config = Application.get_env(:levanngoc, __MODULE__, [])
        Swoosh.Mailer.deliver(email, default_config)
    end
  end
end
