defmodule LevanngocWeb.SpinnerToolLive.Index do
  use LevanngocWeb, :live_view

  alias Levanngoc.External.Spintax

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:spin_content, "")
     |> assign(:show_result_modal, false)
     |> assign(:result_text, "")}
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
  def handle_event("convert", _params, socket) do
    result = Spintax.unspin(socket.assigns.spin_content)

    {:noreply,
     socket
     |> assign(:result_text, result)
     |> assign(:show_result_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_result_modal, false)}
  end

  @impl true
  def handle_event("retry_unspin", _params, socket) do
    result = Spintax.unspin(socket.assigns.spin_content)
    {:noreply, assign(socket, :result_text, result)}
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

            <div class="mt-4 flex justify-end">
              <button
                type="submit"
                class="btn btn-primary min-w-[160px]"
                disabled={@spin_content == ""}
              >
                Unspin
              </button>
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

    """
  end
end
