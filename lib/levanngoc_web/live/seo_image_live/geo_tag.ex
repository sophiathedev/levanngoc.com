defmodule LevanngocWeb.SeoImageLive.GeoTag do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Geo Tag Hình ảnh")
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .svg .gif),
       max_entries: 10,
       auto_upload: true
     )
     |> assign(:uploaded_image, nil)
     |> assign(:latitude, "")
     |> assign(:longitude, "")
     |> assign(:title, "")
     |> assign(:subject, "")
     |> assign(:keywords, "")
     |> assign(:secondary_keywords, "")
     |> assign(:comments, "")
     |> assign(:author, "")
     |> assign(:copyright, "")
     |> assign(:date_taken, Date.to_string(Date.utc_today()))
     |> assign(:camera_manufacturer, "")
     |> assign(:camera_model, "")
     |> assign(:application_name, "")
     |> assign(:delete_old_exif, true)
     |> assign(:use_title_as_filename, false)
     |> assign(:use_filename_as_name, true)
     |> assign(:export_unsigned, true)
     |> assign(:replace_spaces, true)
     |> assign(:append_author_comment, true)
     |> assign(:append_author_filename, true)
     |> assign(:rate_5_stars, true)
     |> assign(:compress_after_geotag, true)
     |> assign(:image_quality, 90)
     |> assign(:has_non_jpeg, false)
     |> LevanngocWeb.TrackToolVisit.track_visit("/geo-tag")}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # Check for non-JPEG files
    entries = socket.assigns.uploads.images.entries

    has_non_jpeg =
      Enum.any?(entries, fn entry ->
        ext = Path.extname(entry.client_name) |> String.downcase()
        ext not in [".jpg", ".jpeg"]
      end)

    socket = assign(socket, :has_non_jpeg, has_non_jpeg)

    # Update assigns based on form params
    updated_socket =
      Enum.reduce(params, socket, fn {key, value}, acc ->
        case key do
          "latitude" -> assign(acc, :latitude, value)
          "longitude" -> assign(acc, :longitude, value)
          "title" -> assign(acc, :title, value)
          "subject" -> assign(acc, :subject, value)
          "keywords" -> assign(acc, :keywords, value)
          "secondary_keywords" -> assign(acc, :secondary_keywords, value)
          "comments" -> assign(acc, :comments, value)
          "author" -> assign(acc, :author, value)
          "copyright" -> assign(acc, :copyright, value)
          "date_taken" -> assign(acc, :date_taken, value)
          "camera_manufacturer" -> assign(acc, :camera_manufacturer, value)
          "camera_model" -> assign(acc, :camera_model, value)
          "application_name" -> assign(acc, :application_name, value)
          "delete_old_exif" -> assign(acc, :delete_old_exif, value == "true")
          "use_title_as_filename" -> assign(acc, :use_title_as_filename, value == "true")
          "use_filename_as_name" -> assign(acc, :use_filename_as_name, value == "true")
          "export_unsigned" -> assign(acc, :export_unsigned, value == "true")
          "replace_spaces" -> assign(acc, :replace_spaces, value == "true")
          "append_author_comment" -> assign(acc, :append_author_comment, value == "true")
          "append_author_filename" -> assign(acc, :append_author_filename, value == "true")
          "rate_5_stars" -> assign(acc, :rate_5_stars, value == "true")
          "compress_after_geotag" -> assign(acc, :compress_after_geotag, value == "true")
          "image_quality" -> assign(acc, :image_quality, String.to_integer(value))
          _ -> acc
        end
      end)

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  @impl true
  def handle_event("add_geo_tag", _params, socket) do
    # If has_non_jpeg is true, clear the restricted fields
    {title, subject, keywords, secondary_keywords, comments} =
      if socket.assigns.has_non_jpeg do
        {"", "", "", "", ""}
      else
        {socket.assigns.title, socket.assigns.subject, socket.assigns.keywords,
         socket.assigns.secondary_keywords, socket.assigns.comments}
      end

    params = %{
      latitude: socket.assigns.latitude,
      longitude: socket.assigns.longitude,
      title: title,
      subject: subject,
      keywords: keywords,
      secondary_keywords: secondary_keywords,
      comments: comments,
      author: socket.assigns.author,
      copyright: socket.assigns.copyright,
      date_taken: socket.assigns.date_taken,
      camera_manufacturer: socket.assigns.camera_manufacturer,
      camera_model: socket.assigns.camera_model,
      application_name: socket.assigns.application_name,
      delete_old_exif: socket.assigns.delete_old_exif,
      use_title_as_filename: socket.assigns.use_title_as_filename,
      use_filename_as_name: socket.assigns.use_filename_as_name,
      export_unsigned: socket.assigns.export_unsigned,
      replace_spaces: socket.assigns.replace_spaces,
      append_author_comment: socket.assigns.append_author_comment,
      append_author_filename: socket.assigns.append_author_filename,
      rate_5_stars: socket.assigns.rate_5_stars,
      compress_after_geotag: socket.assigns.compress_after_geotag,
      image_quality: socket.assigns.image_quality
    }

    uploaded_files =
      consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir!(), "#{entry.uuid}-#{entry.client_name}")
        File.cp!(path, dest)
        {:ok, {dest, entry.client_name}}
      end)

    if uploaded_files == [] do
      {:noreply, put_flash(socket, :error, "Vui lòng tải lên ít nhất một ảnh.")}
    else
      try do
        processed_files =
          Enum.map(uploaded_files, fn {file_path, client_name} ->
            # Determine new filename
            new_filename = determine_filename(client_name, params)

            # Process image
            path = process_geotag(file_path, params, client_name)
            {path, new_filename}
          end)

        zip_filename = "geotagged_images_#{System.os_time(:second)}.zip"
        zip_path = Path.join(System.tmp_dir!(), zip_filename)

        files_to_zip =
          Enum.map(processed_files, fn {file, filename} ->
            {String.to_charlist(filename), File.read!(file)}
          end)

        {:ok, _zip_file} = :zip.create(String.to_charlist(zip_path), files_to_zip)

        # Cleanup processed files
        Enum.each(processed_files, fn {path, _} -> File.rm(path) end)

        zip_content = File.read!(zip_path)
        File.rm(zip_path)

        {:noreply,
         socket
         |> put_flash(:info, "Đã xử lý #{length(processed_files)} ảnh thành công!")
         |> push_event("download-file", %{
           content: Base.encode64(zip_content),
           filename: zip_filename
         })}
      rescue
        e ->
          # Cleanup uploaded files if processing fails
          Enum.each(uploaded_files, fn {path, _} -> File.rm(path) end)

          error_msg =
            case e do
              %ErlangError{original: :enoent} ->
                "Lỗi: Không tìm thấy ImageMagick. Thư viện Elixir Mogrify cần ImageMagick được cài đặt trên hệ thống (brew install imagemagick)."

              _ ->
                "Đã xảy ra lỗi khi xử lý ảnh: #{inspect(e)}"
            end

          {:noreply, put_flash(socket, :error, error_msg)}
      end
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:uploaded_image, nil)
     |> assign(:has_non_jpeg, false)
     |> assign(:latitude, "")
     |> assign(:longitude, "")
     |> assign(:title, "")
     |> assign(:subject, "")
     |> assign(:keywords, "")
     |> assign(:secondary_keywords, "")
     |> assign(:comments, "")
     |> assign(:author, "")
     |> assign(:copyright, "")
     |> assign(:date_taken, Date.to_string(Date.utc_today()))
     |> assign(:camera_manufacturer, "")
     |> assign(:camera_model, "")
     |> assign(:application_name, "")}
  end

  defp determine_filename(original_filename, params) do
    ext = Path.extname(original_filename)
    basename = Path.basename(original_filename, ext)

    # 1. Base name selection
    name =
      if params.use_title_as_filename and params.title != "" do
        params.title
      else
        basename
      end

    # 2. Append author
    name =
      if params.append_author_filename and params.author != "" do
        "#{name}-#{params.author}"
      else
        name
      end

    # 3. Replace spaces
    name =
      if params.replace_spaces do
        String.replace(name, " ", "-")
      else
        name
      end

    # 4. Export unsigned (remove accents)
    name =
      if params.export_unsigned do
        remove_accents(name)
      else
        name
      end

    "#{name}#{ext}"
  end

  defp remove_accents(string) do
    # Simple replacement map for common Vietnamese characters
    string
    |> String.replace(~r/[áàảãạăắằẳẵặâấầẩẫậ]/, "a")
    |> String.replace(~r/[ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ]/, "A")
    |> String.replace(~r/[éèẻẽẹêếềểễệ]/, "e")
    |> String.replace(~r/[ÉÈẺẼẸÊẾỀỂỄỆ]/, "E")
    |> String.replace(~r/[íìỉĩị]/, "i")
    |> String.replace(~r/[ÍÌỈĨỊ]/, "I")
    |> String.replace(~r/[óòỏõọôốồổỗộơớờởỡợ]/, "o")
    |> String.replace(~r/[ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ]/, "O")
    |> String.replace(~r/[úùủũụưứừửữự]/, "u")
    |> String.replace(~r/[ÚÙỦŨỤƯỨỪỬỮỰ]/, "U")
    |> String.replace(~r/[ýỳỷỹỵ]/, "y")
    |> String.replace(~r/[ÝỲỶỸỴ]/, "Y")
    |> String.replace(~r/[đ]/, "d")
    |> String.replace(~r/[Đ]/, "D")
  end

  defp process_geotag(file_path, params, original_filename) do
    # 1. Delete old EXIF explicitly first if requested
    if params.delete_old_exif do
      System.cmd("mogrify", ["-strip", file_path], stderr_to_stdout: true)
    end

    # 2. Prepare metadata values
    title =
      if params.use_filename_as_name and params.title == "",
        do: Path.basename(original_filename, Path.extname(original_filename)),
        else: params.title

    comments =
      if params.append_author_comment and params.author != "",
        do: "#{params.comments} - Author: #{params.author}",
        else: params.comments

    full_keywords =
      [params.keywords, params.secondary_keywords]
      |> Enum.filter(&(&1 != ""))
      |> Enum.join(", ")

    # 3. Set metadata using exiftool (preferred) or mogrify (fallback)
    set_metadata_with_exiftool(file_path, %{
      title: title,
      subject: params.subject,
      keywords: full_keywords,
      comments: comments,
      author: params.author,
      copyright: params.copyright,
      date_taken: params.date_taken,
      camera_manufacturer: params.camera_manufacturer,
      camera_model: params.camera_model,
      application_name: params.application_name,
      rate_5_stars: params.rate_5_stars
    })

    # 4. Compression (use mogrify)
    if params.compress_after_geotag do
      System.cmd("mogrify", ["-quality", to_string(params.image_quality), file_path],
        stderr_to_stdout: true
      )
    end

    # 5. Set GPS with exiftool (if available and coordinates provided)
    if params.latitude != "" and params.longitude != "" do
      set_gps_with_exiftool(file_path, params.latitude, params.longitude)
    end

    file_path
  end

  defp set_metadata_with_exiftool(file_path, metadata) do
    case System.find_executable("exiftool") do
      nil ->
        # Fallback to mogrify if exiftool not available
        IO.puts(
          "Exiftool not found. Falling back to mogrify for metadata (may not set all tags correctly)."
        )

        set_metadata_with_mogrify(file_path, metadata)

      executable ->
        # Build exiftool args for all metadata
        args = [
          "-overwrite_original",
          "-Title=#{metadata.title}",
          "-Subject=#{metadata.subject}",
          "-Keywords=#{metadata.keywords}",
          "-Comment=#{metadata.comments}",
          "-Artist=#{metadata.author}",
          "-Copyright=#{metadata.copyright}",
          "-Make=#{metadata.camera_manufacturer}",
          "-Model=#{metadata.camera_model}",
          "-Software=#{metadata.application_name}",
          "-XPTitle=#{metadata.title}",
          "-XPSubject=#{metadata.subject}",
          "-XPKeywords=#{metadata.keywords}",
          "-XPComment=#{metadata.comments}"
        ]

        # Add Date Taken if provided
        args =
          if metadata.date_taken != "" do
            formatted_date = String.replace(metadata.date_taken, "-", ":") <> " 00:00:00"
            args ++ ["-DateTimeOriginal=#{formatted_date}"]
          else
            args
          end

        # Add Rating
        args = if metadata.rate_5_stars, do: args ++ ["-Rating=5"], else: args

        # Execute exiftool
        System.cmd(executable, args ++ [file_path], stderr_to_stdout: true)
    end
  end

  defp set_metadata_with_mogrify(file_path, metadata) do
    # Fallback: Use mogrify (less reliable for some tags)
    args = []

    add_meta = fn args, key, val ->
      if val != "", do: args ++ ["-set", key, val], else: args
    end

    args =
      args
      |> add_meta.("exif:ImageDescription", metadata.title)
      |> add_meta.("exif:Artist", metadata.author)
      |> add_meta.("exif:Copyright", metadata.copyright)
      |> add_meta.("comment", metadata.comments)
      |> add_meta.("iptc:Keywords", metadata.keywords)
      |> add_meta.("exif:UserComment", metadata.comments)
      |> add_meta.("exif:XPTitle", metadata.title)
      |> add_meta.("exif:XPComment", metadata.comments)
      |> add_meta.("exif:XPKeywords", metadata.keywords)
      |> add_meta.("exif:XPSubject", metadata.subject)
      |> add_meta.("exif:Make", metadata.camera_manufacturer)
      |> add_meta.("exif:Model", metadata.camera_model)
      |> add_meta.("exif:Software", metadata.application_name)

    # Date Taken
    args =
      if metadata.date_taken != "" do
        formatted_date = String.replace(metadata.date_taken, "-", ":") <> " 00:00:00"
        args ++ ["-set", "exif:DateTimeOriginal", formatted_date]
      else
        args
      end

    # Rating
    args = if metadata.rate_5_stars, do: args ++ ["-set", "xmp:Rating", "5"], else: args

    if args != [] do
      System.cmd("mogrify", args ++ [file_path], stderr_to_stdout: true)
    end
  end

  defp set_gps_with_exiftool(file_path, lat, long) do
    case System.find_executable("exiftool") do
      nil ->
        IO.puts("Exiftool not found. Skipping GPS tagging.")

      executable ->
        args = [
          "-GPSLatitude=#{lat}",
          "-GPSLatitudeRef=#{lat}",
          "-GPSLongitude=#{long}",
          "-GPSLongitudeRef=#{long}",
          "-overwrite_original",
          file_path
        ]

        System.cmd(executable, args, stderr_to_stdout: true)
    end
  end

  defp error_to_string(:too_large), do: "File quá lớn"
  defp error_to_string(:too_many_files), do: "Quá nhiều file"
  defp error_to_string(:not_accepted), do: "Định dạng không hỗ trợ"
  defp error_to_string(_), do: "Lỗi không xác định"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full p-4">
      <h1 class="text-2xl font-bold mb-6">GeoTag hình ảnh</h1>

      <form phx-change="validate" phx-submit="add_geo_tag" class="space-y-6">
        <!-- Upload Section -->
        <div
          class="relative w-full p-10 flex flex-col items-center justify-center gap-2 border-2 border-dashed border-base-300 rounded-lg hover:bg-base-200/20 transition-colors"
          phx-drop-target={@uploads.images.ref}
        >
          <div class="bg-primary/10 text-primary px-4 py-2 rounded-lg font-medium text-sm mb-2">
            Tải lên
          </div>
          <p class="text-sm text-base-content/60">Tối đa dung lượng ảnh là 10MB</p>
          <p class="text-sm text-base-content/60">
            Hoặc kéo & thả file vào đây (Định dạng file: .JPG; .JPEG; .PNG; .SVG; .GIF)
          </p>
          <.live_file_input
            upload={@uploads.images}
            class="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          />
        </div>
        
    <!-- File List -->
        <%= if @uploads.images.entries != [] do %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-2">
            <%= for entry <- @uploads.images.entries do %>
              <div class="flex items-center justify-between p-3 bg-base-100 border border-base-200 rounded-lg">
                <div class="flex items-center gap-3 overflow-hidden">
                  <div class="w-10 h-10 rounded-lg bg-base-200 flex-shrink-0 flex items-center justify-center text-base-content/50">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                      />
                    </svg>
                  </div>
                  <div class="min-w-0">
                    <p class="font-medium text-sm truncate" title={entry.client_name}>
                      {entry.client_name}
                    </p>
                    <p class="text-xs text-base-content/60">
                      {Float.round(entry.client_size / 1024 / 1024, 2)} MB
                      <%= if entry.progress < 100 do %>
                        <span class="text-primary ml-1">({entry.progress}%)</span>
                      <% end %>
                    </p>
                    <%= for err <- upload_errors(@uploads.images, entry) do %>
                      <p class="text-xs text-error">{error_to_string(err)}</p>
                    <% end %>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-sm btn-circle text-error flex-shrink-0"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Location Info -->
        <div class="card bg-base-100 shadow-sm border border-base-200">
          <div class="card-body p-6">
            <h2 class="card-title text-base mb-4">Thông tin chi tiết ảnh</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Latitude (vĩ độ)</span>
                </label>
                <input
                  type="text"
                  name="latitude"
                  value={@latitude}
                  placeholder="Nhập vĩ độ"
                  class="input input-bordered w-full"
                />
              </div>
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Longitude (kinh độ)</span>
                </label>
                <input
                  type="text"
                  name="longitude"
                  value={@longitude}
                  placeholder="Nhập kinh độ"
                  class="input input-bordered w-full"
                />
              </div>
            </div>
          </div>
        </div>
        
    <!-- Metadata Info -->
        <%= if @has_non_jpeg do %>
          <div role="alert" class="alert alert-warning shadow-sm">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="stroke-current shrink-0 h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
            <span>
              Một số file không phải định dạng JPG/JPEG. Các trường Title, Subject, Keywords và Comments sẽ bị vô hiệu hóa.
            </span>
          </div>
        <% end %>
        <div class="card bg-base-100 shadow-sm border border-base-200">
          <div class="card-body p-6">
            <h2 class="card-title text-base mb-4">Thông tin chi tiết ảnh</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Title -->
              <div class="form-control w-full">
                <label class="label pt-0"><span class="label-text font-medium">Title</span></label>
                <input
                  type="text"
                  name="title"
                  value={@title}
                  disabled={@has_non_jpeg}
                  class={"input input-bordered w-full bg-base-200/30 #{if @has_non_jpeg, do: "opacity-50 cursor-not-allowed"}"}
                />
              </div>
              <!-- Subject -->
              <div class="form-control w-full">
                <label class="label pt-0"><span class="label-text font-medium">Subject</span></label>
                <input
                  type="text"
                  name="subject"
                  value={@subject}
                  disabled={@has_non_jpeg}
                  class={"input input-bordered w-full bg-base-200/30 #{if @has_non_jpeg, do: "opacity-50 cursor-not-allowed"}"}
                />
              </div>
              <!-- Keywords -->
              <div class="form-control w-full">
                <label class="label pt-0"><span class="label-text font-medium">Keywords</span></label>
                <input
                  type="text"
                  name="keywords"
                  value={@keywords}
                  disabled={@has_non_jpeg}
                  placeholder="..."
                  class={"input input-bordered w-full bg-base-200/30 #{if @has_non_jpeg, do: "opacity-50 cursor-not-allowed"}"}
                />
              </div>
              <!-- Secondary Keywords -->
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Keywords phụ</span>
                </label>
                <input
                  type="text"
                  name="secondary_keywords"
                  value={@secondary_keywords}
                  disabled={@has_non_jpeg}
                  placeholder="..."
                  class={"input input-bordered w-full bg-base-200/30 #{if @has_non_jpeg, do: "opacity-50 cursor-not-allowed"}"}
                />
              </div>
              <!-- Comments -->
              <div class="form-control w-full">
                <label class="label pt-0"><span class="label-text font-medium">Comments</span></label>
                <input
                  type="text"
                  name="comments"
                  value={@comments}
                  disabled={@has_non_jpeg}
                  class={"input input-bordered w-full bg-base-200/30 #{if @has_non_jpeg, do: "opacity-50 cursor-not-allowed"}"}
                />
              </div>
              <!-- Author -->
              <div class="form-control w-full">
                <label class="label pt-0"><span class="label-text font-medium">Author</span></label>
                <input
                  type="text"
                  name="author"
                  value={@author}
                  class="input input-bordered w-full bg-base-200/30"
                />
              </div>
              <!-- Copyright -->
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Copy Right</span>
                </label>
                <input
                  type="text"
                  name="copyright"
                  value={@copyright}
                  class="input input-bordered w-full bg-base-200/30"
                />
              </div>
              <!-- Date Taken -->
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Date Taken</span>
                </label>
                <input
                  type="date"
                  name="date_taken"
                  value={@date_taken}
                  class="input input-bordered w-full bg-base-200/30"
                />
              </div>
            </div>
          </div>
        </div>
        
    <!-- Device Info -->
        <div class="card bg-base-100 shadow-sm border border-base-200">
          <div class="card-body p-6">
            <h2 class="card-title text-base mb-4">Thông tin thiết bị chụp ảnh</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Camera Manufacturer:</span>
                </label>
                <input
                  type="text"
                  name="camera_manufacturer"
                  value={@camera_manufacturer}
                  placeholder="Nhập nhà sản xuất"
                  class="input input-bordered w-full"
                />
              </div>
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Camera Model</span>
                </label>
                <input
                  type="text"
                  name="camera_model"
                  value={@camera_model}
                  placeholder="Tên máy"
                  class="input input-bordered w-full"
                />
              </div>
              <div class="form-control w-full">
                <label class="label pt-0">
                  <span class="label-text font-medium">Application Name</span>
                </label>
                <input
                  type="text"
                  name="application_name"
                  value={@application_name}
                  placeholder="Tên ứng dụng"
                  class="input input-bordered w-full"
                />
              </div>
            </div>
          </div>
        </div>
        
    <!-- Advanced Features -->
        <div tabindex="0" class="collapse collapse-arrow bg-base-100 border-base-200 border shadow-sm">
          <input type="checkbox" />
          <div class="collapse-title font-semibold text-base">
            Tính năng nâng cao
          </div>
          <div class="collapse-content">
            <div class="flex flex-col pt-2">
              <%= for {label, name, checked} <- [
                  {"Xóa exif cũ", "delete_old_exif", @delete_old_exif},
                  {"Sử dụng title làm tên ảnh", "use_title_as_filename", @use_title_as_filename},
                  {"Sử dụng tên ảnh để đặt tên", "use_filename_as_name", @use_filename_as_name},
                  {"Xuất file ảnh không dấu", "export_unsigned", @export_unsigned},
                  {"Thay khoảng trống bằng dấu (-)", "replace_spaces", @replace_spaces},
                  {"Nối tên tác giả vào comment", "append_author_comment", @append_author_comment},
                  {"Nối tên tác giả vào tên ảnh", "append_author_filename", @append_author_filename},
                  {"Đánh giá 5 sao", "rate_5_stars", @rate_5_stars}
                ] do %>
                <div class="form-control border-b border-dashed border-base-200 last:border-none">
                  <label class="label cursor-pointer flex justify-between items-center py-3">
                    <span class="label-text text-base">{label}</span>
                    <input type="hidden" name={name} value="false" />
                    <input
                      type="checkbox"
                      name={name}
                      value="true"
                      class="toggle toggle-primary toggle-sm"
                      checked={checked}
                    />
                  </label>
                </div>
              <% end %>

              <div class="mt-6">
                <h3 class="font-bold text-lg mb-4">Nén ảnh</h3>
                <div class="border-t border-dashed border-base-200"></div>

                <div class="form-control border-b border-dashed border-base-200">
                  <label class="label cursor-pointer flex justify-between items-center py-3">
                    <span class="label-text text-base">Nén ảnh sau khi Geotag</span>
                    <input type="hidden" name="compress_after_geotag" value="false" />
                    <input
                      type="checkbox"
                      name="compress_after_geotag"
                      value="true"
                      class="toggle toggle-primary toggle-sm"
                      checked={@compress_after_geotag}
                    />
                  </label>
                </div>

                <div class="form-control py-4">
                  <div class="flex items-center gap-4">
                    <span class="label-text text-base w-32">Chất lượng ảnh</span>
                    <span class="text-base-content/60 w-12">{@image_quality}%</span>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={@image_quality}
                      name="image_quality"
                      class="range range-primary range-xs flex-1"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Buttons -->
        <div class="flex gap-2 justify-end mt-4">
          <button
            type="button"
            phx-click="clear"
            class="btn btn-outline min-w-[150px] bg-white hover:bg-gray-100 hover:text-gray-800 border-base-300"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-5 h-5 mr-1"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"
              />
            </svg>
            Làm mới
          </button>
          <button
            type="submit"
            class="btn btn-primary min-w-[200px] text-white border-none disabled:bg-base-300 disabled:text-base-content/50"
            phx-disable-with="Đang xử lý..."
            disabled={
              @uploads.images.entries == [] or
                Enum.any?(@uploads.images.entries, fn entry -> !entry.done? end)
            }
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-5 h-5 mr-1"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z"
              />
            </svg>
            Bắt đầu thực hiện
          </button>
        </div>
      </form>
    </div>
    """
  end
end
