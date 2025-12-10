defmodule Levanngoc.External.GoogleDrive do
  alias GoogleApi.Drive.V3.Connection
  alias GoogleApi.Drive.V3.Api.Files
  alias GoogleApi.Drive.V3.Api.Permissions
  alias GoogleApi.Sheets.V4.Api.Spreadsheets

  alias GoogleApi.Drive.V3.Model.{FileList, File, Permission}

  def get_conn do
    %Goth.Token{token: token} = Goth.fetch!(Levanngoc.Goth)

    Connection.new(token)
  end

  def create_new_folder(conn, folder_name) do
    folder_metadata = %File{
      name: folder_name,
      mimeType: "application/vnd.google-apps.folder"
    }

    Files.drive_files_create(conn, body: folder_metadata)
  end

  def create_new_spreadsheet(conn, folder_id, spreadsheet_name) do
    file_metadata = %File{
      name: spreadsheet_name,
      mimeType: "application/vnd.google-apps.spreadsheet",
      parents: [folder_id]
    }

    Files.drive_files_create(conn, body: file_metadata)
  end

  def bulk_clean_up(conn) do
    case Files.drive_files_list(conn, q: "trashed=false and 'me' in owners") do
      {:ok, %FileList{files: files}} when is_list(files) ->
        results =
          Enum.map(files, fn file ->
            case Files.drive_files_delete(conn, file.id) do
              {:ok, _} -> {:ok, file.id}
              {:error, reason} -> {:error, {file.id, reason}}
            end
          end)

        {successes, failures} =
          Enum.split_with(results, fn
            {:ok, _} -> true
            {:error, _} -> false
          end)

        {:ok, %{deleted: length(successes), failed: length(failures), failures: failures}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def export_to_spreadsheet(conn, folder_id, spreadsheet_name, rows) do
    # Step 1: Create a new spreadsheet in the folder
    case create_new_spreadsheet(conn, folder_id, spreadsheet_name) do
      {:ok, %{id: spreadsheet_id}} ->
        # Step 2: Make the spreadsheet viewable by anyone with the link
        case make_file_public(conn, spreadsheet_id) do
          {:ok, _} ->
            # Step 3: Rename the sheet to "Results"
            case rename_sheet(conn, spreadsheet_id) do
              {:ok, _} ->
                # Step 4: Populate the spreadsheet with data
                case populate_spreadsheet(conn, spreadsheet_id, rows) do
                  {:ok, _} ->
                    {:ok, %{spreadsheet_id: spreadsheet_id, spreadsheet_name: spreadsheet_name}}

                  {:error, reason} ->
                    {:error, reason}
                end

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_file_public(conn, file_id) do
    # Create a permission that allows anyone with the link to view
    permission = %Permission{
      type: "anyone",
      role: "reader"
    }

    Permissions.drive_permissions_create(conn, file_id, body: permission)
  end

  defp rename_sheet(conn, spreadsheet_id) do
    # Get the first sheet ID (default Sheet1)
    case Spreadsheets.sheets_spreadsheets_get(conn, spreadsheet_id) do
      {:ok, spreadsheet} ->
        sheet_id = hd(spreadsheet.sheets).properties.sheetId

        # Rename Sheet1 to "Results"
        request = %GoogleApi.Sheets.V4.Model.BatchUpdateSpreadsheetRequest{
          requests: [
            %GoogleApi.Sheets.V4.Model.Request{
              updateSheetProperties: %GoogleApi.Sheets.V4.Model.UpdateSheetPropertiesRequest{
                properties: %GoogleApi.Sheets.V4.Model.SheetProperties{
                  sheetId: sheet_id,
                  title: "Results"
                },
                fields: "title"
              }
            }
          ]
        }

        Spreadsheets.sheets_spreadsheets_batch_update(conn, spreadsheet_id, body: request)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp populate_spreadsheet(conn, spreadsheet_id, rows) do
    # Prepare the values to update
    value_range = %GoogleApi.Sheets.V4.Model.ValueRange{
      range: "Results!A1",
      values: rows
    }

    # Update the spreadsheet with the data
    Spreadsheets.sheets_spreadsheets_values_update(
      conn,
      spreadsheet_id,
      "Results!A1",
      body: value_range,
      valueInputOption: "RAW"
    )
  end
end
