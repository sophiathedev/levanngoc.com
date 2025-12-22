defmodule LevanngocWeb.FreeToolsLive.RedirectChecker do
  use LevanngocWeb, :live_view

  @max_redirects 10
  @timeout 10_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Kiểm tra Redirect")
     |> assign(:url_input, "")
     |> assign(:checking, false)
     |> assign(:redirect_chain, [])
     |> assign(:error_message, nil)
     |> assign(:summary, nil)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_url", %{"url" => value}, socket) do
    {:noreply, assign(socket, :url_input, String.trim(value))}
  end

  @impl true
  def handle_event("check_redirect", _params, socket) do
    url = socket.assigns.url_input

    # Validate URL
    case validate_url(url) do
      {:ok, validated_url} ->
        send(self(), {:check_redirect_async, validated_url})

        {:noreply,
         socket
         |> assign(:checking, true)
         |> assign(:redirect_chain, [])
         |> assign(:error_message, nil)
         |> assign(:summary, nil)}

      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    {:noreply,
     socket
     |> assign(:url_input, "")
     |> assign(:redirect_chain, [])
     |> assign(:error_message, nil)
     |> assign(:summary, nil)}
  end

  @impl true
  def handle_info({:check_redirect_async, url}, socket) do
    case check_redirect_chain(url) do
      {:ok, chain, summary} ->
        {:noreply,
         socket
         |> assign(:checking, false)
         |> assign(:redirect_chain, chain)
         |> assign(:summary, summary)
         |> assign(:error_message, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:checking, false)
         |> assign(:error_message, reason)}
    end
  end

  # Validate URL format
  defp validate_url(url) when is_binary(url) do
    url = String.trim(url)

    cond do
      url == "" ->
        {:error, "Vui lòng nhập URL"}

      not String.match?(url, ~r/^https?:\/\//i) ->
        {:error, "URL phải bắt đầu bằng http:// hoặc https://"}

      true ->
        {:ok, url}
    end
  end

  # Check redirect chain
  defp check_redirect_chain(url) do
    start_time = System.monotonic_time(:millisecond)

    case follow_redirects(url, [], 0) do
      {:ok, chain} ->
        end_time = System.monotonic_time(:millisecond)
        total_time = end_time - start_time

        summary = build_summary(chain, total_time)
        {:ok, chain, summary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Recursively follow redirects
  defp follow_redirects(url, chain, depth) when depth >= @max_redirects do
    {:ok,
     chain ++
       [
         %{
           url: url,
           status_code: nil,
           status_text: "Max redirects reached",
           redirect_type: nil,
           location: nil,
           is_final: true,
           error: "Đã đạt giới hạn #{@max_redirects} redirects"
         }
       ]}
  end

  defp follow_redirects(url, chain, depth) do
    request_start = System.monotonic_time(:millisecond)

    case HTTPoison.get(url, [], follow_redirect: false, timeout: @timeout, recv_timeout: @timeout) do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: headers}} ->
        request_end = System.monotonic_time(:millisecond)
        response_time = request_end - request_start

        redirect_info = %{
          url: url,
          status_code: status_code,
          status_text: get_status_text(status_code),
          redirect_type: get_redirect_type(status_code),
          location: get_location_header(headers),
          response_time: response_time,
          is_final: !is_redirect_status?(status_code),
          error: nil
        }

        new_chain = chain ++ [redirect_info]

        # If it's a redirect, follow it
        if is_redirect_status?(status_code) do
          case get_location_header(headers) do
            nil ->
              {:ok,
               new_chain ++
                 [
                   %{
                     url: nil,
                     status_code: nil,
                     status_text: "Redirect Error",
                     redirect_type: nil,
                     location: nil,
                     is_final: true,
                     error: "Không tìm thấy Location header"
                   }
                 ]}

            next_url ->
              # Resolve relative URLs
              absolute_url = resolve_url(url, next_url)
              follow_redirects(absolute_url, new_chain, depth + 1)
          end
        else
          {:ok, new_chain}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        error_message = format_error_reason(reason)

        {:ok,
         chain ++
           [
             %{
               url: url,
               status_code: nil,
               status_text: "Error",
               redirect_type: nil,
               location: nil,
               is_final: true,
               error: error_message
             }
           ]}
    end
  end

  # Check if status code is a redirect
  defp is_redirect_status?(status) when status in [301, 302, 303, 307, 308], do: true
  defp is_redirect_status?(_), do: false

  # Get redirect type description
  defp get_redirect_type(301), do: "Permanent (301)"
  defp get_redirect_type(302), do: "Temporary (302)"
  defp get_redirect_type(303), do: "See Other (303)"
  defp get_redirect_type(307), do: "Temporary (307)"
  defp get_redirect_type(308), do: "Permanent (308)"
  defp get_redirect_type(_), do: nil

  # Get status text
  defp get_status_text(200), do: "OK"
  defp get_status_text(301), do: "Moved Permanently"
  defp get_status_text(302), do: "Found"
  defp get_status_text(303), do: "See Other"
  defp get_status_text(307), do: "Temporary Redirect"
  defp get_status_text(308), do: "Permanent Redirect"
  defp get_status_text(400), do: "Bad Request"
  defp get_status_text(401), do: "Unauthorized"
  defp get_status_text(403), do: "Forbidden"
  defp get_status_text(404), do: "Not Found"
  defp get_status_text(500), do: "Internal Server Error"
  defp get_status_text(502), do: "Bad Gateway"
  defp get_status_text(503), do: "Service Unavailable"
  defp get_status_text(code), do: "HTTP #{code}"

  # Get location header from response headers
  defp get_location_header(headers) do
    headers
    |> Enum.find(fn {key, _} -> String.downcase(key) == "location" end)
    |> case do
      {_, location} -> location
      nil -> nil
    end
  end

  # Resolve relative URLs
  defp resolve_url(base_url, relative_url) do
    cond do
      String.starts_with?(relative_url, "http://") or
          String.starts_with?(relative_url, "https://") ->
        relative_url

      String.starts_with?(relative_url, "//") ->
        %URI{scheme: scheme} = URI.parse(base_url)
        "#{scheme}:#{relative_url}"

      String.starts_with?(relative_url, "/") ->
        uri = URI.parse(base_url)
        "#{uri.scheme}://#{uri.host}#{if uri.port, do: ":#{uri.port}", else: ""}#{relative_url}"

      true ->
        uri = URI.parse(base_url)
        path = Path.dirname(uri.path || "/")

        "#{uri.scheme}://#{uri.host}#{if uri.port, do: ":#{uri.port}", else: ""}#{path}/#{relative_url}"
    end
  end

  # Format error reason
  defp format_error_reason(:timeout), do: "Timeout - Server không phản hồi"
  defp format_error_reason(:nxdomain), do: "Domain không tồn tại"
  defp format_error_reason(:econnrefused), do: "Kết nối bị từ chối"
  defp format_error_reason(:closed), do: "Kết nối bị đóng"
  defp format_error_reason(reason), do: "Lỗi: #{inspect(reason)}"

  # Build summary statistics
  defp build_summary(chain, total_time) do
    redirect_count = Enum.count(chain, fn item -> item.redirect_type != nil end)
    first_status = List.first(chain)
    final_status = List.last(chain)

    %{
      total_redirects: redirect_count,
      total_time: total_time,
      final_url: final_status.url,
      final_status: first_status.status_code,
      has_error: final_status.error != nil
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full px-4 flex flex-col">
      <h1 class="text-3xl font-bold mb-6">Kiểm tra Redirect</h1>

      <div class="card bg-base-100 shadow-xl border border-base-300 flex-1 flex flex-col">
        <div class="card-body flex flex-col flex-1">
          <form phx-change="validate" phx-submit="check_redirect" class="flex flex-col flex-1">
            <!-- URL Input -->
            <div class="form-control w-full mb-4">
              <label class="label">
                <span class="label-text font-medium">Nhập URL cần kiểm tra:</span>
              </label>
              <input
                type="text"
                placeholder="https://example.com"
                class="input input-bordered w-full"
                value={@url_input}
                phx-change="update_url"
                name="url"
                required
              />
              <label class="label">
                <span class="label-text-alt">Nhập URL đầy đủ bao gồm http:// hoặc https://</span>
              </label>
            </div>
            
    <!-- Error Message -->
            <%= if @error_message do %>
              <div class="alert alert-error mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="stroke-current shrink-0 h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span>{@error_message}</span>
              </div>
            <% end %>
            
    <!-- Summary Stats -->
            <%= if @summary do %>
              <div class="stats stats-vertical lg:stats-horizontal shadow mb-4 w-full">
                <div class="stat">
                  <div class="stat-figure text-primary">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="inline-block w-8 h-8 stroke-current"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"
                      />
                    </svg>
                  </div>
                  <div class="stat-title">Tổng số Redirects</div>
                  <div class="stat-value text-primary">{@summary.total_redirects}</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-secondary">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="inline-block w-8 h-8 stroke-current"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                  </div>
                  <div class="stat-title">Thời gian</div>
                  <div class="stat-value text-secondary">{@summary.total_time}ms</div>
                </div>

                <div class="stat">
                  <div class={"stat-figure #{if @summary.has_error, do: "text-error", else: "text-success"}"}>
                    <%= if @summary.has_error do %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        class="inline-block w-8 h-8 stroke-current"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                    <% else %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        class="inline-block w-8 h-8 stroke-current"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                    <% end %>
                  </div>
                  <div class="stat-title">Trạng thái</div>
                  <div class={"stat-value #{if @summary.has_error, do: "text-error", else: "text-success"}"}>
                    {if @summary.final_status, do: @summary.final_status, else: "Error"}
                  </div>
                </div>
              </div>
            <% end %>
            
    <!-- Results Section -->
            <%= if @redirect_chain != [] do %>
              <div class="form-control w-full mb-4 flex-1">
                <label class="label">
                  <span class="label-text font-medium">Chuỗi Redirect Chi Tiết:</span>
                </label>
                <div class="overflow-auto border border-base-300 rounded-lg p-4 bg-base-200 flex-1">
                  <div class="space-y-4">
                    <%= for {redirect, index} <- Enum.with_index(@redirect_chain) do %>
                      <div class="card bg-base-100 shadow-sm">
                        <div class="card-body p-4">
                          <!-- Header -->
                          <div class="flex items-start gap-3 mb-3">
                            <div class="badge badge-primary badge-lg font-bold">
                              {index + 1}
                            </div>
                            <div class="flex-1">
                              <%= if redirect.error do %>
                                <div class="flex items-center gap-2">
                                  <span class="badge badge-error">ERROR</span>
                                  <span class="text-sm font-semibold text-error">
                                    {redirect.error}
                                  </span>
                                </div>
                              <% else %>
                                <div class="flex items-center gap-2 flex-wrap">
                                  <span class={"badge badge-lg #{get_status_badge_class(redirect.status_code)}"}>
                                    {redirect.status_code}
                                  </span>
                                  <span class="text-sm font-semibold">
                                    {redirect.status_text}
                                  </span>
                                  <%= if redirect.redirect_type do %>
                                    <span class="badge badge-info badge-outline">
                                      {redirect.redirect_type}
                                    </span>
                                  <% end %>
                                  <%= if redirect.response_time do %>
                                    <span class="badge badge-ghost">
                                      {redirect.response_time}ms
                                    </span>
                                  <% end %>
                                </div>
                              <% end %>
                            </div>
                          </div>
                          
    <!-- URL -->
                          <div class="mb-2">
                            <div class="text-xs text-base-content/60 mb-1">URL:</div>
                            <div class="font-mono text-sm break-all bg-base-200 p-2 rounded">
                              {redirect.url || "N/A"}
                            </div>
                          </div>
                          
    <!-- Location (for redirects) -->
                          <%= if redirect.location do %>
                            <div>
                              <div class="text-xs text-base-content/60 mb-1">Redirect đến:</div>
                              <div class="font-mono text-sm break-all bg-base-200 p-2 rounded flex items-start gap-2">
                                <svg
                                  xmlns="http://www.w3.org/2000/svg"
                                  class="h-4 w-4 mt-0.5 text-primary flex-shrink-0"
                                  fill="none"
                                  viewBox="0 0 24 24"
                                  stroke="currentColor"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    stroke-width="2"
                                    d="M13 7l5 5m0 0l-5 5m5-5H6"
                                  />
                                </svg>
                                <span>{redirect.location}</span>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                      
    <!-- Arrow between cards -->
                      <%= if index < length(@redirect_chain) - 1 do %>
                        <div class="flex justify-center">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-6 w-6 text-primary"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M19 14l-7 7m0 0l-7-7m7 7V3"
                            />
                          </svg>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
            
    <!-- Buttons -->
            <div class="flex gap-3 justify-end">
              <%= if @redirect_chain != [] do %>
                <button type="button" class="btn btn-ghost" phx-click="clear_results">
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
                  Xóa kết quả
                </button>
              <% end %>

              <button
                type="submit"
                class="btn btn-primary"
                disabled={@url_input == "" or @checking}
              >
                <%= if @checking do %>
                  <span class="loading loading-spinner loading-sm"></span> Đang kiểm tra...
                <% else %>
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
                      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                    />
                  </svg>
                  Kiểm tra
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for status badge color
  defp get_status_badge_class(status) when status >= 200 and status < 300,
    do: "badge-success"

  defp get_status_badge_class(status) when status >= 300 and status < 400,
    do: "badge-info"

  defp get_status_badge_class(status) when status >= 400 and status < 500,
    do: "badge-warning"

  defp get_status_badge_class(status) when status >= 500, do: "badge-error"
  defp get_status_badge_class(_), do: "badge-ghost"
end
