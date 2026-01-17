defmodule CmdStan do
  @moduledoc """
  Elixir interface to CmdStan.

  This library provides functionality to download, install, and manage
  CmdStan releases from GitHub.
  """

  alias CmdStan.Installer

  @doc """
  Install CmdStan from GitHub releases.

  Downloads and installs a CmdStan release, builds it, and tests the compilation.

  ## Options

    * `:version` - CmdStan version string (e.g., "2.32.2"). Defaults to latest.
    * `:dir` - Installation directory. Defaults to `~/.cmdstan`.
    * `:overwrite` - Boolean, whether to overwrite existing installation. Defaults to false.
    * `:progress` - Boolean, whether to show progress bars. Defaults to false.
    * `:verbose` - Boolean, whether to show verbose output. Defaults to false.
    * `:cores` - Number of CPU cores to use for building. Defaults to number of schedulers.
    * `:interactive` - Boolean, whether to run in interactive mode. Defaults to false.

  ## Examples

      iex> CmdStan.install_cmdstan(version: "2.32.2")
      :ok

      iex> CmdStan.install_cmdstan(dir: "/opt/cmdstan", progress: true)
      :ok

  """
  @spec install_cmdstan(keyword()) :: :ok | {:error, term()}
  def install_cmdstan(opts \\ []) do
    Installer.install_cmdstan(opts)
  end
end
