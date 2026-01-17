defmodule CmdStan.ProgressRenderer do
  @moduledoc """
  Renders download progress bars in minimalist ASCII style.

  Format: Downloading cmdstan-2.38.0: [██████████████░░░░░░░░] 67% (34.2MB/51.1MB)
  """

  alias CmdStan.DownloadProgress

  # Fixed width for consistency across terminals
  @bar_width 30

  @doc """
  Render a progress bar for the given download progress.

  Returns a single-line string suitable for terminal output.
  """
  @spec render(DownloadProgress.t()) :: String.t()
  def render(progress) do
    percentage = DownloadProgress.percentage(progress)
    bar = render_bar(percentage)
    sizes = format_sizes(progress)
    filename = extract_filename(progress.filename)

    "Downloading #{filename}: #{bar} #{percentage}% #{sizes}"
  end

  @doc """
  Render just the progress bar portion.
  """
  @spec render_bar(0..100) :: String.t()
  def render_bar(percentage) do
    filled_count = round(@bar_width * percentage / 100)
    empty_count = @bar_width - filled_count

    filled = String.duplicate("█", filled_count)
    empty = String.duplicate("░", empty_count)

    "[#{filled}#{empty}]"
  end

  @doc """
  Format file sizes in human-readable format.
  """
  @spec format_sizes(DownloadProgress.t()) :: String.t()
  def format_sizes(progress) do
    downloaded = format_bytes(progress.downloaded_bytes)
    total = format_bytes(progress.total_bytes)
    "(#{downloaded}/#{total})"
  end

  @doc """
  Format bytes into human-readable units (B, KB, MB).
  """
  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) do
    cond do
      bytes >= 1_000_000 ->
        # Show 1 decimal place for MB
        mb = bytes / 1_000_000
        "#{:erlang.float_to_binary(mb, decimals: 1)}MB"

      bytes >= 1_000 ->
        # Show 1 decimal place for KB
        kb = bytes / 1_000
        "#{:erlang.float_to_binary(kb, decimals: 1)}KB"

      true ->
        # Show exact bytes for small files
        "#{bytes}B"
    end
  end

  @doc """
  Extract and clean filename from URL or path.
  """
  @spec extract_filename(String.t()) :: String.t()
  def extract_filename(url_or_path) do
    # Extract filename from URL/path and remove .tar.gz extension
    url_or_path
    |> String.split("/")
    |> List.last()
    |> String.replace_suffix(".tar.gz", "")
  end
end
