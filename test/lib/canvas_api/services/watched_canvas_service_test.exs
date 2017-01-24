defmodule CanvasAPI.WatchedCanvasServiceTest do
  use CanvasAPI.ModelCase, async: true

  import CanvasAPI.Factory

  alias CanvasAPI.WatchedCanvasService

  describe ".insert/2" do
    setup do
      {:ok, canvas: insert(:canvas)}
    end

    test "inserts a watched canvas when found", %{canvas: canvas} do
      {:ok, watched_canvas} =
        %{"canvas_id" => canvas.id}
        |> WatchedCanvasService.insert(account: canvas.creator.account)
      assert watched_canvas.canvas_id == canvas.id
    end

    test "returns a changeset when invalid", %{canvas: canvas} do
      assert {:error, _changeset} =
        %{"canvas_id" => canvas.id}
        |> WatchedCanvasService.insert(account: insert(:account))
    end
  end

  describe ".delete/2" do
    test "deletes a watched canvas" do
      watch = insert(:watched_canvas)
      {:ok, _} =
        WatchedCanvasService.delete(watch.canvas_id,
                                    account: watch.user.account)
      refute Repo.reload(watch)
    end

    test "returns an error when not found" do
      assert {:error, :watch_not_found} =
        WatchedCanvasService.delete(insert(:watched_canvas).id,
                                    account: insert(:account))
    end
  end
end
