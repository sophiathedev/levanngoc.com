defmodule Levanngoc.Jobs.ReportsFolderRefresh do
  @moduledoc """
  Oban worker that refreshes the Google Drive reports folder daily.

  This job runs at 3:00 AM every day and performs the following:
  1. Deletes the current cached reports folder from Google Drive
  2. Creates a new reports folder with format: reports_YYYYMMDD
  3. Updates the cache with the new folder ID
  """
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    try do
      conn = Levanngoc.External.GoogleDrive.get_conn()

      # Step 1: Delete the current cached folder if it exists
      case Cachex.get(:cache, :reports_folder_id) do
        {:ok, nil} ->
          :ok

        {:ok, folder_id} ->
          GoogleApi.Drive.V3.Api.Files.drive_files_delete(conn, folder_id)

        {:error, _reason} ->
          :error
      end

      # Step 2: Create new reports folder with current date
      folder_name = "reports_#{Date.utc_today() |> Calendar.strftime("%Y%m%d")}"

      case Levanngoc.External.GoogleDrive.create_new_folder(conn, folder_name) do
        {:ok, %{id: folder_id}} ->
          # Step 3: Cache the new folder ID
          case Cachex.put(:cache, :reports_folder_id, folder_id) do
            {:ok, true} ->
              :ok

            {:error, _reason} ->
              {:error, :cache_failed}
          end

        {:error, _reason} ->
          {:error, :folder_creation_failed}
      end
    rescue
      _e ->
        {:error, :unexpected_error}
    end
  end
end
