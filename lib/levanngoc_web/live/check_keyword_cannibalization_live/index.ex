defmodule LevanngocWeb.CheckKeywordCannibalizationLive.Index do
  use LevanngocWeb, :live_view

  require Logger

  alias Levanngoc.External.GoogleDrive
  alias Levanngoc.{KeywordCannibalizationProject, KeywordCannibalizationProjects}

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user

    # Load user's projects
    projects = KeywordCannibalizationProjects.list_projects(user.id)

    # Check if there's a running project to auto-subscribe
    running_project = KeywordCannibalizationProjects.get_running_project(user.id)

    # Subscribe to running project if exists
    if running_project do
      Phoenix.PubSub.subscribe(
        Levanngoc.PubSub,
        "cannibalization_project:#{running_project.id}"
      )
    end

    progress_message =
      if running_project do
        case Cachex.get(:cache, {:cannibalization_progress, running_project.id}) do
          {:ok, msg} when is_binary(msg) -> msg
          _ -> "Đang xử lý..."
        end
      else
        nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra Ăn thịt từ khóa")
     |> assign(:projects, projects)
     |> assign(:running_project_id, running_project && running_project.id)
     |> assign(:progress_message, progress_message)
     |> assign(:show_modal, false)
     |> assign(:modal_action, nil)
     |> assign(:modal_project, nil)
     |> assign(:form, nil)
     |> assign(:is_edit_mode, true)
     |> assign(:manual_keywords, "")
     |> assign(:cannibalization_results, [])
     |> assign(:show_result_modal, false)
     |> assign(:selected_project, nil)
     |> assign(:selected_keyword_index, 0)
     |> assign(:domain_input, "")
     |> assign(:user_email, Map.get(session, "user_email", "anonymous"))
     |> assign(:session_id, Map.get(session, "session_id", "unknown"))
     |> allow_upload(:file,
       accept: ~w(.xlsx .csv .txt),
       max_entries: 1,
       max_file_size: 32_000_000
     )
     |> LevanngocWeb.TrackToolVisit.track_visit("/check-keyword-cannibalization")}
  end

  # Modal Management Event Handlers

  @impl true
  def handle_event("open_new_project_modal", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    if KeywordCannibalizationProjects.has_running_project?(user_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Bạn đã có một dự án đang chạy. Vui lòng đợi hoàn thành.")}
    else
      # Create empty project struct for form
      project = %KeywordCannibalizationProject{}
      changeset = KeywordCannibalizationProject.changeset(project, %{})
      form = to_form(changeset, as: "project")

      {:noreply,
       socket
       |> assign(:show_modal, true)
       |> assign(:modal_action, :new)
       |> assign(:modal_project, project)
       |> assign(:form, form)
       |> assign(:manual_keywords, "")
       |> assign(:is_edit_mode, true)}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:modal_action, nil)
     |> assign(:modal_project, nil)
     |> assign(:form, nil)
     |> assign(:manual_keywords, "")
     |> assign(:is_edit_mode, true)}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      socket.assigns.modal_project
      |> KeywordCannibalizationProject.changeset(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "project"))}
  end

  # Keep old validate handler for backward compatibility
  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_project", %{"project" => project_params}, socket) do
    user = socket.assigns.current_scope.user

    # Check for running project again (defensive)
    if KeywordCannibalizationProjects.has_running_project?(user.id) do
      {:noreply,
       socket
       |> put_flash(:error, "Bạn đã có một dự án đang chạy. Vui lòng đợi hoàn thành.")}
    else
      # Parse keywords from textarea or file
      keywords = parse_keywords_from_form(socket)

      if length(keywords) == 0 do
        {:noreply,
         socket
         |> put_flash(:error, "Vui lòng nhập ít nhất một từ khóa")}
      else
        # Prepare project attributes
        attrs = %{
          name: project_params["name"],
          domain: project_params["domain"],
          keywords: keywords,
          result_limit: String.to_integer(project_params["result_limit"] || "20"),
          user_id: user.id,
          status: "pending"
        }

        # Create project in DB
        case KeywordCannibalizationProjects.create_project(attrs) do
          {:ok, project} ->
            # Enqueue Oban job
            %{project_id: project.id}
            |> Levanngoc.Jobs.KeywordCannibalizationWorker.new()
            |> Oban.insert()

            # Subscribe to PubSub for this project
            Phoenix.PubSub.subscribe(
              Levanngoc.PubSub,
              "cannibalization_project:#{project.id}"
            )

            # Reload projects list
            projects = KeywordCannibalizationProjects.list_projects(user.id)

            {:noreply,
             socket
             |> assign(:show_modal, false)
             |> assign(:modal_action, nil)
             |> assign(:modal_project, nil)
             |> assign(:form, nil)
             |> assign(:projects, projects)
             |> assign(:running_project_id, project.id)
             |> assign(:progress_message, "Đang khởi động...")
             |> put_flash(:info, "Dự án đã được tạo và đang xử lý...")}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset, as: "project"))}
        end
      end
    end
  end

  # Project Management Event Handlers

  @impl true
  def handle_event("view_project_results", %{"project_id" => project_id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    project = KeywordCannibalizationProjects.get_project!(project_id, user_id)

    if project.status == "completed" && project.cannibalization_results do
      # Convert string keys to atom keys for template compatibility
      atomized_results = Enum.map(project.cannibalization_results, &atomize_result/1)

      {:noreply,
       socket
       |> assign(:selected_project, project)
       |> assign(:cannibalization_results, atomized_results)
       |> assign(:show_result_modal, true)
       |> assign(:selected_keyword_index, 0)
       |> assign(:domain_input, project.domain)}
    else
      {:noreply, put_flash(socket, :error, "Dự án chưa hoàn thành hoặc không có kết quả")}
    end
  end

  @impl true
  def handle_event("delete_project", %{"project_id" => project_id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    project = KeywordCannibalizationProjects.get_project!(project_id, user_id)

    # Don't allow deleting running projects
    if project.status == "running" do
      {:noreply, put_flash(socket, :error, "Không thể xóa dự án đang chạy")}
    else
      {:ok, _} = KeywordCannibalizationProjects.delete_project(project)
      projects = KeywordCannibalizationProjects.list_projects(user_id)

      {:noreply,
       socket
       |> assign(:projects, projects)
       |> put_flash(:info, "Đã xóa dự án")}
    end
  end

  @impl true
  def handle_event("rerun_project", %{"project_id" => project_id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Check if user already has a running project
    if KeywordCannibalizationProjects.has_running_project?(user_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Bạn đã có một dự án đang chạy. Vui lòng đợi hoàn thành.")}
    else
      project = KeywordCannibalizationProjects.get_project!(project_id, user_id)

      # Reset project to pending
      {:ok, project} = KeywordCannibalizationProjects.reset_to_pending(project)

      # Enqueue job
      %{project_id: project.id}
      |> Levanngoc.Jobs.KeywordCannibalizationWorker.new()
      |> Oban.insert()

      # Subscribe to PubSub
      Phoenix.PubSub.subscribe(
        Levanngoc.PubSub,
        "cannibalization_project:#{project.id}"
      )

      # Reload projects
      projects = KeywordCannibalizationProjects.list_projects(user_id)

      {:noreply,
       socket
       |> assign(:projects, projects)
       |> assign(:running_project_id, project.id)
       |> assign(:progress_message, "Đang khởi động...")
       |> put_flash(:info, "Đang chạy lại dự án...")}
    end
  end

  # File Upload and Keyword Management

  @impl true
  def handle_event("switch_to_edit_mode", _params, socket) do
    {:noreply, assign(socket, :is_edit_mode, true)}
  end

  @impl true
  def handle_event("switch_to_file_mode", _params, socket) do
    {:noreply, assign(socket, :is_edit_mode, false)}
  end

  @impl true
  def handle_event("update_manual_keywords", %{"keywords" => keywords}, socket) do
    {:noreply, assign(socket, :manual_keywords, keywords)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  # Results Modal Management

  @impl true
  def handle_event("close_result_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_keyword", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, :selected_keyword_index, index)}
  end

  # Export Event Handlers

  @impl true
  def handle_event("export_to_xlsx", _params, socket) do
    results = socket.assigns.cannibalization_results
    domain = socket.assigns.domain_input

    # Generate XLSX file
    filename =
      "keyword_cannibalization_#{sanitize_filename(domain)}_#{System.system_time(:second)}.xlsx"

    file_path = Path.join(System.tmp_dir!(), filename)

    case generate_xlsx(results, file_path) do
      :ok ->
        # Read file and send to client
        file_content = File.read!(file_path)
        File.rm(file_path)

        {:noreply,
         socket
         |> push_event("download-file", %{
           filename: filename,
           content: Base.encode64(file_content)
         })}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] XLSX_EXPORT_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Error: #{inspect(reason)}"
        )

        {:noreply, put_flash(socket, :error, "Không thể tạo file Excel")}
    end
  end

  @impl true
  def handle_event("export_to_google_sheet", _params, socket) do
    results = socket.assigns.cannibalization_results
    domain = socket.assigns.domain_input

    case export_to_google_sheets(results, domain) do
      {:ok, sheet_url} ->
        {:noreply,
         socket
         |> put_flash(:info, "Đã tạo Google Sheet thành công!")
         |> push_event("open-url", %{url: sheet_url})}

      {:error, reason} ->
        Logger.error(
          "[KEYWORD_CANNIBALIZATION] GOOGLE_SHEETS_ERROR - User: #{socket.assigns.user_email}, Session: #{socket.assigns.session_id}, Error: #{inspect(reason)}"
        )

        {:noreply, put_flash(socket, :error, "Không thể tạo Google Sheet: #{inspect(reason)}")}
    end
  end

  # PubSub Message Handler

  @impl true
  def handle_info(
        {:project_status, %{project_id: project_id, status: status, message: message}},
        socket
      ) do
    user_id = socket.assigns.current_scope.user.id

    case status do
      "completed" ->
        # Reload projects list to get updated status
        projects = KeywordCannibalizationProjects.list_projects(user_id)

        # Unsubscribe from this project
        Phoenix.PubSub.unsubscribe(
          Levanngoc.PubSub,
          "cannibalization_project:#{project_id}"
        )

        # Clear progress from cache
        Cachex.del(:cache, {:cannibalization_progress, project_id})

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:running_project_id, nil)
         |> assign(:progress_message, nil)
         |> put_flash(:info, "Dự án đã hoàn thành!")}

      "failed" ->
        # Reload projects list to get updated status
        projects = KeywordCannibalizationProjects.list_projects(user_id)

        # Unsubscribe
        Phoenix.PubSub.unsubscribe(
          Levanngoc.PubSub,
          "cannibalization_project:#{project_id}"
        )

        # Clear progress from cache
        Cachex.del(:cache, {:cannibalization_progress, project_id})

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:running_project_id, nil)
         |> assign(:progress_message, nil)
         |> put_flash(:error, "Dự án thất bại: #{message}")}

      "running" ->
        # Optimize: Don't reload projects list for progress updates
        # Just update the progress message
        {:noreply, assign(socket, :progress_message, message)}

      _ ->
        {:noreply, socket}
    end
  end

  # Helper Functions

  # Parse keywords from textarea or uploaded file
  defp parse_keywords_from_form(socket) do
    if socket.assigns.is_edit_mode do
      # Parse from textarea
      socket.assigns.manual_keywords
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    else
      # Parse from uploaded file
      uploaded_files =
        consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
          parse_keywords_file(path, entry.client_type)
        end)

      uploaded_files
      |> List.flatten()
      |> Enum.uniq()
    end
  end

  # Parse keywords from uploaded file
  defp parse_keywords_file(path, "text/csv") do
    path
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
    |> Enum.to_list()
    |> case do
      [] ->
        []

      [_header | rows] ->
        rows
        |> Enum.map(fn row ->
          keyword = Enum.at(row, 0)
          if keyword, do: String.trim(keyword) |> String.downcase(), else: nil
        end)
        |> Enum.reject(&(&1 == nil or &1 == ""))
    end
  end

  defp parse_keywords_file(path, "text/plain") do
    # .txt file - one keyword per line
    File.read!(path)
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_keywords_file(path, _type) do
    # Assume XLSX
    case Xlsxir.multi_extract(path, 0) do
      {:ok, table_id} ->
        data =
          Xlsxir.get_list(table_id)
          |> case do
            [] ->
              []

            [_header | rows] ->
              rows
              |> Enum.map(fn row ->
                keyword = Enum.at(row, 0)

                if keyword,
                  do: to_string(keyword) |> String.trim() |> String.downcase(),
                  else: nil
              end)
              |> Enum.reject(&(&1 == nil or &1 == ""))
          end

        Xlsxir.close(table_id)
        data

      _ ->
        []
    end
  end

  # Helper function to get badge class based on score
  defp get_score_badge_class(score) when score <= 2, do: "badge-success"
  defp get_score_badge_class(score) when score <= 4, do: "badge-warning"
  defp get_score_badge_class(score) when score <= 6, do: "badge-error"
  defp get_score_badge_class(_score), do: "badge-error font-bold"

  # Map score to text color class for inline number display
  defp get_score_text_class(score) when score <= 2, do: "text-success"
  defp get_score_text_class(score) when score <= 4, do: "text-warning"
  defp get_score_text_class(score) when score <= 6, do: "text-error"
  defp get_score_text_class(_score), do: "text-error font-bold"

  # Sanitize filename for safe file system operations
  defp sanitize_filename(domain) do
    domain
    |> String.replace(~r/[^a-zA-Z0-9-_]/, "_")
    |> String.slice(0..50)
  end

  # Helper function for date formatting with Asia/Ho_Chi_Minh timezone
  defp format_date(nil), do: ""

  defp format_date(datetime) do
    case datetime do
      %DateTime{} ->
        # Convert to Asia/Ho_Chi_Minh timezone
        local_datetime = DateTime.shift_zone!(datetime, "Asia/Ho_Chi_Minh")

        "#{local_datetime.year}-#{pad_zero(local_datetime.month)}-#{pad_zero(local_datetime.day)} #{pad_zero(local_datetime.hour)}:#{pad_zero(local_datetime.minute)}"

      %NaiveDateTime{} ->
        # Assume UTC and convert to Asia/Ho_Chi_Minh timezone
        datetime
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.shift_zone!("Asia/Ho_Chi_Minh")
        |> then(fn dt ->
          "#{dt.year}-#{pad_zero(dt.month)}-#{pad_zero(dt.day)} #{pad_zero(dt.hour)}:#{pad_zero(dt.minute)}"
        end)

      _ ->
        ""
    end
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: "#{num}"

  # Convert string keys from database JSON to atom keys for template
  defp atomize_result(result) when is_map(result) do
    %{
      keyword: result["keyword"],
      score: result["score"],
      urls: result["urls"] || [],
      status:
        case result["status"] do
          "no_results" -> :no_results
          "safe" -> :safe
          "error" -> :error
          "cannibalization" -> :cannibalization
          _ -> :needs_review
        end,
      details: %{
        base_score: result["details"]["base_score"],
        title_h1_similarity: result["details"]["title_h1_similarity"],
        same_page_type: result["details"]["same_page_type"],
        anchor_text_conflicts: result["details"]["anchor_text_conflicts"]
      },
      visualization: %{
        percentage: result["visualization"]["percentage"],
        circumference: result["visualization"]["circumference"],
        stroke_dashoffset: result["visualization"]["stroke_dashoffset"]
      }
    }
    |> maybe_add_error_message(result)
  end

  defp maybe_add_error_message(atomized_result, result) do
    if result["error_message"] do
      Map.put(atomized_result, :error_message, result["error_message"])
    else
      atomized_result
    end
  end

  # Generate XLSX file from cannibalization results
  defp generate_xlsx(results, file_path) do
    try do
      # Create header row
      header = ["Từ khóa", "Điểm", "URLs"]

      # Create data rows
      data_rows =
        Enum.map(results, fn result ->
          # Join URLs with newline character for Excel
          urls_text = Enum.join(result.urls, "\n")

          [result.keyword, result.score, urls_text]
        end)

      # Combine header and data
      all_rows = [header | data_rows]

      # Create workbook
      workbook = %Elixlsx.Workbook{
        sheets: [
          %Elixlsx.Sheet{
            name: "Results",
            rows: all_rows
          }
        ]
      }

      # Write to file
      Elixlsx.write_to(workbook, file_path)

      :ok
    rescue
      e ->
        {:error, e}
    end
  end

  # Export to Google Sheets
  defp export_to_google_sheets(results, domain) do
    try do
      # Get folder ID from cache
      case Cachex.get(:cache, :reports_folder_id) do
        {:ok, folder_id} when is_binary(folder_id) ->
          # Get connection
          conn = GoogleDrive.get_conn()

          # Prepare spreadsheet name
          spreadsheet_name =
            "Keyword Cannibalization - #{domain} - #{DateTime.utc_now() |> DateTime.to_date()}"

          # Prepare data rows
          header = ["Từ khóa", "Điểm", "URLs"]

          data_rows =
            Enum.map(results, fn result ->
              # Join URLs with newline for display in single cell
              urls_text = Enum.join(result.urls, "\n")
              [result.keyword, result.score, urls_text]
            end)

          all_rows = [header | data_rows]

          # Export to spreadsheet
          case GoogleDrive.export_to_spreadsheet(conn, folder_id, spreadsheet_name, all_rows) do
            {:ok, %{spreadsheet_id: spreadsheet_id}} ->
              spreadsheet_url = "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit"
              {:ok, spreadsheet_url}

            {:error, reason} ->
              {:error, reason}
          end

        {:ok, nil} ->
          {:error, "Reports folder ID not configured in cache"}

        {:error, reason} ->
          {:error, "Failed to get reports folder ID: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, inspect(e)}
    end
  end
end
