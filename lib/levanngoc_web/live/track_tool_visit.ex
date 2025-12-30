defmodule LevanngocWeb.TrackToolVisit do
  @moduledoc """
  Helper module to track tool visits for each user using Cachex.
  Each tool LiveView should call `track_visit/3` in their mount function.
  """

  # Map of route paths to tool information
  @tool_info %{
    "/check-keyword-ranking" => %{
      name: "Kiểm tra thứ hạng từ khóa",
      icon: "hero-chart-bar"
    },
    "/check-all-in-title" => %{
      name: "Kiểm tra AllInTitle",
      icon: "hero-document-magnifying-glass"
    },
    "/keyword-grouping" => %{
      name: "Gom nhóm từ khóa",
      icon: "hero-squares-2x2"
    },
    "/check-keyword-cannibalization" => %{
      name: "Kiểm tra Keyword Cannibalization",
      icon: "hero-document-duplicate"
    },
    "/check-duplicate-content" => %{
      name: "Kiểm tra nội dung trùng lặp",
      icon: "hero-document-check"
    },
    "/check-url-index" => %{
      name: "Kiểm tra URL Index",
      icon: "hero-globe-alt"
    },
    "/schema-generator" => %{
      name: "Tạo Schema Markup",
      icon: "hero-code-bracket"
    },
    "/backlink-checker" => %{
      name: "Kiểm tra Backlink",
      icon: "hero-link"
    },
    "/redirect-checker" => %{
      name: "Kiểm tra Redirect",
      icon: "hero-arrow-path"
    },
    "/image-compression" => %{
      name: "Nén hình ảnh",
      icon: "hero-photo"
    },
    "/geo-tag" => %{
      name: "Thêm Geo Tag",
      icon: "hero-map-pin"
    },
    "/gmail-alias" => %{
      name: "Gmail Alias Generator",
      icon: "hero-envelope"
    },
    "/robots-generator" => %{
      name: "Robots.txt Generator",
      icon: "hero-cog-6-tooth"
    },
    "/free-tools" => %{
      name: "Công cụ tiện ích",
      icon: "hero-wrench-screwdriver"
    }
  }

  @max_recent_tools 6

  @doc """
  Track a tool visit for the current user.
  Call this in the mount function of each tool LiveView.

  ## Example
      def mount(_params, _session, socket) do
        socket = TrackToolVisit.track_visit(socket, "/check-keyword-ranking")
        {:ok, socket}
      end
  """
  def track_visit(socket, path) do
    # Only track if user is logged in and socket is connected
    if Phoenix.LiveView.connected?(socket) do
      case socket.assigns[:current_scope] do
        %{user: %{id: user_id}} ->
          do_track(user_id, path)

        _ ->
          :ok
      end
    end

    socket
  end

  defp do_track(user_id, path) do
    # Check if this is a tool page we want to track
    case Map.get(@tool_info, path) do
      nil ->
        # Not a tool page, don't track
        :ok

      tool_info ->
        # Track this tool visit
        cache_key = "recent_tools:#{user_id}"

        # Get current recent tools or empty list
        recent_tools =
          case Cachex.get(:cache, cache_key) do
            {:ok, nil} -> []
            {:ok, tools} -> tools
            _ -> []
          end

        # Create new tool entry
        new_tool = Map.put(tool_info, :path, path)

        # Remove this tool if it already exists (to avoid duplicates)
        recent_tools = Enum.reject(recent_tools, fn tool -> tool.path == path end)

        # Prepend the new tool to the front
        recent_tools = [new_tool | recent_tools]

        # Keep only the most recent 6 tools
        recent_tools = Enum.take(recent_tools, @max_recent_tools)

        # Store back in cache with 3 days expiration
        # 3 days = 72 hours
        Cachex.put(:cache, cache_key, recent_tools, ttl: :timer.hours(72))

        :ok
    end
  end
end
