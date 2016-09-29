defmodule CanvasAPI.Unfurl.Canvas do
  @moduledoc """
  An unfurled canvas, providing summary and progress information.
  """

  @provider_name "Canvas"
  @provider_icon_url(
    "https://s3.amazonaws.com/canvas-assets/provider-icons/canvas.png")
  @provider_url "https://usecanvas.com"

  @canvas_regex Regex.compile!(
    "\\A#{System.get_env("WEB_URL")}/[^/]+/(?<id>[^/]{22})\\z")

  alias CanvasAPI.{Block, Canvas, Repo, Unfurl}
  alias Unfurl.Field

  def unfurl(url, _opts) do
    with id when is_binary(id) <- extract_canvas_id(url),
         canvas = %Canvas{} <- Repo.get(Canvas, id) |> Repo.preload([:team]) do
      %Unfurl{
        id: url,
        title: canvas_title(canvas),
        text: canvas_summary(canvas),
        provider_name: @provider_name,
        provider_icon_url: @provider_icon_url,
        provider_url: @provider_url,
        url: "#{System.get_env("WEB_URL")}/#{canvas.team.domain}/#{id}",
        fields: [
          progress_field(canvas)
        ]
      }
    end
  end

  def canvas_regex, do: @canvas_regex

  defp canvas_summary(canvas) do
    first_content_block =
      canvas.blocks
      |> Enum.at(1)

    case first_content_block do
      %Block{blocks: [block | _]} ->
        block.content
      %Block{content: content} ->
        String.slice(content, 0..140)
      nil ->
        ""
    end
  end

  defp canvas_title(canvas) do
    canvas.blocks
    |> Enum.at(0)
    |> Map.get(:content)
  end

  defp progress_field(canvas) do
    {complete, total} = do_progress_field(canvas.blocks)
    progress = if total > 0, do: (complete / total * 100) |> Float.round(2)
    %Field{title: "progress", value: progress, short: true}
  end

  defp do_progress_field(blocks, progress \\ {0, 0}) do
    blocks
    |> Enum.reduce(progress, fn
      (%Block{blocks: child_blocks}, progress) when length(child_blocks) > 0 ->
        do_progress_field(child_blocks, progress)
      (block = %Block{type: "checklist-item"}, progress) ->
        if block.meta["checked"] do
          {elem(progress, 0) + 1, elem(progress, 1) + 1}
        else
          {elem(progress, 0), elem(progress, 1) + 1}
        end
      (_, progress) ->
        progress
    end)
  end

  defp extract_canvas_id(url) do
    with match when is_map(match) <- Regex.named_captures(@canvas_regex, url) do
      match["id"]
    end
  end
end
