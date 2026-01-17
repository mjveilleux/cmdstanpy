defmodule CmdStan do
  @moduledoc """
  Elixir interface to CmdStan.

  This library provides functionality to download, install, and manage
  CmdStan releases from GitHub, similar to the Python CmdStanPy library.
  """

  alias CmdStan.{Installer, Model, Summary}

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

  @doc """
  Compile a Stan model file to an executable.

  ## Parameters
  - `stan_file`: Path to the Stan model file (.stan)

  ## Returns
  A map containing model information or an error tuple.

  ## Examples

      iex> CmdStan.compile_model("model.stan")
      {:ok, %{name: "model", stan_file: "model.stan", exe_file: "model"}}

  """
  @spec compile_model(String.t()) :: {:ok, map()} | {:error, term()}
  def compile_model(stan_file) do
    Model.compile(stan_file)
  end

  @doc """
  Run MCMC sampling on a compiled model.

  ## Parameters
  - `model`: Model map returned by `compile_model/1`
  - `data`: Data map in Stan format
  - `opts`: Sampling options (chains, iterations, etc.)

  ## Returns
  A result map containing draws, metadata, and diagnostics.

  ## Examples

      iex> model = %{exe_file: "bernoulli"}
      iex> data = %{"N" => 10, "y" => [0,1,0,0,0,0,0,0,0,1]}
      iex> CmdStan.sample(model, data, chains: 1, iter: 100)
      {:ok, %{draws: %{"theta" => [0.2, 0.3, ...]}, metadata: %{...}, diagnostics: %{...}}}

  """
  @spec sample(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def sample(model, data, opts \\ []) do
    Model.sample(model, data, opts)
  end

  @doc """
  Compute summary statistics for MCMC fit results.

  ## Parameters
  - `fit`: Fit result from `sample/3`
  - `opts`: Summary options (percentiles, significant figures)

  ## Returns
  A list of maps containing summary statistics for each variable.

  ## Examples

      iex> fit = CmdStan.sample(model, data, chains: 4, iter: 1000)
      iex> {:ok, summary} = CmdStan.summary(fit)
      iex> Enum.find(summary, &(&1.variable == "theta"))

  """
  @spec summary(map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def summary(fit, opts \\ []) do
    Summary.summary(fit, opts)
  end
end
