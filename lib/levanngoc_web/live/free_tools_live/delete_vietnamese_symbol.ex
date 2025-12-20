defmodule LevanngocWeb.FreeToolsLive.DeleteVietnameseSymbol do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Xóa dấu tiếng Việt")
     |> assign(:input_text, "")
     |> assign(:output_text, "")
     |> assign(:word_count, 0)
     |> assign(:char_count, 0)
     |> assign(:line_count, 0)
     |> assign(:space_count, 0)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_input", %{"text" => value}, socket) do
    output = remove_vietnamese_accents(value)
    stats = calculate_statistics(output)

    {:noreply,
     socket
     |> assign(:input_text, value)
     |> assign(:output_text, output)
     |> assign(:word_count, stats.words)
     |> assign(:char_count, stats.chars)
     |> assign(:line_count, stats.lines)
     |> assign(:space_count, stats.spaces)}
  end

  @impl true
  def handle_event("clear_all", _params, socket) do
    {:noreply,
     socket
     |> assign(:input_text, "")
     |> assign(:output_text, "")
     |> assign(:word_count, 0)
     |> assign(:char_count, 0)
     |> assign(:line_count, 0)
     |> assign(:space_count, 0)}
  end

  # Tính toán thống kê văn bản
  defp calculate_statistics(text) do
    if text == "" do
      %{words: 0, chars: 0, lines: 0, spaces: 0}
    else
      # Đếm số từ (tách bởi khoảng trắng)
      words =
        text
        |> String.split(~r/\s+/, trim: true)
        |> length()

      # Đếm số ký tự
      chars = String.length(text)

      # Đếm số dòng
      lines =
        text
        |> String.split("\n")
        |> length()

      # Đếm số khoảng trắng
      spaces =
        text
        |> String.graphemes()
        |> Enum.count(fn char -> char in [" ", "\t", "\n", "\r"] end)

      %{words: words, chars: chars, lines: lines, spaces: spaces}
    end
  end

  # Xóa dấu tiếng Việt
  defp remove_vietnamese_accents(text) do
    text
    |> String.replace(~r/[àáạảãâầấậẩẫăằắặẳẵ]/u, "a")
    |> String.replace(~r/[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]/u, "A")
    |> String.replace(~r/[èéẹẻẽêềếệểễ]/u, "e")
    |> String.replace(~r/[ÈÉẸẺẼÊỀẾỆỂỄ]/u, "E")
    |> String.replace(~r/[ìíịỉĩ]/u, "i")
    |> String.replace(~r/[ÌÍỊỈĨ]/u, "I")
    |> String.replace(~r/[òóọỏõôồốộổỗơờớợởỡ]/u, "o")
    |> String.replace(~r/[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]/u, "O")
    |> String.replace(~r/[ùúụủũưừứựửữ]/u, "u")
    |> String.replace(~r/[ÙÚỤỦŨƯỪỨỰỬỮ]/u, "U")
    |> String.replace(~r/[ỳýỵỷỹ]/u, "y")
    |> String.replace(~r/[ỲÝỴỶỸ]/u, "Y")
    |> String.replace(~r/[đ]/u, "d")
    |> String.replace(~r/[Đ]/u, "D")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Xóa Dấu Tiếng Việt</h1>

      <div class="card bg-base-100 shadow-xl border border-base-300 flex-1 flex flex-col">
        <div class="card-body flex flex-col flex-1">
          <form phx-change="validate" class="flex flex-col flex-1 gap-4">
            <!-- Input Textarea -->
            <div class="form-control w-full flex-1 flex flex-col">
              <label class="label">
                <span class="label-text font-medium">Văn bản có dấu:</span>
              </label>
              <textarea
                class="textarea textarea-bordered w-full flex-1 font-mono text-sm"
                placeholder="Nhập văn bản tiếng Việt có dấu vào đây..."
                phx-change="update_input"
                name="text"
                id="input-text"
              ><%= @input_text %></textarea>
            </div>

    <!-- Output Textarea -->
            <div class="form-control w-full flex-1 flex flex-col">
              <label class="label">
                <span class="label-text font-medium">Văn bản không dấu:</span>
              </label>
              <textarea
                class="textarea textarea-bordered w-full flex-1 font-mono text-sm"
                readonly
                id="output-text"
              ><%= @output_text %></textarea>
            </div>

    <!-- Statistics and Buttons -->
            <div class="flex gap-3 justify-between items-center">
              <!-- Statistics -->
              <div class="flex gap-4 text-sm">
                <div class="flex items-center gap-1">
                  <span class="font-medium">Số từ:</span>
                  <span class="text-primary font-semibold">{@word_count}</span>
                </div>
                <div class="flex items-center gap-1">
                  <span class="font-medium">Số ký tự:</span>
                  <span class="text-primary font-semibold">{@char_count}</span>
                </div>
                <div class="flex items-center gap-1">
                  <span class="font-medium">Số dòng:</span>
                  <span class="text-primary font-semibold">{@line_count}</span>
                </div>
                <div class="flex items-center gap-1">
                  <span class="font-medium">Khoảng trắng:</span>
                  <span class="text-primary font-semibold">{@space_count}</span>
                </div>
              </div>

    <!-- Buttons -->
              <div class="flex gap-3">
                <button
                  type="button"
                  class="btn btn-ghost"
                  phx-click="clear_all"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                  Xóa tất cả
                </button>

                <button
                  type="button"
                  class="btn btn-primary"
                  disabled={@output_text == ""}
                  onclick="copyToClipboard()"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
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
            </div>
          </form>
        </div>
      </div>
    </div>

    <script>
      function copyToClipboard() {
        const content = document.getElementById('output-text').value;
        navigator.clipboard.writeText(content);
      }
    </script>
    """
  end
end
