defmodule LevanngocWeb.AdminLive.TokenUsage do
  use LevanngocWeb, :live_view

  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.Repo

  @impl true
  def mount(_params, _session, socket) do
    settings = get_settings()
    token_url_index_value = if settings, do: settings.token_usage_check_url_index || 0, else: 0
    token_allintitle_value = if settings, do: settings.token_usage_check_allintitle || 0, else: 0

    token_keyword_ranking_value =
      if settings, do: settings.token_usage_keyword_ranking || 0, else: 0

    token_keyword_grouping_value =
      if settings, do: settings.token_usage_keyword_grouping || 0, else: 0

    token_checking_duplicate_content_value =
      if settings, do: settings.token_usage_checking_duplicate_content || 0, else: 0

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:token_usage_check_url_index, token_url_index_value)
      |> assign(:token_usage_check_allintitle, token_allintitle_value)
      |> assign(:token_usage_keyword_ranking, token_keyword_ranking_value)
      |> assign(:token_usage_keyword_grouping, token_keyword_grouping_value)
      |> assign(:token_usage_checking_duplicate_content, token_checking_duplicate_content_value)
      |> assign(:editing_url_index, false)
      |> assign(:editing_allintitle, false)
      |> assign(:editing_keyword_ranking, false)
      |> assign(:editing_keyword_grouping, false)
      |> assign(:editing_checking_duplicate_content, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("edit_url_index", _params, socket) do
    {:noreply, assign(socket, :editing_url_index, true)}
  end

  @impl true
  def handle_event("cancel_url_index", _params, socket) do
    # Reset to the saved value from database
    settings = socket.assigns.settings
    saved_value = if settings, do: settings.token_usage_check_url_index || 0, else: 0

    {:noreply,
     socket
     |> assign(:editing_url_index, false)
     |> assign(:token_usage_check_url_index, saved_value)}
  end

  @impl true
  def handle_event("save_url_index", %{"token_value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {int_value, ""} when int_value > 0 ->
        case save_or_update_setting(:token_usage_check_url_index, int_value) do
          {:ok, _updated_settings} ->
            # Reload fresh from database to ensure we have the latest value
            fresh_settings = get_settings()

            new_value =
              if fresh_settings, do: fresh_settings.token_usage_check_url_index || 0, else: 0

            {:noreply,
             socket
             |> assign(:settings, fresh_settings)
             |> assign(:token_usage_check_url_index, new_value)
             |> assign(:editing_url_index, false)
             |> put_flash(:info, "Đã cập nhật lượng token sử dụng cho Kiểm tra URL Index")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Token Usage Check URL Index")}
        end

      _ ->
        {:noreply,
         put_flash(socket, :error, "Token Usage Check URL Index must be a positive integer")}
    end
  end

  @impl true
  def handle_event("edit_allintitle", _params, socket) do
    {:noreply, assign(socket, :editing_allintitle, true)}
  end

  @impl true
  def handle_event("cancel_allintitle", _params, socket) do
    # Reset to the saved value from database
    settings = socket.assigns.settings
    saved_value = if settings, do: settings.token_usage_check_allintitle || 0, else: 0

    {:noreply,
     socket
     |> assign(:editing_allintitle, false)
     |> assign(:token_usage_check_allintitle, saved_value)}
  end

  @impl true
  def handle_event("save_allintitle", %{"token_value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {int_value, ""} when int_value > 0 ->
        case save_or_update_setting(:token_usage_check_allintitle, int_value) do
          {:ok, _updated_settings} ->
            # Reload fresh from database to ensure we have the latest value
            fresh_settings = get_settings()

            new_value =
              if fresh_settings, do: fresh_settings.token_usage_check_allintitle || 0, else: 0

            {:noreply,
             socket
             |> assign(:settings, fresh_settings)
             |> assign(:token_usage_check_allintitle, new_value)
             |> assign(:editing_allintitle, false)
             |> put_flash(:info, "Đã cập nhật lượng token sử dụng cho Kiểm tra Allintitle")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Token Usage Check Allintitle")}
        end

      _ ->
        {:noreply,
         put_flash(socket, :error, "Token Usage Check Allintitle must be a positive integer")}
    end
  end

  @impl true
  def handle_event("edit_keyword_ranking", _params, socket) do
    {:noreply, assign(socket, :editing_keyword_ranking, true)}
  end

  @impl true
  def handle_event("cancel_keyword_ranking", _params, socket) do
    # Reset to the saved value from database
    settings = socket.assigns.settings
    saved_value = if settings, do: settings.token_usage_keyword_ranking || 0, else: 0

    {:noreply,
     socket
     |> assign(:editing_keyword_ranking, false)
     |> assign(:token_usage_keyword_ranking, saved_value)}
  end

  @impl true
  def handle_event("save_keyword_ranking", %{"token_value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {int_value, ""} when int_value > 0 ->
        case save_or_update_setting(:token_usage_keyword_ranking, int_value) do
          {:ok, _updated_settings} ->
            # Reload fresh from database to ensure we have the latest value
            fresh_settings = get_settings()

            new_value =
              if fresh_settings, do: fresh_settings.token_usage_keyword_ranking || 0, else: 0

            {:noreply,
             socket
             |> assign(:settings, fresh_settings)
             |> assign(:token_usage_keyword_ranking, new_value)
             |> assign(:editing_keyword_ranking, false)
             |> put_flash(:info, "Đã cập nhật lượng token sử dụng cho Kiểm tra thứ hạng từ khóa")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Token Usage Keyword Ranking")}
        end

      _ ->
        {:noreply,
         put_flash(socket, :error, "Token Usage Keyword Ranking must be a positive integer")}
    end
  end

  @impl true
  def handle_event("edit_keyword_grouping", _params, socket) do
    {:noreply, assign(socket, :editing_keyword_grouping, true)}
  end

  @impl true
  def handle_event("cancel_keyword_grouping", _params, socket) do
    # Reset to the saved value from database
    settings = socket.assigns.settings
    saved_value = if settings, do: settings.token_usage_keyword_grouping || 0, else: 0

    {:noreply,
     socket
     |> assign(:editing_keyword_grouping, false)
     |> assign(:token_usage_keyword_grouping, saved_value)}
  end

  @impl true
  def handle_event("save_keyword_grouping", %{"token_value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {int_value, ""} when int_value > 0 ->
        case save_or_update_setting(:token_usage_keyword_grouping, int_value) do
          {:ok, _updated_settings} ->
            # Reload fresh from database to ensure we have the latest value
            fresh_settings = get_settings()

            new_value =
              if fresh_settings, do: fresh_settings.token_usage_keyword_grouping || 0, else: 0

            {:noreply,
             socket
             |> assign(:settings, fresh_settings)
             |> assign(:token_usage_keyword_grouping, new_value)
             |> assign(:editing_keyword_grouping, false)
             |> put_flash(:info, "Đã cập nhật lượng token sử dụng cho Gom nhóm từ khóa")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Token Usage Keyword Grouping")}
        end

      _ ->
        {:noreply,
         put_flash(socket, :error, "Token Usage Keyword Grouping must be a positive integer")}
    end
  end

  @impl true
  def handle_event("edit_checking_duplicate_content", _params, socket) do
    {:noreply, assign(socket, :editing_checking_duplicate_content, true)}
  end

  @impl true
  def handle_event("cancel_checking_duplicate_content", _params, socket) do
    # Reset to the saved value from database
    settings = socket.assigns.settings
    saved_value = if settings, do: settings.token_usage_checking_duplicate_content || 0, else: 0

    {:noreply,
     socket
     |> assign(:editing_checking_duplicate_content, false)
     |> assign(:token_usage_checking_duplicate_content, saved_value)}
  end

  @impl true
  def handle_event("save_checking_duplicate_content", %{"token_value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {int_value, ""} when int_value > 0 ->
        case save_or_update_setting(:token_usage_checking_duplicate_content, int_value) do
          {:ok, _updated_settings} ->
            # Reload fresh from database to ensure we have the latest value
            fresh_settings = get_settings()

            new_value =
              if fresh_settings, do: fresh_settings.token_usage_checking_duplicate_content || 0, else: 0

            {:noreply,
             socket
             |> assign(:settings, fresh_settings)
             |> assign(:token_usage_checking_duplicate_content, new_value)
             |> assign(:editing_checking_duplicate_content, false)
             |> put_flash(:info, "Đã cập nhật lượng token sử dụng cho Kiểm tra trùng lặp nội dung")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Token Usage Checking Duplicate Content")}
        end

      _ ->
        {:noreply,
         put_flash(socket, :error, "Token Usage Checking Duplicate Content must be a positive integer")}
    end
  end

  defp get_settings do
    Repo.all(AdminSetting) |> List.first()
  end

  defp save_or_update_setting(field, value) do
    attrs = Map.put(%{}, field, value)

    case get_settings() do
      nil ->
        %AdminSetting{}
        |> AdminSetting.changeset(attrs)
        |> Repo.insert()

      existing_settings ->
        existing_settings
        |> AdminSetting.changeset(attrs)
        |> Repo.update()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold">Quản lý Token Usage</h1>
        <p class="text-neutral-content mt-2">Cấu hình Token Usage Check URL Index</p>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th class="text-lg">Chức năng</th>
              <th class="text-lg text-center">Giá trị</th>
              <th class="text-lg">Hành động</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="font-semibold">
                <div class="flex items-center gap-2">
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
                      d="M13 10V3L4 14h7v7l9-11h-7z"
                    />
                  </svg>
                  Kiểm tra URL Index
                </div>
              </td>
              <td class="text-center">
                <%= if @editing_url_index do %>
                  <form id="token-url-index-form" phx-submit="save_url_index">
                    <input
                      type="number"
                      name="token_value"
                      value={@token_usage_check_url_index}
                      class="input input-bordered w-32"
                      min="1"
                      required
                    />
                  </form>
                <% else %>
                  <span class="font-mono">
                    {@token_usage_check_url_index}
                  </span>
                <% end %>
              </td>
              <td>
                <%= if @editing_url_index do %>
                  <div class="flex gap-2">
                    <button type="submit" form="token-url-index-form" class="btn btn-success btn-sm">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      Lưu
                    </button>
                    <button type="button" phx-click="cancel_url_index" class="btn btn-ghost btn-sm">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
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
                      Hủy
                    </button>
                  </div>
                <% else %>
                  <button type="button" phx-click="edit_url_index" class="btn btn-primary btn-sm">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    Chỉnh sửa
                  </button>
                <% end %>
              </td>
            </tr>
            <tr>
              <td class="font-semibold">
                <div class="flex items-center gap-2">
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
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Kiểm tra Allintitle
                </div>
              </td>
              <td class="text-center">
                <%= if @editing_allintitle do %>
                  <form id="token-allintitle-form" phx-submit="save_allintitle">
                    <input
                      type="number"
                      name="token_value"
                      value={@token_usage_check_allintitle}
                      class="input input-bordered w-32"
                      min="1"
                      required
                    />
                  </form>
                <% else %>
                  <span class="font-mono">
                    {@token_usage_check_allintitle}
                  </span>
                <% end %>
              </td>
              <td>
                <%= if @editing_allintitle do %>
                  <div class="flex gap-2">
                    <button type="submit" form="token-allintitle-form" class="btn btn-success btn-sm">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      Lưu
                    </button>
                    <button type="button" phx-click="cancel_allintitle" class="btn btn-ghost btn-sm">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
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
                      Hủy
                    </button>
                  </div>
                <% else %>
                  <button type="button" phx-click="edit_allintitle" class="btn btn-primary btn-sm">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    Chỉnh sửa
                  </button>
                <% end %>
              </td>
            </tr>
          </tbody>
          <tbody>
            <tr>
              <td class="font-semibold">
                <div class="flex items-center gap-2">
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
                      d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                    />
                  </svg>
                  Kiểm tra thứ hạng từ khóa
                </div>
              </td>
              <td class="text-center">
                <%= if @editing_keyword_ranking do %>
                  <form id="token-keyword-ranking-form" phx-submit="save_keyword_ranking">
                    <input
                      type="number"
                      name="token_value"
                      value={@token_usage_keyword_ranking}
                      class="input input-bordered w-32"
                      min="1"
                      required
                    />
                  </form>
                <% else %>
                  <span class="font-mono">
                    {@token_usage_keyword_ranking}
                  </span>
                <% end %>
              </td>
              <td>
                <%= if @editing_keyword_ranking do %>
                  <div class="flex gap-2">
                    <button
                      type="submit"
                      form="token-keyword-ranking-form"
                      class="btn btn-success btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      Lưu
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_keyword_ranking"
                      class="btn btn-ghost btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
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
                      Hủy
                    </button>
                  </div>
                <% else %>
                  <button
                    type="button"
                    phx-click="edit_keyword_ranking"
                    class="btn btn-primary btn-sm"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    Chỉnh sửa
                  </button>
                <% end %>
              </td>
            </tr>
            <tr>
              <td class="font-semibold">
                <div class="flex items-center gap-2">
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
                      d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                    />
                  </svg>
                  Gom nhóm từ khóa
                </div>
              </td>
              <td class="text-center">
                <%= if @editing_keyword_grouping do %>
                  <form id="token-keyword-grouping-form" phx-submit="save_keyword_grouping">
                    <input
                      type="number"
                      name="token_value"
                      value={@token_usage_keyword_grouping}
                      class="input input-bordered w-32"
                      min="1"
                      required
                    />
                  </form>
                <% else %>
                  <span class="font-mono">
                    {@token_usage_keyword_grouping}
                  </span>
                <% end %>
              </td>
              <td>
                <%= if @editing_keyword_grouping do %>
                  <div class="flex gap-2">
                    <button
                      type="submit"
                      form="token-keyword-grouping-form"
                      class="btn btn-success btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      Lưu
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_keyword_grouping"
                      class="btn btn-ghost btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
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
                      Hủy
                    </button>
                  </div>
                <% else %>
                  <button
                    type="button"
                    phx-click="edit_keyword_grouping"
                    class="btn btn-primary btn-sm"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    Chỉnh sửa
                  </button>
                <% end %>
              </td>
            </tr>
            <tr>
              <td class="font-semibold">
                <div class="flex items-center gap-2">
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
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Kiểm tra trùng lặp nội dung
                </div>
              </td>
              <td class="text-center">
                <%= if @editing_checking_duplicate_content do %>
                  <form id="token-checking-duplicate-content-form" phx-submit="save_checking_duplicate_content">
                    <input
                      type="number"
                      name="token_value"
                      value={@token_usage_checking_duplicate_content}
                      class="input input-bordered w-32"
                      min="1"
                      required
                    />
                  </form>
                <% else %>
                  <span class="font-mono">
                    {@token_usage_checking_duplicate_content}
                  </span>
                <% end %>
              </td>
              <td>
                <%= if @editing_checking_duplicate_content do %>
                  <div class="flex gap-2">
                    <button
                      type="submit"
                      form="token-checking-duplicate-content-form"
                      class="btn btn-success btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      Lưu
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_checking_duplicate_content"
                      class="btn btn-ghost btn-sm"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4"
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
                      Hủy
                    </button>
                  </div>
                <% else %>
                  <button
                    type="button"
                    phx-click="edit_checking_duplicate_content"
                    class="btn btn-primary btn-sm"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    Chỉnh sửa
                  </button>
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
