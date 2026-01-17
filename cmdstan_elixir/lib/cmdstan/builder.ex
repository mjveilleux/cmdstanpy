defmodule CmdStan.Builder do
  @moduledoc """
  Handles building and testing CmdStan installations.

  Provides functionality to compile CmdStan, run make commands,
  and test the compilation with example models.
  """

  alias CmdStan.Platform
  require Logger

  @doc """
  Build CmdStan from source.

  Changes to the CmdStan directory and runs make with the specified number of cores.

  ## Examples

      iex> config = %CmdStan.Config{cores: 4, verbose: true}
      iex> CmdStan.Builder.build_cmdstan("cmdstan-2.32.2", config)
      :ok

  """
  @spec build_cmdstan(String.t(), CmdStan.Config.t()) :: :ok | {:error, term()}
  def build_cmdstan(cmdstan_dir, config) do
    Logger.info("Building CmdStan in #{cmdstan_dir}")

    # Change to CmdStan directory
    original_cwd = File.cwd!()
    File.cd!(cmdstan_dir)

    try do
      # Build with make
      make_cmd = Platform.make_command()
      args = build_make_args(config)

      Logger.info("Running: #{make_cmd} #{Enum.join(args, " ")}")

      case run_command(make_cmd, args, config.verbose) do
        :ok ->
          Logger.info("CmdStan build successful")
          :ok

        {:error, reason} ->
          Logger.error("CmdStan build failed: #{inspect(reason)}")
          {:error, {:build_failed, reason}}
      end
    after
      File.cd!(original_cwd)
    end
  end

  @doc """
  Test CmdStan compilation with the bernoulli example.

  ## Examples

      iex> config = %CmdStan.Config{verbose: true}
      iex> CmdStan.Builder.test_compilation("cmdstan-2.32.2", config)
      :ok

  """
  @spec test_compilation(String.t(), CmdStan.Config.t()) :: :ok | {:error, term()}
  def test_compilation(cmdstan_dir, config) do
    Logger.info("Testing CmdStan compilation with bernoulli example")

    original_cwd = File.cwd!()

    try do
      File.cd!(cmdstan_dir)

      # Remove existing executable if it exists
      exe_path = Path.join(["examples", "bernoulli", "bernoulli#{Platform.extension()}"])

      if File.exists?(exe_path) do
        File.rm!(exe_path)
      end

      # Run make on bernoulli example from CmdStan root directory
      make_cmd = Platform.make_command()
      target = Path.join(["examples", "bernoulli", "bernoulli"])

      case run_command(make_cmd, [target], config.verbose) do
        :ok ->
          # Check if executable was created
          if File.exists?(exe_path) do
            Logger.info("Test compilation successful")
            :ok
          else
            {:error, {:executable_not_found, exe_path}}
          end

        {:error, reason} ->
          Logger.error("Test compilation failed: #{inspect(reason)}")
          {:error, {:test_compilation_failed, reason}}
      end
    after
      File.cd!(original_cwd)
    end
  end

  @doc """
  Clean CmdStan build artifacts.

  ## Examples

      iex> CmdStan.Builder.clean_cmdstan("cmdstan-2.32.2", true)
      :ok

  """
  @spec clean_cmdstan(String.t(), boolean()) :: :ok | {:error, term()}
  def clean_cmdstan(cmdstan_dir, verbose \\ false) do
    Logger.info("Cleaning CmdStan build in #{cmdstan_dir}")

    original_cwd = File.cwd!()
    File.cd!(cmdstan_dir)

    try do
      make_cmd = Platform.make_command()
      run_command(make_cmd, ["clean-all"], verbose)
    after
      File.cd!(original_cwd)
    end
  end

  # Private functions

  defp build_make_args(config) do
    args = []

    # Add cores if more than 1
    if config.cores > 1 do
      args = ["-j#{config.cores}" | args]
    end

    # Add other make targets if needed
    args
  end

  defp run_command(cmd, args, verbose) do
    opts = [
      stderr_to_stdout: true,
      into: if(verbose, do: IO.stream(), else: "")
    ]

    case System.cmd(cmd, args, opts) do
      {output, 0} ->
        :ok

      {output, exit_code} ->
        {:error, %{exit_code: exit_code, output: output}}
    end
  end
end
