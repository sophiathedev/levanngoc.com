defmodule LevanngocWeb.FreeToolsLive.DisavowGenerator do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tạo file Disavow")
     |> assign(:input_text, "")
     |> assign(:result_text, "")}
  end

  @impl true
  def handle_event("validate", %{"input_text" => input}, socket) do
    result = process_disavow(input)
    {:noreply, socket |> assign(:input_text, input) |> assign(:result_text, result)}
  end

  @impl true
  def handle_event("save_to_file", _params, socket) do
    content = socket.assigns.result_text

    {:noreply,
     push_event(socket, "download_file", %{content: content, filename: "disavow_file.txt"})}
  end

  @impl true
  def handle_event("copy_to_clipboard", _params, socket) do
    content = socket.assigns.result_text
    {:noreply, push_event(socket, "copy_to_clipboard", %{content: content})}
  end

  defp process_disavow(input) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_disavow_line/1)
    |> Enum.join("\n")
  end

  defp format_disavow_line(line) do
    # Remove protocol if present
    line = String.replace(line, ~r/^https?:\/\//, "")

    # Check if it's a full URL or just a domain
    cond do
      # If it contains a path (has / after domain)
      String.contains?(line, "/") ->
        # Extract domain
        domain = line |> String.split("/") |> List.first()
        "domain:#{domain}"

      # If it's already in domain: format
      String.starts_with?(line, "domain:") ->
        line

      # Otherwise, it's just a domain
      true ->
        "domain:#{line}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 py-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Disavow Generator</h1>

      <!-- Grid 2 columns full height -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 flex-1 min-h-0">
        <!-- Left Section: Input -->
        <div class="flex flex-col min-h-0">
          <h2 class="text-2xl font-semibold mb-3">Domains to disavow:</h2>
          <form phx-change="validate" class="flex-1 flex flex-col min-h-0">
            <textarea
              name="input_text"
              class="textarea textarea-bordered w-full flex-1 font-mono text-sm resize-none"
              placeholder="Paste the bad links here"
            ><%= @input_text %></textarea>
          </form>
        </div>

        <!-- Right Section: Result -->
        <div class="flex flex-col min-h-0">
          <h2 class="text-2xl font-semibold mb-3">Result:</h2>
          <textarea
            id="result-textarea"
            class="textarea textarea-bordered w-full flex-1 font-mono text-sm bg-base-200 resize-none"
            readonly
          ><%= @result_text %></textarea>
        </div>
      </div>

      <!-- Buttons Row -->
      <div class="flex gap-3 mt-6 justify-end">
        <button
          type="button"
          phx-click="save_to_file"
          class="btn btn-primary text-white"
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
              d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          Lưu vào file
        </button>

        <button
          type="button"
          phx-click="copy_to_clipboard"
          id="copy-button"
          class="btn btn-success text-white"
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
              d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
            />
          </svg>
          Sao chép
        </button>
      </div>

      <div class="mt-8 p-4 bg-base-200 rounded-lg">
        <h3 class="font-bold text-lg mb-2">Hướng dẫn sử dụng:</h3>
        <ul class="list-disc list-inside space-y-1 text-sm">
          <li>Dán các liên kết hoặc tên miền xấu vào ô bên trái</li>
          <li>Công cụ sẽ tự động chuyển đổi chúng sang định dạng disavow phù hợp</li>
          <li>Kết quả sẽ hiển thị ở ô bên phải với định dạng "domain:example.com"</li>
          <li>Nhấn "Lưu vào file" để tải xuống file disavow_file.txt</li>
          <li>Hoặc nhấn "Sao chép vào clipboard" để sao chép vào clipboard</li>
        </ul>
      </div>
    </div>

    <script>
      window.addEventListener("phx:download_file", (e) => {
        const element = document.createElement('a');
        element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(e.detail.content));
        element.setAttribute('download', e.detail.filename);
        element.style.display = 'none';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
      });

      window.addEventListener("phx:copy_to_clipboard", (e) => {
        navigator.clipboard.writeText(e.detail.content).then(function() {
          const btn = document.getElementById('copy-button');
          const originalContent = btn.innerHTML;
          btn.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            Đã sao chép!
          `;

          setTimeout(() => {
            btn.innerHTML = originalContent;
          }, 1500);
        });
      });
    </script>
    """
  end
end
