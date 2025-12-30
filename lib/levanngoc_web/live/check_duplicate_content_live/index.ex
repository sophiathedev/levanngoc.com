defmodule LevanngocWeb.CheckDuplicateContentLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Safely get user from current_scope
    user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    # Check if user is logged in
    is_logged_in = user != nil

    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra trùng lặp nội dung")
     |> assign(:is_logged_in, is_logged_in)
     |> assign(:show_login_required_modal, !is_logged_in)
     |> assign(:is_processing, false)
     |> assign(:timer_text, "00:00:00.0")
     |> assign(:start_time, nil)
     |> assign(:show_result_modal, false)
     |> assign(:post_title, "")
     |> assign(:content_input, "")
     |> LevanngocWeb.TrackToolVisit.track_visit("/check-duplicate-content")}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    content = socket.assigns.content_input |> String.trim()

    if content == "" do
      {:noreply, put_flash(socket, :error, "Vui lòng nhập nội dung cần kiểm tra")}
    else
      # Start processing directly without confirmation
      socket =
        socket
        |> assign(:is_processing, true)
        |> assign(:start_time, DateTime.utc_now())
        |> assign(:timer_text, "00:00:00.0")

      # Start timer
      :timer.send_interval(100, self(), :tick)

      # Process in async task to allow UI updates
      pid = self()

      Task.start(fn ->
        # This is a placeholder - implement your duplicate content checking logic here
        results = check_duplicate_content(content)
        send(pid, {:processing_complete, [{nil, results}]})
      end)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_post_title", %{"post_title" => post_title}, socket) do
    {:noreply, assign(socket, :post_title, post_title)}
  end

  @impl true
  def handle_event("update_content", %{"content" => content}, socket) do
    {:noreply, assign(socket, :content_input, content)}
  end

  @impl true
  def handle_event("close_result_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_result_modal, false)
     |> assign(:duplicate_results, [])}
  end

  @impl true
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_login_required_modal, false)}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.is_processing do
      now = DateTime.utc_now()
      diff = DateTime.diff(now, socket.assigns.start_time, :millisecond)

      hours = div(diff, 3600_000)
      rem_h = rem(diff, 3600_000)
      minutes = div(rem_h, 60_000)
      rem_m = rem(rem_h, 60_000)
      seconds = div(rem_m, 1000)
      millis = rem(rem_m, 1000)
      tenth = div(millis, 100)

      timer_text = "#{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}.#{tenth}"

      {:noreply, assign(socket, :timer_text, timer_text)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:processing_complete, results_list}, socket) do
    all_results =
      results_list
      |> Enum.flat_map(fn {_path, results} -> results end)

    processing_time = socket.assigns.timer_text

    {:noreply,
     socket
     |> assign(:is_processing, false)
     |> assign(:duplicate_results, all_results)
     |> assign(:processing_time, processing_time)
     |> assign(:show_result_modal, true)}
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  # Placeholder duplicate content checking logic
  # Replace this with your actual duplicate checking algorithm
  defp check_duplicate_content(content) do
    # Simple placeholder: return analysis result
    [
      %{
        content: content,
        is_duplicate: Enum.random([true, false]),
        similarity_score: Enum.random(0..100),
        duplicate_of: nil
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Kiểm tra trùng lặp nội dung</h1>

      <div class="card bg-base-100 shadow-xl mb-6 border border-base-300 flex-1">
        <div class="card-body flex flex-col">
          <form phx-change="validate" phx-submit="save" class="flex flex-col flex-1">
            <div class="form-control w-full mb-4">
              <label class="label mb-2">
                <span class="label-text">Tiêu đề bài viết</span>
              </label>
              <input
                type="text"
                class="input w-full rounded-lg"
                placeholder="Nhập tiêu đề bài viết"
                value={@post_title}
                phx-change="update_post_title"
                name="post_title"
                disabled={!@is_logged_in or @is_processing}
              />
            </div>

            <div class="form-control w-full flex flex-col flex-1">
              <label class="label mb-2">
                <span class="label-text">Nội dung</span>
              </label>
              <textarea
                id="content-input"
                class="w-full flex-1 textarea textarea-bordered rounded-lg"
                placeholder="Nhập nội dung cần kiểm tra trùng lặp..."
                phx-change="update_content"
                name="content"
                phx-hook="AutoResize"
                disabled={!@is_logged_in or @is_processing}
              >{@content_input}</textarea>
            </div>
            <div class="mt-4 flex justify-end items-center">
              <button
                type="submit"
                class="btn btn-primary min-w-[160px]"
                disabled={true}
              >
                <%= if @is_processing do %>
                  {@timer_text}
                <% else %>
                  Kiểm tra trùng lặp
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <%= if @show_result_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-4xl relative z-50">
          <h3 class="font-bold text-lg mb-4">Kết quả kiểm tra trùng lặp nội dung</h3>

          <div class="space-y-2 max-h-96 overflow-y-auto">
            <%= for result <- @duplicate_results do %>
              <div class={"card shadow-sm #{if result.is_duplicate, do: "bg-error/10 border border-error/30", else: "bg-success/10 border border-success/30"}"}>
                <div class="card-body p-4">
                  <div class="flex items-start justify-between gap-4">
                    <div class="flex-1 min-w-0">
                      <p class="text-sm break-words whitespace-pre-wrap">{result.content}</p>
                    </div>
                    <div class="flex items-center gap-2 flex-shrink-0">
                      <span class={"badge #{if result.is_duplicate, do: "badge-error", else: "badge-success"}"}>
                        <%= if result.is_duplicate do %>
                          Trùng lặp
                        <% else %>
                          Không trùng
                        <% end %>
                      </span>
                      <span class="badge badge-outline">
                        {result.similarity_score}%
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="mt-4 pt-4 border-t">
            <div class="text-sm text-base-content/70">
              Thời gian xử lý: <span class="font-semibold">{@processing_time}</span>
            </div>
          </div>

          <div class="modal-action">
            <button class="btn btn-primary" phx-click="close_result_modal">Đóng</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
      </div>
    <% end %>

    <%= if @show_login_required_modal do %>
      <div class="modal modal-open">
        <div class="modal-box relative z-50">
          <h3 class="font-bold text-lg mb-4">Yêu cầu đăng nhập</h3>
          <div class="py-4">
            <div class="flex justify-center mb-4">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-16 w-16 text-warning"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <p class="text-center text-base-content">
              Bạn cần đăng nhập để sử dụng chức năng này.
            </p>
          </div>
          <div class="modal-action justify-center">
            <button class="btn btn-primary" phx-click="close_login_modal">Tôi đã hiểu</button>
          </div>
        </div>
        <div class="modal-backdrop backdrop-blur-sm bg-black/30"></div>
      </div>
    <% end %>
    """
  end
end
