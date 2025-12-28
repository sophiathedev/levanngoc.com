defmodule Levanngoc.KeywordCannibalizationProjects do
  @moduledoc """
  Context module for managing keyword cannibalization projects.
  """

  import Ecto.Query, warn: false
  alias Levanngoc.Repo
  alias Levanngoc.KeywordCannibalizationProject

  @doc """
  Returns the list of projects for a specific user, ordered by most recent first.
  """
  def list_projects(user_id) do
    KeywordCannibalizationProject
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> select([p], %{
      id: p.id,
      name: p.name,
      domain: p.domain,
      status: p.status,
      inserted_at: p.inserted_at,
      error_message: p.error_message,
      # compute keywords count from array column to avoid loading the full array
      keywords_count: fragment("cardinality(?)", p.keywords)
    })
    |> Repo.all()
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the project does not exist or doesn't belong to the user.
  """
  def get_project!(id, user_id) do
    KeywordCannibalizationProject
    |> where([p], p.id == ^id and p.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Checks if a user has a running project.
  """
  def has_running_project?(user_id) do
    KeywordCannibalizationProject
    |> where([p], p.user_id == ^user_id and p.status == "running")
    |> Repo.exists?()
  end

  @doc """
  Gets the currently running project for a user, if any.
  """
  def get_running_project(user_id) do
    KeywordCannibalizationProject
    |> where([p], p.user_id == ^user_id and p.status == "running")
    |> select([p], %{id: p.id, status: p.status})
    |> Repo.one()
  end

  @doc """
  Creates a project.
  """
  def create_project(attrs \\ %{}) do
    %KeywordCannibalizationProject{}
    |> KeywordCannibalizationProject.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.
  """
  def update_project(%KeywordCannibalizationProject{} = project, attrs) do
    project
    |> KeywordCannibalizationProject.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.
  """
  def delete_project(%KeywordCannibalizationProject{} = project) do
    Repo.delete(project)
  end

  @doc """
  Marks a project as running and sets the started_at timestamp.
  """
  def mark_as_running(%KeywordCannibalizationProject{} = project) do
    update_project(project, %{
      status: "running",
      started_at: DateTime.utc_now(),
      completed_at: nil,
      error_message: nil
    })
  end

  @doc """
  Marks a project as completed and stores the crawled data and results.
  """
  def mark_as_completed(
        %KeywordCannibalizationProject{} = project,
        crawled_data,
        cannibalization_results
      ) do
    update_project(project, %{
      status: "completed",
      completed_at: DateTime.utc_now(),
      crawled_data: crawled_data,
      cannibalization_results: cannibalization_results,
      error_message: nil
    })
  end

  @doc """
  Marks a project as failed and stores the error message.
  """
  def mark_as_failed(%KeywordCannibalizationProject{} = project, error_message) do
    update_project(project, %{
      status: "failed",
      completed_at: DateTime.utc_now(),
      error_message: error_message
    })
  end

  @doc """
  Resets a project to pending status, clearing previous results.
  This is used when re-running a project.
  """
  def reset_to_pending(%KeywordCannibalizationProject{} = project) do
    update_project(project, %{
      status: "pending",
      started_at: nil,
      completed_at: nil,
      crawled_data: nil,
      cannibalization_results: nil,
      error_message: nil
    })
  end
end
