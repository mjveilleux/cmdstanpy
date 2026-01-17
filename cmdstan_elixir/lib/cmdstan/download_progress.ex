defmodule CmdStan.DownloadProgress do
  @moduledoc """
  Tracks download progress for progress bar rendering.

  Maintains state about bytes downloaded, total size, timing,
  and throttles updates to avoid spam.
  """

  @type t :: %__MODULE__{
          filename: String.t(),
          total_bytes: non_neg_integer(),
          downloaded_bytes: non_neg_integer(),
          start_time: integer(),
          last_render_time: integer()
        }

  @enforce_keys [:filename, :total_bytes]
  defstruct [
    :filename,
    :total_bytes,
    :downloaded_bytes,
    :start_time,
    :last_render_time
  ]

  # Update progress bar every 150ms
  @update_interval_ms 150

  @doc """
  Create a new progress tracker.

  ## Parameters
  - `filename`: The name of the file being downloaded
  - `total_bytes`: Total size in bytes (0 if unknown)
  """
  @spec new(String.t(), non_neg_integer()) :: t()
  def new(filename, total_bytes) do
    now = System.monotonic_time(:millisecond)

    %__MODULE__{
      filename: filename,
      total_bytes: total_bytes,
      downloaded_bytes: 0,
      start_time: now,
      # Force initial render
      last_render_time: 0
    }
  end

  @doc """
  Check if enough time has passed to update the progress bar.
  """
  @spec should_update?(t()) :: boolean()
  def should_update?(progress) do
    now = System.monotonic_time(:millisecond)
    now - progress.last_render_time >= @update_interval_ms
  end

  @doc """
  Update progress with newly received bytes.
  """
  @spec update(t(), non_neg_integer()) :: t()
  def update(progress, bytes_received) do
    now = System.monotonic_time(:millisecond)

    %{
      progress
      | downloaded_bytes: progress.downloaded_bytes + bytes_received,
        last_render_time: now
    }
  end

  @doc """
  Get the completion percentage (0-100).
  """
  @spec percentage(t()) :: 0..100
  def percentage(%{total_bytes: 0}), do: 0

  def percentage(%{total_bytes: total, downloaded_bytes: downloaded}) do
    if total > 0 do
      min(round(downloaded / total * 100), 100)
    else
      0
    end
  end
end
