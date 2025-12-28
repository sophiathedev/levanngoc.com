defmodule LevanngocWeb.FreeToolsLive.GmailAlias do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Gmail Alias")
     |> assign(:gmail_address, "")
     |> assign(:num_aliases, "100")
     |> assign(:alias_method, "plus")
     |> assign(:generated_aliases, "")}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_gmail", %{"gmail" => value}, socket) do
    {:noreply, assign(socket, :gmail_address, value)}
  end

  @impl true
  def handle_event("update_num_aliases", %{"num_aliases" => value}, socket) do
    {:noreply, assign(socket, :num_aliases, value)}
  end

  @impl true
  def handle_event("update_alias_method", %{"alias_method" => value}, socket) do
    {:noreply, assign(socket, :alias_method, value)}
  end

  @impl true
  def handle_event("generate_aliases", _params, socket) do
    aliases =
      generate_alias_list(
        socket.assigns.gmail_address,
        socket.assigns.num_aliases,
        socket.assigns.alias_method
      )

    {:noreply,
     socket
     |> assign(:generated_count, String.split(aliases, "\n") |> length())
     |> push_event("aliases_generated", %{aliases: aliases})}
  end

  @impl true
  def handle_event("export_to_txt", _params, socket) do
    {:noreply, socket}
  end

  defp generate_alias_list(email, num_str, method) do
    with {num, _} <- Integer.parse(num_str),
         true <- num > 0 and num <= 10000,
         [username, domain] <- String.split(email, "@", parts: 2) do
      case method do
        "plus" -> generate_plus_aliases(username, domain, num)
        "dot" -> generate_dot_variations(username, domain, num)
        _ -> generate_plus_aliases(username, domain, num)
      end
    else
      _ -> ""
    end
  end

  defp generate_plus_aliases(username, domain, count) do
    chars = "abcdefghijklmnopqrstuvwxyz0123456789" |> String.graphemes()

    Stream.repeatedly(fn ->
      alias_length = Enum.random(5..10)

      random_alias =
        1..alias_length
        |> Enum.map(fn _ -> Enum.random(chars) end)
        |> Enum.join("")

      "#{username}+#{random_alias}@#{domain}"
    end)
    |> Stream.uniq()
    |> Enum.take(count)
    |> Enum.join("\n")
  end

  defp generate_dot_variations(username, domain, max_variants) do
    if String.length(username) <= 1 do
      "#{username}@#{domain}"
    else
      indices = 1..(String.length(username) - 1) |> Enum.to_list()
      max_dots = min(length(indices), 9)

      # Generate variations lazily
      Stream.resource(
        fn -> {1, []} end,
        fn
          {current_dots, _acc} when current_dots > max_dots ->
            {:halt, nil}

          {current_dots, _acc} ->
            current_combos = combinations(indices, current_dots)
            # Map combinations to email variations
            variations =
              Enum.map(current_combos, fn dot_positions ->
                insert_dots_at_indices(username, dot_positions, domain)
              end)

            {variations, {current_dots + 1, []}}
        end,
        fn _ -> :ok end
      )
      |> Stream.uniq()
      |> Enum.take(max_variants)
      |> Enum.join("\n")
    end
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], k) do
    for(l <- combinations(t, k - 1), do: [h | l]) ++ combinations(t, k)
  end

  defp insert_dots_at_indices(username, dot_positions, domain) do
    graphemes = String.graphemes(username)

    result =
      graphemes
      |> Enum.with_index()
      |> Enum.map(fn {char, idx} ->
        if (idx + 1) in dot_positions, do: char <> ".", else: char
      end)
      |> Enum.join("")

    "#{result}@#{domain}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Gmail Alias Generator</h1>

      <div class="card bg-base-100 shadow-xl border border-base-300 flex-1 flex flex-col">
        <div class="card-body flex flex-col flex-1">
          <form phx-change="validate" phx-submit="generate_aliases" class="flex flex-col flex-1">
            <!-- Gmail Input -->
            <div class="form-control w-full mb-4">
              <label class="label">
                <span class="label-text font-medium">Nhập Gmail của bạn:</span>
              </label>
              <input
                type="email"
                placeholder="example@gmail.com"
                class="input input-bordered w-full"
                value={@gmail_address}
                phx-change="update_gmail"
                name="gmail"
                required
              />
            </div>
            
    <!-- Number of Aliases and Method on same row -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text font-medium">Số lượng alias (100 - 10000):</span>
                </label>
                <input
                  type="number"
                  min="100"
                  max="10000"
                  placeholder="100"
                  class="input input-bordered w-full"
                  value={@num_aliases}
                  phx-change="update_num_aliases"
                  name="num_aliases"
                  required
                />
              </div>

              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text font-medium">Phương thức Alias:</span>
                </label>
                <select
                  class="select select-bordered w-full"
                  phx-change="update_alias_method"
                  name="alias_method"
                >
                  <option value="plus" selected={@alias_method == "plus"}>+alias</option>
                  <option value="dot" selected={@alias_method == "dot"}>dot (.)</option>
                </select>
              </div>
            </div>
            
    <!-- Result Textarea -->
            <div class="form-control w-full mb-4 flex-1 flex flex-col">
              <label class="label">
                <span class="label-text font-medium">Kết quả:</span>
              </label>
              <textarea
                class="textarea textarea-bordered w-full flex-1 font-mono text-sm"
                readonly
                id="alias-result"
                spellcheck="false"
                wrap="off"
                style="contain: strict; white-space: pre; overflow: auto;"
                phx-update="ignore"
              ></textarea>
            </div>
            
    <!-- But -->
            <div class="flex justify-between items-center">
              <button
                type="button"
                id="btn-copy"
                class="btn btn-secondary"
                onclick="copyToClipboard(this)"
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
                    d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"
                  />
                </svg>
                Copy
              </button>

              <div class="flex gap-3">
                <button
                  type="button"
                  id="btn-export"
                  class="btn btn-info"
                  onclick="exportToTxt()"
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
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Xuất file .txt
                </button>

                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={@gmail_address == "" or @num_aliases == ""}
                  phx-disable-with="Đang tạo..."
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
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Tạo alias
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <script>
      window.addEventListener("phx:aliases_generated", (e) => {
        const textarea = document.getElementById('alias-result');
        textarea.value = e.detail.aliases;

        // Reset button states when new aliases are generated
        const btnCopy = document.getElementById('btn-copy');
        btnCopy.disabled = false;
        const btnExport = document.getElementById('btn-export');
        btnExport.disabled = false;
      });

      function copyToClipboard(btn) {
        const content = document.getElementById('alias-result').value;
        if (!content) return;

        navigator.clipboard.writeText(content).then(() => {
          const originalHTML = btn.innerHTML;
          btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg> Đã copy!';
          btn.classList.replace('btn-secondary', 'btn-success');

          setTimeout(() => {
            btn.innerHTML = originalHTML;
            btn.classList.replace('btn-success', 'btn-secondary');
          }, 2000);
        });
      }

      function exportToTxt() {
        const content = document.getElementById('alias-result').value;
        if (!content) return;
        const blob = new Blob([content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'gmail-aliases.txt';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    </script>
    """
  end
end
