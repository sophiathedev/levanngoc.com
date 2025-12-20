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

    {:noreply, assign(socket, :generated_aliases, aliases)}
  end

  @impl true
  def handle_event("export_to_txt", _params, socket) do
    # Client-side export will be handled via JS hook
    {:noreply, socket}
  end

  defp generate_alias_list(email, num_str, method) do
    with {num, _} <- Integer.parse(num_str),
         true <- num > 0 and num <= 500,
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

  # Generate random +alias variations (like Python's random_plus_aliases)
  defp generate_plus_aliases(username, domain, count) do
    1..count
    |> Enum.map(fn _ ->
      # Generate random string of 5-10 characters (lowercase + digits)
      alias_length = Enum.random(5..10)
      chars = "abcdefghijklmnopqrstuvwxyz0123456789" |> String.graphemes()

      random_alias =
        1..alias_length
        |> Enum.map(fn _ -> Enum.random(chars) end)
        |> Enum.join("")

      "#{username}+#{random_alias}@#{domain}"
    end)
    |> Enum.uniq()
    |> Enum.take(count)
    |> Enum.join("\n")
  end

  # Generate dot variations (like Python's dot_variations)
  # Creates all possible combinations of inserting dots between characters
  defp generate_dot_variations(username, domain, max_variants) do
    if String.length(username) <= 1 do
      "#{username}@#{domain}"
    else
      # Get all positions where we can insert dots (between characters)
      indices = 1..(String.length(username) - 1) |> Enum.to_list()

      # Generate all combinations of dot positions (up to 9 dots max)
      max_dots = min(length(indices), 9)

      variations =
        1..max_dots
        |> Enum.flat_map(fn dot_count ->
          combinations(indices, dot_count)
        end)
        |> Enum.map(fn dot_positions ->
          insert_dots_at_indices(username, dot_positions, domain)
        end)
        |> Enum.uniq()
        |> Enum.take(max_variants)

      Enum.join(variations, "\n")
    end
  end

  # Generate combinations of size k from a list (like Python's itertools.combinations)
  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], k) do
    for(l <- combinations(t, k - 1), do: [h | l]) ++ combinations(t, k)
  end

  # Insert dots at specified indices in username
  defp insert_dots_at_indices(username, dot_positions, domain) do
    graphemes = String.graphemes(username)

    result =
      graphemes
      |> Enum.with_index()
      |> Enum.map(fn {char, idx} ->
        # Check if we should add a dot after this character
        # dot_positions are 1-based indices (between characters)
        if (idx + 1) in dot_positions do
          char <> "."
        else
          char
        end
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
                  <span class="label-text font-medium">Số lượng alias (100 - 500):</span>
                </label>
                <input
                  type="number"
                  min="100"
                  max="500"
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
              ><%= @generated_aliases %></textarea>
            </div>
            
    <!-- Buttons -->
            <div class="flex gap-3 justify-end">
              <button
                type="button"
                class="btn btn-info"
                phx-click="export_to_txt"
                disabled={@generated_aliases == ""}
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
          </form>
        </div>
      </div>
    </div>

    <script>
      function exportToTxt() {
        const content = document.getElementById('alias-result').value;
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
