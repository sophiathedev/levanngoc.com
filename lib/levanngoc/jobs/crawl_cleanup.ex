defmodule Levanngoc.Jobs.CrawlCleanup do
  @moduledoc """
  Oban worker to clean up crawl result JSON files after 2 hours.
  """
  use Oban.Worker, queue: :cleanup, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_path" => file_path}}) do
    Logger.info("Cleaning up crawl result file: #{file_path}")

    case File.rm(file_path) do
      :ok ->
        Logger.info("Successfully deleted crawl file: #{file_path}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete crawl file #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedule cleanup job for a file path after 2 hours.
  """
  def schedule_cleanup(file_path) do
    %{file_path: file_path}
    |> __MODULE__.new(schedule_in: {2, :hours})
    |> Oban.insert()
  end
end
