defmodule Levanngoc.KeywordCheckings do
  @moduledoc """
  The KeywordCheckings context.
  """

  import Ecto.Query, warn: false
  alias Levanngoc.Repo
  alias Levanngoc.KeywordChecking

  @doc """
  Returns the list of keyword_checkings for a specific user.

  ## Examples

      iex> list_keyword_checkings(user_id)
      [%KeywordChecking{}, ...]

  """
  def list_keyword_checkings(user_id) do
    KeywordChecking
    |> where([k], k.user_id == ^user_id)
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns paginated keyword_checkings for a specific user.

  ## Examples

      iex> list_keyword_checkings_paginated(user_id, page: 1, per_page: 10)
      %{entries: [...], page: 1, per_page: 10, total_entries: 50, total_pages: 5}

  """
  def list_keyword_checkings_paginated(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    query =
      KeywordChecking
      |> where([k], k.user_id == ^user_id)
      |> order_by([k], desc: k.inserted_at)

    total_entries = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_entries / per_page)

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  @doc """
  Gets a single keyword_checking.

  Raises `Ecto.NoResultsError` if the Keyword checking does not exist.

  ## Examples

      iex> get_keyword_checking!(id)
      %KeywordChecking{}

      iex> get_keyword_checking!(456)
      ** (Ecto.NoResultsError)

  """
  def get_keyword_checking!(id), do: Repo.get!(KeywordChecking, id)

  @doc """
  Creates a keyword_checking.

  ## Examples

      iex> create_keyword_checking(%{field: value})
      {:ok, %KeywordChecking{}}

      iex> create_keyword_checking(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_keyword_checking(attrs \\ %{}) do
    %KeywordChecking{}
    |> KeywordChecking.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a keyword_checking.

  ## Examples

      iex> update_keyword_checking(keyword_checking, %{field: new_value})
      {:ok, %KeywordChecking{}}

      iex> update_keyword_checking(keyword_checking, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_keyword_checking(%KeywordChecking{} = keyword_checking, attrs) do
    keyword_checking
    |> KeywordChecking.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a keyword_checking.

  ## Examples

      iex> delete_keyword_checking(keyword_checking)
      {:ok, %KeywordChecking{}}

      iex> delete_keyword_checking(keyword_checking)
      {:error, %Ecto.Changeset{}}

  """
  def delete_keyword_checking(%KeywordChecking{} = keyword_checking) do
    Repo.delete(keyword_checking)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking keyword_checking changes.

  ## Examples

      iex> change_keyword_checking(keyword_checking)
      %Ecto.Changeset{data: %KeywordChecking{}}

  """
  def change_keyword_checking(%KeywordChecking{} = keyword_checking, attrs \\ %{}) do
    KeywordChecking.changeset(keyword_checking, attrs)
  end
end
