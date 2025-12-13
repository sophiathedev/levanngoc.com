defmodule LevanngocWeb.SpinnerToolLive.Index do
  use LevanngocWeb, :live_view

  alias Levanngoc.External.Spintax

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:spin_content, "")
     |> assign(:conversion_type, "unspin_all")
     |> assign(:show_result_modal, false)
     |> assign(:result_text, "")
     |> assign(:show_link_builder_modal, false)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_spin_content", %{"content" => content}, socket) do
    {:noreply, assign(socket, :spin_content, content)}
  end

  @impl true
  def handle_event("update_conversion_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :conversion_type, type)}
  end

  @impl true
  def handle_event("convert", _params, socket) do
    case socket.assigns.conversion_type do
      "unspin_all" ->
        result = Spintax.unspin(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      "1_level_spin" ->
        result = Spintax.to_one_level(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      "unique_article_wizard" ->
        result = Spintax.convert(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      "seo_link_vine" ->
        result = Spintax.convert_to_bbcode(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      "free_traffic_system" ->
        result = Spintax.convert_to_fts(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      "article_rank_2_levels" ->
        result = Spintax.convert_to_article_rank(socket.assigns.spin_content)

        {:noreply,
         socket
         |> assign(:result_text, result)
         |> assign(:show_result_modal, true)}

      _ ->
        # TODO: Implement other conversion types
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("retry_unspin", _params, socket) do
    result =
      case socket.assigns.conversion_type do
        "unspin_all" ->
          Spintax.unspin(socket.assigns.spin_content)

        "1_level_spin" ->
          Spintax.to_one_level(socket.assigns.spin_content)

        "unique_article_wizard" ->
          Spintax.convert(socket.assigns.spin_content)

        "seo_link_vine" ->
          Spintax.convert_to_bbcode(socket.assigns.spin_content)

        "free_traffic_system" ->
          Spintax.convert_to_fts(socket.assigns.spin_content)

        "article_rank_2_levels" ->
          Spintax.convert_to_article_rank(socket.assigns.spin_content)

        _ ->
          socket.assigns.result_text
      end

    {:noreply, assign(socket, :result_text, result)}
  end

  @impl true
  def handle_event("open_link_builder", _params, socket) do
    {:noreply, assign(socket, :show_link_builder_modal, true)}
  end

  @impl true
  def handle_event("close_link_builder", _params, socket) do
    {:noreply, assign(socket, :show_link_builder_modal, false)}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Spinner Tool</h1>

      <div class="card bg-base-100 shadow-xl mb-6 border border-base-300 flex-1">
        <div class="card-body flex flex-col p-0">
          <form phx-change="validate" phx-submit="convert" class="flex flex-col flex-1 p-4">
            <div class="form-control w-full flex flex-col flex-1">
              <label class="label mb-2">
                <span class="label-text">Dán nội dung spin của bạn (định dạng &#123; | &#125;)</span>
              </label>
              <textarea
                class="w-full flex-1 textarea textarea-bordered rounded-lg focus:outline-primary focus:outline-2"
                placeholder="Ví dụ: {Xin chào|Hello|Hi} {thế giới|world|mọi người}"
                phx-change="update_spin_content"
                name="content"
              >{@spin_content}</textarea>
            </div>

            <div class="mt-4 flex justify-between items-center">
              <button type="button" class="btn btn-info" phx-click="open_link_builder">
                Link Builder
              </button>

              <div class="flex items-center gap-2">
                <div class="dropdown dropdown-top">
                  <label tabindex="0" class="btn btn-bordered w-64">
                    <%= case @conversion_type do %>
                      <% "unspin_all" -> %>
                        Unspin All
                      <% "1_level_spin" -> %>
                        1-Level Spin
                      <% "unique_article_wizard" -> %>
                        Unique Article Wizard
                      <% "seo_link_vine" -> %>
                        SEO Link Vine
                      <% "free_traffic_system" -> %>
                        Free Traffic System
                      <% "article_rank_2_levels" -> %>
                        Article Rank (2 levels)
                    <% end %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4 ml-2"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </label>
                  <ul tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-64 mb-2">
                    <li>
                      <button type="button" phx-click="update_conversion_type" phx-value-type="unspin_all">
                        Unspin All
                      </button>
                    </li>
                    <li>
                      <button type="button" phx-click="update_conversion_type" phx-value-type="1_level_spin">
                        1-Level Spin
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        phx-click="update_conversion_type"
                        phx-value-type="unique_article_wizard"
                      >
                        Unique Article Wizard
                      </button>
                    </li>
                    <li>
                      <button type="button" phx-click="update_conversion_type" phx-value-type="seo_link_vine">
                        SEO Link Vine
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        phx-click="update_conversion_type"
                        phx-value-type="free_traffic_system"
                      >
                        Free Traffic System
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        phx-click="update_conversion_type"
                        phx-value-type="article_rank_2_levels"
                      >
                        Article Rank (2 levels)
                      </button>
                    </li>
                  </ul>
                </div>
                <button
                  type="submit"
                  class="btn btn-primary min-w-[160px]"
                  disabled={@spin_content == ""}
                >
                  Convert
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box w-[70vw] max-w-none">
          <h3 class="font-bold text-lg mb-4">Kết quả Unspin</h3>

          <div class="form-control w-full">
            <textarea
              class="textarea textarea-bordered w-full h-96 font-mono"
              readonly
            >{@result_text}</textarea>
          </div>

          <div class="modal-action">
            <button
              class="btn btn-primary"
              onclick={"navigator.clipboard.writeText(#{Jason.encode!(@result_text)})"}
            >
              Sao chép
            </button>
            <button class="btn btn-info" phx-click="retry_unspin">
              Thử lại
            </button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30" phx-click="close_modal"></div>
      </div>
    <% end %>

    <%= if @show_link_builder_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-2xl" id="link-builder-container" phx-hook="LinkBuilder">
          <div class="flex justify-between items-center mb-4">
            <h3 class="font-bold text-lg">Link Builder</h3>
            <button
              type="button"
              class="btn btn-sm btn-ghost btn-circle"
              phx-click="close_link_builder"
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

          <div class="space-y-4">
            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">URL:</span>
              </label>
              <input
                type="text"
                data-link-url
                class="input input-bordered w-full"
                placeholder="https://google.com"
              />
            </div>

            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">Anchor Text:</span>
              </label>
              <input
                type="text"
                data-link-anchor
                class="input input-bordered w-full"
                placeholder="anchor"
              />
            </div>

            <div class="form-control w-full">
              <label class="label">
                <span class="label-text font-semibold">Built link:</span>
              </label>
              <input
                type="text"
                data-link-output
                class="input input-bordered w-full font-mono text-sm bg-base-200"
                readonly
              />
            </div>

            <div class="form-control w-full" data-link-test style="display: none;">
              <label class="label">
                <span class="label-text font-semibold">Test your link:</span>
              </label>
              <div class="p-3 bg-base-200 rounded-lg">
                <a data-link-anchor-test href="" class="link link-primary" target="_blank"></a>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30" phx-click="close_link_builder">
        </div>
      </div>
    <% end %>
    """
  end
end
