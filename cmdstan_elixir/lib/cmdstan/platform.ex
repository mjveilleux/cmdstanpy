defmodule CmdStan.Platform do
  @moduledoc """
  Cross-platform utilities for CmdStan operations.

  Provides platform detection, file extensions, and system-specific operations.
  """

  @type os_type :: :linux | :macos | :windows | :unknown

  @doc """
  Detect the current operating system.

  ## Examples

      iex> CmdStan.Platform.os()
      :linux
      # or :macos, :windows, :unknown

  """
  @spec os() :: os_type()
  def os do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :linux
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  @doc """
  Get the executable file extension for the current platform.

  ## Examples

      iex> CmdStan.Platform.extension()
      ""  # on Unix-like systems

      # On Windows:
      # ".exe"

  """
  @spec extension() :: String.t()
  def extension do
    case os() do
      :windows -> ".exe"
      _ -> ""
    end
  end

  @doc """
  Get the make command for the current platform.

  ## Examples

      iex> CmdStan.Platform.make_command()
      "make"  # on Unix-like systems

      # On Windows:
      # "mingw32-make"

  """
  @spec make_command() :: String.t()
  def make_command do
    case os() do
      :windows -> "mingw32-make"
      _ -> "make"
    end
  end

  @doc """
  Validate that a directory exists and is writable.

  Creates the directory if it doesn't exist. Raises an error if it's not writable.

  ## Examples

      iex> CmdStan.Platform.validate_dir("/tmp/cmdstan")
      :ok

      iex> CmdStan.Platform.validate_dir("/nonexistent/path")
      :ok  # creates the directory

      iex> CmdStan.Platform.validate_dir("/root/protected")
      ** (RuntimeError) Cannot write to directory /root/protected: eacces

  """
  @spec validate_dir(String.t()) :: :ok | no_return()
  def validate_dir(dir) do
    # Create directory if it doesn't exist
    unless File.exists?(dir) do
      case File.mkdir_p(dir) do
        :ok ->
          :ok

        {:error, reason} ->
          raise "Cannot create directory #{dir}: #{reason}"
      end
    end

    # Check if it's actually a directory
    unless File.dir?(dir) do
      raise "Path exists but is not a directory: #{dir}"
    end

    # Test write permissions
    test_file = Path.join(dir, ".cmdstan_write_test")

    case File.write(test_file, "test") do
      :ok ->
        File.rm!(test_file)
        :ok

      {:error, reason} ->
        raise "Cannot write to directory #{dir}: #{reason}"
    end
  end

  @doc """
  Determine the Linux architecture for downloading the correct CmdStan binary.

  Returns the architecture string or nil for universal binaries.
  """
  @spec linux_arch() :: String.t() | nil
  def linux_arch do
    case os() do
      :linux ->
        machine = :erlang.system_info(:system_architecture) |> to_string()

        cond do
          String.contains?(machine, "aarch64") ->
            "arm64"

          String.contains?(machine, "armv7") ->
            "armhf"

          String.contains?(machine, "ppc64el") or String.contains?(machine, "ppc64le") ->
            "ppc64el"

          String.contains?(machine, "s390x") ->
            "s390x"

          true ->
            nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Get the CPU architecture string for CmdStan downloads.
  """
  @spec arch_string() :: String.t() | nil
  def arch_string do
    case os() do
      :linux -> linux_arch()
      _ -> nil
    end
  end

  @doc """
  Get environment variable for overriding the architecture.
  """
  @spec env_arch() :: String.t() | nil
  def env_arch do
    case System.get_env("CMDSTAN_ARCH") do
      nil -> nil
      "false" -> nil
      arch -> arch
    end
  end

  @doc """
  Get the final architecture string to use for downloads.
  """
  @spec final_arch() :: String.t() | nil
  def final_arch do
    env_arch() || arch_string()
  end
end
