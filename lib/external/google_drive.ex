defmodule Levanngoc.External.GoogleDrive do
  alias GoogleApi.Drive.V3.Connection
  alias GoogleApi.Drive.V3.Api.Files

  alias GoogleApi.Drive.V3.Model.{FileList, File}

  def get_conn do
    %Goth.Token{token: token} = Goth.fetch!(Levanngoc.Goth)

    Connection.new(token)
  end

  def get_shared_folder(conn) do
    query =
      "sharedWithMe = true and mimeType = 'application/vnd.google-apps.folder' and trashed = false"

    opts = [
      q: query,
      fields: "files(id, name, webViewLink)",
      page_size: 10
    ]

    case Files.drive_files_list(conn, opts) do
      {:ok, %FileList{files: [%File{} = file | _]}} ->
        file

      error ->
        error
    end
  end

  def test_create_new_file(conn, folder_id) do
    file_metadata = %File{
      name: "sukablyat",
      mimeType: "application/vnd.google-apps.spreadsheet",
      driveId: folder_id
    }

    case Files.drive_files_create(conn, body: file_metadata) do
      {:ok, %File{} = file} ->
        file

      {:error, reason} ->
        {:error, reason}
    end
  end
end
