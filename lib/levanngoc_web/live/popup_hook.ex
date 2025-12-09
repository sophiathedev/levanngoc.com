defmodule LevanngocWeb.PopupHook do
  @moduledoc """
  LiveView hook for handling popup display logic.
  """
  alias Levanngoc.Repo
  alias Levanngoc.Popup
  alias Levanngoc.PopupSeen
  import Phoenix.LiveView
  import Phoenix.Component

  import Ecto.Query, warn: false

  def on_mount(:default, _params, _session, socket) do
    current_user =
      case socket.assigns[:current_scope] do
        %{user: user} when not is_nil(user) -> user
        _ -> nil
      end

    socket =
      if current_user do
        handling_popup_for_logged_user(socket)
      else
        # For anonymous users, get anonymous_id from connection params
        anonymous_id = get_in(socket.private, [:connect_params, "popup_anonymous_id"])

        if anonymous_id && anonymous_id != "" do
          handling_popup_for_anonymous_user(socket, anonymous_id)
        else
          socket
          |> assign(:current_popup, nil)
          |> assign(:remaining_popups, [])
          |> assign(:anonymous_popup_tracker, nil)
        end
      end

    # Attach event handler for close_popup
    socket = attach_hook(socket, :popup_close_handler, :handle_event, &handle_popup_event/3)

    {:cont, socket}
  end

  # Handle popups for anonymous users with persistent ID
  defp handling_popup_for_anonymous_user(socket, anonymous_id) do
    {:ok, visiting_site_popup} = Cachex.get(:popup_cache, "visiting_site")

    visiting_site_popup =
      if visiting_site_popup == nil or length(visiting_site_popup) == 0 do
        popups =
          from(Popup)
          |> where([p], p.trigger_when == 0 and p.status >= 1)
          |> order_by([p], desc: p.inserted_at)
          |> Repo.all()

        Cachex.put(:popup_cache, "visiting_site", popups)
        popups
      else
        visiting_site_popup
      end

    # Get seen popup IDs from Cachex
    {:ok, seen_popup_ids} = Cachex.get(:cache, "popup_seen:#{anonymous_id}")
    seen_popup_ids = seen_popup_ids || []

    unseen_popups =
      visiting_site_popup
      |> Enum.filter(&(&1.status == 2))
      |> Enum.reject(&(&1.id in seen_popup_ids))

    # Assign the first unseen popup to socket
    current_popup = List.first(unseen_popups)
    remaining_popups = if current_popup, do: Enum.drop(unseen_popups, 1), else: []

    socket
    |> assign(:current_popup, current_popup)
    |> assign(:remaining_popups, remaining_popups)
    |> assign(:anonymous_popup_tracker, anonymous_id)
  end

  # Handle the close_popup event
  defp handle_popup_event("close_popup", %{"popup-id" => popup_id}, socket) do
    # Get current user from current_scope (which is a struct)
    current_user =
      case socket.assigns[:current_scope] do
        %{user: user} when not is_nil(user) -> user
        _ -> nil
      end

    if current_user do
      # Logged-in user: Save to database
      PopupSeen.mark_popup_as_seen(popup_id, current_user.id)
    else
      # Anonymous user: Store in Cachex with 6-hour expiration
      anonymous_id = socket.assigns[:anonymous_popup_tracker]

      if anonymous_id do
        update_anonymous_seen_popups(anonymous_id, popup_id)
      end
    end

    # Get next popup from remaining_popups
    remaining_popups = socket.assigns[:remaining_popups] || []
    next_popup = List.first(remaining_popups)
    new_remaining = if next_popup, do: Enum.drop(remaining_popups, 1), else: []

    {:halt,
     socket
     |> assign(:current_popup, next_popup)
     |> assign(:remaining_popups, new_remaining)}
  end

  # Pass through other events
  defp handle_popup_event(_event, _params, socket), do: {:cont, socket}

  defp handling_popup_for_logged_user(socket) do
    current_user = socket.assigns.current_scope.user
    {:ok, visiting_site_popup} = Cachex.get(:popup_cache, "visiting_site")

    visiting_site_popup =
      if visiting_site_popup == nil or length(visiting_site_popup) == 0 do
        popups =
          from(Popup)
          |> where([p], p.trigger_when == 0 and p.status >= 1)
          |> order_by([p], desc: p.inserted_at)
          |> Repo.all()

        Cachex.put(:popup_cache, "visiting_site", popups)

        popups
      else
        visiting_site_popup
      end

    unseen_popups =
      if current_user do
        popup_ids = Enum.map(visiting_site_popup, & &1.id)

        seen_popup_ids =
          from(PopupSeen)
          |> where([ps], ps.user_id == ^current_user.id and ps.popup_id in ^popup_ids)
          |> select([ps], ps.popup_id)
          |> Repo.all()

        Enum.reject(visiting_site_popup, fn popup ->
          popup.id in seen_popup_ids
        end)
      else
        visiting_site_popup
      end

    # Assign the first unseen popup to socket
    current_popup = List.first(unseen_popups)
    remaining_popups = if current_popup, do: Enum.drop(unseen_popups, 1), else: []

    socket
    |> assign(:current_popup, current_popup)
    |> assign(:remaining_popups, remaining_popups)
  end

  # Update seen popup IDs in Cachex for anonymous users
  defp update_anonymous_seen_popups(anonymous_id, popup_id) do
    cache_key = "popup_seen:#{anonymous_id}"
    {:ok, seen_ids} = Cachex.get(:cache, cache_key)
    seen_ids = seen_ids || []

    # Add new popup_id to the list
    updated_ids = [popup_id | seen_ids] |> Enum.uniq()

    # Store in cache with 6-hour expiration
    Cachex.put(:cache, cache_key, updated_ids, expire: :timer.hours(6))
  end
end
