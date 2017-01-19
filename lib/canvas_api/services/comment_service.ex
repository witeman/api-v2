defmodule CanvasAPI.CommentService do
  @moduledoc """
  A service for viewing and manipulating comments.
  """

  alias CanvasAPI.{Account, Canvas, CanvasService, Comment, CommentView,
                   Endpoint, Repo, Team, User}
  use CanvasAPI.Web, :service

  @preload [:canvas]

  @doc """
  Create a new comment on a given block and block.
  """
  @spec create(map, Keyword.t) :: {:ok, Comment.t} | {:error, Ecto.Changeset.t}
  def create(attrs, opts) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> put_canvas(iget(attrs, :canvas_id), opts[:account])
    |> put_block(iget(attrs, :block_id))
    |> put_creator(opts[:account])
    |> Repo.insert
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, @preload)
        notify_new_comment(comment)
        {:ok, comment}
      error ->
        error
    end
  end

  @spec notify_new_comment(Comment.t) :: any
  defp notify_new_comment(comment) do
    Endpoint.broadcast("canvas:#{comment.canvas_id}", "new_comment",
                       CommentView.render("show.json", %{comment: comment}))
  end

  @spec put_block(Ecto.Changeset.t, String.t | nil) :: Ecto.Changeset.t
  defp put_block(changeset = %{valid?: true}, id) when is_binary(id) do
    with canvas = get_change(changeset, :canvas).data,
         block when not is_nil(block) <- Canvas.find_block(canvas, id) do
        changeset
        |> put_change(:block_id, block.id)
    else
      _ ->
        changeset
        |> add_error(:block, "was not found")
    end
  end

  defp put_block(changeset, nil) do
    changeset
    |> add_error(:block, "is required")
  end

  defp put_block(changeset, _), do: changeset

  @spec put_canvas(Ecto.Changeset.t, String.t | nil, Account.t)
        :: Ecto.Changeset.t
  defp put_canvas(changeset, id, account) when is_binary(id) do
    id
    |> CanvasService.get(account: account)
    |> case do
      {:ok, canvas} ->
        changeset |> put_assoc(:canvas, canvas)
      {:error, _} ->
        changeset |> add_error(:canvas, "was not found")
    end
  end

  defp put_canvas(changeset, _, _),
    do: changeset |> add_error(:canvas, "is required")

  @spec put_creator(Ecto.Changeset.t, Account.t) :: Ecto.Changeset.t
  defp put_creator(changeset = %{valid?: true}, account) do
    canvas = get_change(changeset, :canvas).data
    user =
      account
      |> assoc(:users)
      |> from(where: [team_id: ^canvas.team_id])
      |> Repo.one
    put_assoc(changeset, :creator, user)
  end

  defp put_creator(changeset, _), do: changeset

  @doc """
  Retrieve a single comment by ID.
  """
  @spec get(String.t, Keyword.t) :: {:ok, Comment.t}
                                  | {:error, :comment_not_found}
  def get(id, opts) do
    opts[:account].id
    |> comment_query
    |> maybe_lock
    |> where(id: ^id)
    |> Repo.one
    |> case do
      comment = %Comment{} ->
        {:ok, comment}
      nil ->
        {:error, :comment_not_found}
    end
  end

  @spec maybe_lock(Ecto.Query.t) :: Ecto.Query.t
  defp maybe_lock(query) do
    if Repo.in_transaction? do
      lock(query, "FOR UPDATE")
    else
      query
    end
  end

  @doc """
  List comments.
  """
  @spec list(Keyword.t) :: [Comment.t]
  def list(opts) do
    opts[:account].id
    |> comment_query
    |> filter(opts[:filter])
    |> Repo.all
  end

  @spec filter(Ecto.Query.t, map | nil) :: Ecto.Query.t
  defp filter(query, filter) when is_map(filter) do
    filter
    |> Enum.reduce(query, &do_filter/2)
  end

  defp filter(query, _), do: query

  @spec do_filter({String.t, String.t}, Ecto.Query.t) :: Ecto.Query.t
  defp do_filter({"canvas.id", canvas_id}, query),
    do: where(query, canvas_id: ^canvas_id)
  defp do_filter({"block.id", block_id}, query),
    do: where(query, block_id: ^block_id)
  defp do_filter(_, query), do: query

  @doc """
  Update a comment.
  """
  @spec update(String.t | Comment.t, map, Keyword.t)
        :: {:ok, Comment.t} | {:error, Ecto.Changeset.t | :comment_not_found}
  def update(id, attrs, opts \\ [])

  def update(id, attrs, opts) when is_binary(id) do
    Repo.transaction fn ->
      with {:ok, comment} <- get(id, opts) do
        __MODULE__.update(comment, attrs, opts)
      end
      |> case do
        {:ok, comment} -> comment
        {:error, error} -> Repo.rollback(error)
      end
    end
  end

  def update(comment, attrs, _opts) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update
    |> case do
      {:ok, comment} ->
        notify_updated_comment(comment)
        {:ok, comment}
      error -> error
    end
  end

  @spec notify_updated_comment(Comment.t) :: any
  defp notify_updated_comment(comment) do
    Endpoint.broadcast("canvas:#{comment.canvas_id}", "updated_comment",
                       CommentView.render("show.json", %{comment: comment}))
  end

  @doc """
  Delete a comment.
  """
  @spec delete(String.t | Comment.t, Keyword.t) :: {:ok, Comment.t}
                                                 | {:error, :comment_not_found}
  def delete(id, opts \\ [])

  def delete(id, opts) when is_binary(id) do
    Repo.transaction fn ->
      with {:ok, comment} <- get(id, opts) do
        __MODULE__.delete(comment, opts)
      end
      |> case do
        {:ok, comment} -> comment
        {:error, error} -> Repo.rollback(error)
      end
    end
  end

  def delete(comment, _opts) do
    comment
    |> Repo.delete
    |> case do
      {:ok, comment} ->
        notify_deleted_comment(comment)
        {:ok, comment}
      error -> error
    end
  end

  @spec notify_deleted_comment(Comment.t) :: any
  defp notify_deleted_comment(comment) do
    Endpoint.broadcast("canvas:#{comment.canvas_id}", "deleted_comment",
                       CommentView.render("show.json", %{comment: comment}))
  end

  @spec comment_query(String.t) :: Ecto.Query.t
  defp comment_query(account_id) do
    Comment
    |> join(:left, [co], ca in Canvas, co.canvas_id == ca.id)
    |> join(:left, [..., ca], t in Team, ca.team_id == t.id)
    |> join(:left, [..., t], u in User, u.team_id == t.id)
    |> where([..., u], u.account_id == ^account_id)
    |> preload(^@preload)
  end

  @spec iget(map, atom) :: any
  defp iget(map, key) do
    if Map.has_key?(map, key) do
      map[key]
    else
      map[to_string(key)]
    end
  end
end
