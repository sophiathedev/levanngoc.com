defmodule Levanngoc.External.GoogleDrive do
  alias GoogleApi.Drive.V3.Connection
  alias GoogleApi.Drive.V3.Api.{Files, Permissions, About}
  alias GoogleApi.Drive.V3.Model.File
  alias GoogleApi.Drive.V3.Model.Permission

  def get_conn do
    %Goth.Token{token: token} = Goth.fetch!(Levanngoc.Goth)

    Connection.new(token)
  end

  def new_private_folder(folder_name) do
    conn = get_conn()

    folder_metadata = %File{
      name: folder_name,
      mimeType: "application/vnd.google-apps.folder"
    }

    {:ok, folder} = conn |> Files.drive_files_create(body: folder_metadata)
    %File{id: folder_id} = folder
    Cachex.put(:cache, "google_drive:folder", folder_id, expire: :timer.hours(24))

    create_permission(folder_id, "thedevguy1337@gmail.com")

    folder
  end

  def new_spreadsheet_in_private_folder(folder_id, sheet_name) do
    conn = get_conn()

    file_metadata = %File{
      name: sheet_name,
      mimeType: "application/vnd.google-apps.spreadsheet",
      parents: [folder_id]
    }

    case Files.drive_files_create(conn, body: file_metadata, fields: "id, name, webViewLink") do
      {:ok, file} ->
        {:ok, file}

      error ->
        error
    end
  end

  def check_quota do
    conn = get_conn()

    # Lấy thông tin về bộ nhớ (storageQuota)
    case About.drive_about_get(conn, fields: "storageQuota") do
      {:ok, info} ->
        limit = String.to_integer(info.storageQuota.limit)
        usage = String.to_integer(info.storageQuota.usage)
        usage_in_trash = String.to_integer(info.storageQuota.usageInDriveTrash)

        IO.puts("""
        --- THÔNG TIN DUNG LƯỢNG SERVICE ACCOUNT ---
        Tổng giới hạn: #{limit / 1024 / 1024 / 1024} GB
        Đang sử dụng : #{usage / 1024 / 1024} MB
        Trong thùng rác: #{usage_in_trash / 1024 / 1024} MB
        --------------------------------------------
        """)

      {:error, reason} ->
        IO.inspect(reason, label: "Lỗi check quota")
    end
  end

  # For debug only
  defp create_permission(file_id, email) do
    conn = get_conn()

    permission = %Permission{
      type: :user,
      role: :owner,
      emailAddress: email
    }

    Permissions.drive_permissions_create(conn, file_id, body: permission)
  end
end
