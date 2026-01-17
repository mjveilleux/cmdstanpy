#!/usr/bin/env elixir

# Simple test script to demonstrate the progress bar

# Import our modules
alias CmdStan.{DownloadProgress, ProgressRenderer}

# Test the progress bar rendering
IO.puts("Testing progress bar rendering:")

# Test different progress states
test_cases = [
  {0, 50_000_000, "cmdstan-2.38.0.tar.gz"},
  {12_500_000, 50_000_000, "cmdstan-2.38.0.tar.gz"},
  {25_000_000, 50_000_000, "cmdstan-2.38.0.tar.gz"},
  {37_500_000, 50_000_000, "cmdstan-2.38.0.tar.gz"},
  {50_000_000, 50_000_000, "cmdstan-2.38.0.tar.gz"}
]

Enum.each(test_cases, fn {downloaded, total, filename} ->
  progress = %DownloadProgress{
    filename: filename,
    total_bytes: total,
    downloaded_bytes: downloaded,
    start_time: System.monotonic_time(:millisecond),
    last_render_time: System.monotonic_time(:millisecond)
  }

  bar = ProgressRenderer.render(progress)
  IO.puts(bar)
end)

IO.puts("\nProgress bar rendering test complete!")
