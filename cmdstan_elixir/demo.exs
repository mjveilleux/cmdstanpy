#!/usr/bin/env elixir
# Demo script showing CmdStan functionality

IO.puts("=== CmdStan Elixir Demo ===")

# Test data handling
IO.puts("\n1. Testing data handling:")
data = %{"N" => 5, "y" => [1, 0, 1, 1, 0]}
{:ok, json} = CmdStan.Data.to_json(data)
IO.puts("Data: #{inspect(data)}")
IO.puts("JSON: #{json}")

# Test model compilation (will fail without CmdStan installed)
IO.puts("\n2. Testing model compilation:")
IO.puts("CmdStan path: #{inspect(System.get_env("CMDSTAN"))}")

case CmdStan.compile_model("lib/example/bernoulli.stan") do
  {:ok, model} ->
    IO.puts("Model compiled: #{inspect(model)}")

  {:error, reason} ->
    IO.puts("Model compilation failed: #{inspect(reason)}")
end

# Test progress bar display
IO.puts("\n3. Testing progress bar:")
progress = CmdStan.DownloadProgress.new("cmdstan-2.37.0.tar.gz", 47_600_000)
progress = CmdStan.DownloadProgress.update(progress, 23_800_000)
bar = CmdStan.ProgressRenderer.render(progress)
IO.puts(bar)

IO.puts("\n=== Demo Complete ===")
