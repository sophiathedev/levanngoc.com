defmodule LevanngocWeb.SeoImageLive.ImageCompression do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Nén Hình ảnh")
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg),
       max_entries: 10,
       max_file_size: 10_000_000,
       auto_upload: true
     )
     |> assign(:compression_mode, "standard")
     |> assign(:quality, 90)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    updated_socket =
      Enum.reduce(params, socket, fn {key, value}, acc ->
        case key do
          "compression_mode" -> assign(acc, :compression_mode, value)
          "quality" -> assign(acc, :quality, String.to_integer(value))
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
  def handle_event("compress_images", _params, socket) do
    IO.puts("Starting compression...")
    compression_mode = socket.assigns.compression_mode
    quality = socket.assigns.quality

    uploaded_files =
      consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir!(), "#{entry.uuid}-#{entry.client_name}")
        File.cp!(path, dest)
        {:ok, {dest, entry.client_name}}
      end)

    IO.inspect(uploaded_files, label: "Uploaded Files")

    if uploaded_files == [] do
      {:noreply, put_flash(socket, :error, "Vui lòng tải lên ít nhất một ảnh.")}
    else
      try do
        processed_files =
          Enum.map(uploaded_files, fn {file_path, client_name} ->
            path = process_image(file_path, compression_mode, quality)
            {path, client_name}
          end)

        zip_filename = "compressed_images_#{System.os_time(:second)}.zip"
        zip_path = Path.join(System.tmp_dir!(), zip_filename)

        files_to_zip =
          Enum.map(processed_files, fn {file, client_name} ->
            {String.to_charlist(client_name), File.read!(file)}
          end)

        {:ok, _zip_file} = :zip.create(String.to_charlist(zip_path), files_to_zip)

        # Cleanup processed files
        Enum.each(processed_files, fn {path, _} -> File.rm(path) end)

        zip_content = File.read!(zip_path)
        File.rm(zip_path)

        IO.puts("Compression successful, pushing download event...")

        {:noreply,
         socket
         |> put_flash(:info, "Đã nén #{length(processed_files)} ảnh thành công!")
         |> push_event("download-file", %{
           content: Base.encode64(zip_content),
           filename: zip_filename
         })}
      rescue
        e ->
          IO.inspect(e, label: "Compression Error")
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
     |> assign(:compression_mode, "standard")
     |> assign(:quality, 90)}
  end

  defp process_image(file_path, mode, quality) do
    image = Mogrify.open(file_path)

    image =
      case mode do
        "standard" ->
          image
          |> Mogrify.quality(to_string(quality))
          |> Mogrify.save(in_place: true)

        "remove_exif" ->
          image
          |> Mogrify.custom("strip")
          |> Mogrify.save(in_place: true)

        _ ->
          image
      end

    image.path
  end

  defp error_to_string(:too_large), do: "File quá lớn"
  defp error_to_string(:too_many_files), do: "Quá nhiều file"
  defp error_to_string(:not_accepted), do: "Định dạng không hỗ trợ"
  defp error_to_string(_), do: "Lỗi không xác định"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full p-4 flex flex-col">
      <h1 class="text-2xl font-bold mb-6">Nén ảnh</h1>

      <form phx-change="validate" onsubmit="return false;" class="flex-1 flex flex-col gap-6">
        <!-- Options and Quality Section -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Left: Compression Options -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body p-6">
              <h2 class="card-title text-base mb-4">Tùy chọn nén ảnh</h2>
              <div class="space-y-3">
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="radio"
                      name="compression_mode"
                      value="standard"
                      class="radio radio-primary radio-sm"
                      checked={@compression_mode == "standard"}
                    />
                    <span class="label-text">Nén ảnh tiêu chuẩn</span>
                  </label>
                </div>
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="radio"
                      name="compression_mode"
                      value="remove_exif"
                      class="radio radio-primary radio-sm"
                      checked={@compression_mode == "remove_exif"}
                    />
                    <span class="label-text">Xóa toàn bộ geotag và exif ảnh*</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
          <!-- Right: Quality Slider -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body p-6">
              <h2 class="card-title text-base mb-4">Chất lượng ảnh</h2>
              <div class="flex items-center gap-4">
                <span class="text-sm text-base-content/60 w-12">{@quality}%</span>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={@quality}
                  name="quality"
                  class="range range-primary flex-1"
                />
              </div>
            </div>
          </div>
        </div>
        <!-- Upload Section and File List -->
        <div class="flex flex-col gap-2">
          <div
            class="relative w-full flex-1 p-10 flex flex-col items-center justify-center gap-2 border-2 border-dashed border-base-300 rounded-lg hover:bg-base-200/20 transition-colors"
            phx-drop-target={@uploads.images.ref}
          >
            <div class="bg-primary/10 text-primary px-4 py-2 rounded-lg font-medium text-sm mb-2">
              Tải lên
            </div>
            <p class="text-sm text-base-content/60">Tối đa dung lượng ảnh là 10MB</p>
            <p class="text-sm text-base-content/60">
              Hoặc kéo & thả file vào đây (Định dạng file: .JPG; .JPEG)
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
        </div>
        <!-- Submit Button -->
        <div class="flex justify-end">
          <button
            type="button"
            phx-click="compress_images"
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
