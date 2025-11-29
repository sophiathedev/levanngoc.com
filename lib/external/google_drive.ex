defmodule Levanngoc.External.GoogleDrive do
  alias GoogleApi.Drive.V3.Connection
  alias GoogleApi.Drive.V3.Api.{Files, Permissions}
  alias GoogleApi.Drive.V3.Model.File
  alias GoogleApi.Drive.V3.Model.Permission

  def get_conn do
    %Goth.Token{token: token} = Goth.fetch!(Levanngoc.Goth)

    Connection.new(token)
  end

  def create_private_folder(folder_name) do
    conn = get_conn()

    folder_metadata = %File{
      name: folder_name,
      mimeType: "application/vnd.google-apps.folder"
    }

    {:ok, folder} = conn |> Files.drive_files_create(body: folder_metadata)

    results = conn |> Files.drive_files_list()
    dbg(results)

    create_permission(folder.id, "thedevguy1337@gmail.com")
  end

  # For debug only
  defp create_permission(file_id, email) do
    conn = get_conn()

    permission = %Permission{
      type: :user,
      role: :writer,
      emailAddress: email
    }

    Permissions.drive_permissions_create(conn, file_id, body: permission)
  end
end
