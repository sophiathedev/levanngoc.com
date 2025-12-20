defmodule LevanngocWeb.FreeToolsLive.ExtractDomain do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tách tên miền từ URL")
     |> assign(:input_urls, "")
     |> assign(:result_domains, "")
     |> assign(:remove_duplicates, true)}
  end

  @impl true
  def handle_event("validate", %{"input_urls" => urls} = params, socket) do
    remove_duplicates = Map.get(params, "remove_duplicates") == "on"

    {:noreply,
     socket
     |> assign(:input_urls, urls)
     |> assign(:remove_duplicates, remove_duplicates)}
  end

  @impl true
  def handle_event("extract", _params, socket) do
    result = extract_domains(socket.assigns.input_urls, socket.assigns.remove_duplicates)
    {:noreply, assign(socket, :result_domains, result)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:input_urls, "")
     |> assign(:result_domains, "")
     |> assign(:remove_duplicates, false)}
  end

  defp extract_domains(input, remove_duplicates) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&extract_domain_from_url/1)
    |> then(fn domains ->
      if remove_duplicates, do: Enum.uniq(domains), else: domains
    end)
    |> Enum.join("\n")
  end

  defp extract_domain_from_url(url) do
    url = String.trim(url)

    # Remove protocol
    url = String.replace(url, ~r/^https?:\/\//, "")
    url = String.replace(url, ~r/^www\./, "")

    # Extract domain (everything before the first /)
    case String.split(url, "/") do
      [domain | _] -> domain
      [] -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 py-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Tách tên miền từ URL</h1>

      <!-- Grid 2 columns full height -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 flex-1 min-h-0">
        <!-- Left Section: URLs Input -->
        <div class="flex flex-col min-h-0">
          <h2 class="text-2xl font-semibold mb-3">Danh sách URL</h2>
          <form phx-change="validate" class="flex-1 flex flex-col min-h-0">
            <textarea
              name="input_urls"
              class="textarea textarea-bordered w-full flex-1 font-mono text-sm resize-none"
              placeholder="Thêm vào danh sách Urls cần lọc"
            ><%= @input_urls %></textarea>
          </form>
        </div>

        <!-- Right Section: Domains Output -->
        <div class="flex flex-col min-h-0">
          <h2 class="text-2xl font-semibold mb-3">Domains</h2>
          <textarea
            id="result-textarea"
            class="textarea textarea-bordered w-full flex-1 font-mono text-sm bg-base-200 resize-none"
            readonly
          ><%= @result_domains %></textarea>
        </div>
      </div>

      <!-- Checkbox and Buttons -->
      <div class="mt-6 space-y-2 flex justify-between items-center">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            name="remove_duplicates"
            phx-click="validate"
            checked={@remove_duplicates}
            class="checkbox"
          />
          <span class="font-medium">Xóa kết quả trùng lập</span>
        </label>

        <div class="flex gap-2">


          <button
            type="button"
            phx-click="reset"
            class="btn btn-soft px-8"
          >
          Reset
          </button>
          <button
            type="button"
            phx-click="extract"
            class="btn btn-primary text-white px-8"
          >
          Tách domain
          </button>
        </div>
      </div>
    </div>
    """
  end
end
