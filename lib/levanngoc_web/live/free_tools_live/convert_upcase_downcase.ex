defmodule LevanngocWeb.FreeToolsLive.ConvertUpcaseDowncase do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Chuyển đổi Hoa/Thường")
     |> assign(:input_text, "")
     |> assign(:output_text, "")
     |> assign(:convert_mode, "uppercase")
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
    output = convert_text(value, socket.assigns.convert_mode)
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
  def handle_event("update_mode", %{"mode" => mode}, socket) do
    output = convert_text(socket.assigns.input_text, mode)
    stats = calculate_statistics(output)

    {:noreply,
     socket
     |> assign(:convert_mode, mode)
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

  # Chuyển đổi văn bản theo chế độ
  defp convert_text(text, mode) do
    case mode do
      "uppercase" -> String.upcase(text)
      "lowercase" -> String.downcase(text)
      "titlecase" -> titlecase(text)
      "togglecase" -> toggle_case(text)
      _ -> text
    end
  end

  # Chuyển chữ cái đầu mỗi từ thành hoa
  defp titlecase(text) do
    text
    |> String.split(~r/(\s+)/, include_captures: true)
    |> Enum.map(fn word ->
      if String.match?(word, ~r/^\s+$/) do
        word
      else
        String.capitalize(word)
      end
    end)
    |> Enum.join("")
  end

  # Đảo ngược chữ hoa/thường
  defp toggle_case(text) do
    text
    |> String.graphemes()
    |> Enum.map(fn char ->
      cond do
        String.upcase(char) == char and String.downcase(char) != char ->
          String.downcase(char)

        String.downcase(char) == char and String.upcase(char) != char ->
          String.upcase(char)

        true ->
          char
      end
    end)
    |> Enum.join("")
  end

  # Lấy tên hiển thị của chế độ
  defp get_mode_label(mode) do
    case mode do
      "uppercase" -> "CHỮ HOA (UPPERCASE)"
      "lowercase" -> "chữ thường (lowercase)"
      "titlecase" -> "Chữ Cái Đầu Hoa (Title Case)"
      "togglecase" -> "Đảo Ngược (tOGGLE cASE)"
      _ -> "CHỮ HOA (UPPERCASE)"
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <div class="card bg-base-100 shadow-xl border border-base-300 flex-1 flex flex-col">
        <div class="card-body flex flex-col flex-1">
          <form phx-change="validate" class="flex flex-col flex-1 gap-4">
            <!-- Title and Mode Selection -->
            <div class="flex justify-between items-center mb-2">
              <div>
                <h1 class="text-3xl font-bold">Chuyển Đổi Chữ Hoa/Thường</h1>
              </div>
              <div class="flex items-center gap-2">
                <h4 class="font-semibold text-md">Chuyển văn bản thành</h4>
                <div class="dropdown dropdown-end">
                  <div tabindex="0" role="button" class="btn btn-primary">
                    {get_mode_label(@convert_mode)}
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4 ml-2"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      />
                    </svg>
                  </div>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu bg-base-100 rounded-box z-[1] w-72 p-2 shadow-xl border border-base-300"
                  >
                    <li>
                      <a
                        phx-click="update_mode"
                        phx-value-mode="uppercase"
                        class={@convert_mode == "uppercase" && "active"}
                      >
                        CHỮ HOA (UPPERCASE)
                      </a>
                    </li>
                    <li>
                      <a
                        phx-click="update_mode"
                        phx-value-mode="lowercase"
                        class={@convert_mode == "lowercase" && "active"}
                      >
                        chữ thường (lowercase)
                      </a>
                    </li>
                    <li>
                      <a
                        phx-click="update_mode"
                        phx-value-mode="titlecase"
                        class={@convert_mode == "titlecase" && "active"}
                      >
                        Chữ Cái Đầu Hoa (Title Case)
                      </a>
                    </li>
                    <li>
                      <a
                        phx-click="update_mode"
                        phx-value-mode="togglecase"
                        class={@convert_mode == "togglecase" && "active"}
                      >
                        Đảo Ngược (tOGGLE cASE)
                      </a>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
            
    <!-- Input Textarea -->
            <div class="form-control w-full flex-1 flex flex-col">
              <label class="label">
                <span class="label-text font-medium">Văn bản gốc:</span>
              </label>
              <textarea
                class="textarea textarea-bordered w-full flex-1 font-mono text-sm"
                placeholder="Nhập văn bản cần chuyển đổi vào đây..."
                phx-change="update_input"
                name="text"
                id="input-text"
              ><%= @input_text %></textarea>
            </div>
            
    <!-- Output Textarea -->
            <div class="form-control w-full flex-1 flex flex-col">
              <label class="label">
                <span class="label-text font-medium">Kết quả:</span>
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
              <div class="flex gap-4 text-sm flex-wrap">
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
