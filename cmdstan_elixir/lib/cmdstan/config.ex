defmodule CmdStan.Config do
  @moduledoc """
  Configuration for CmdStan installation.

  Handles configuration from environment variables, config files, and runtime options.
  """

  defstruct [
    :version,
    :dir,
    :overwrite,
    :progress,
    :verbose,
    :cores,
    :interactive,
    :github_token,
    :progress_width
  ]

  @type t :: %__MODULE__{
          version: String.t() | nil,
          dir: String.t(),
          overwrite: boolean(),
          progress: boolean(),
          verbose: boolean(),
          cores: pos_integer(),
          interactive: boolean(),
          github_token: String.t() | nil,
          progress_width: pos_integer()
        }

  @doc """
  Create a new configuration struct.

  Merges configuration from environment variables, config files, and runtime options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    # Load from environment variables
    env_config = load_env_config()

    # Load from config file if exists
    file_config = load_file_config()

    # Merge configurations (opts take precedence)
    config = Map.merge(env_config, file_config)
    config = Map.merge(config, Enum.into(opts, %{}))

    # Create struct with defaults
    %__MODULE__{
      version: config[:version],
      dir: config[:dir] || default_install_dir(),
      overwrite: config[:overwrite] || false,
      progress: config[:progress] || false,
      verbose: config[:verbose] || false,
      cores: config[:cores] || System.schedulers_online(),
      interactive: config[:interactive] || false,
      github_token: config[:github_token] || System.get_env("GITHUB_TOKEN"),
      progress_width: config[:progress_width] || 30
    }
  end

  @doc """
  Get the default installation directory.
  """
  @spec default_install_dir() :: String.t()
  def default_install_dir do
    Path.expand("~/.cmdstan")
  end

  @doc """
  Load configuration from environment variables.
  """
  @spec load_env_config() :: map()
  def load_env_config do
    %{
      version: System.get_env("CMDSTAN_VERSION"),
      dir: System.get_env("CMDSTAN_DIR"),
      overwrite: parse_bool_env("CMDSTAN_OVERWRITE"),
      progress: parse_bool_env("CMDSTAN_PROGRESS"),
      verbose: parse_bool_env("CMDSTAN_VERBOSE"),
      cores: parse_int_env("CMDSTAN_CORES"),
      github_token: System.get_env("GITHUB_TOKEN"),
      progress_width: parse_int_env("CMDSTAN_PROGRESS_WIDTH")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Load configuration from TOML config file.
  """
  @spec load_file_config() :: map()
  def load_file_config do
    config_paths = [
      Path.expand("~/.cmdstan.toml"),
      Path.expand("~/.config/cmdstan/config.toml"),
      "cmdstan.toml"
    ]

    Enum.find_value(config_paths, %{}, fn path ->
      if File.exists?(path) do
        case Toml.decode_file(path) do
          {:ok, config} -> config
          {:error, _reason} -> %{}
        end
      else
        nil
      end
    end)
  end

  @doc """
  Parse a boolean environment variable.
  """
  @spec parse_bool_env(String.t()) :: boolean() | nil
  def parse_bool_env(var_name) do
    case System.get_env(var_name) do
      "true" -> true
      "1" -> true
      "yes" -> true
      "false" -> false
      "0" -> false
      "no" -> false
      nil -> nil
      _ -> nil
    end
  end

  @doc """
  Parse an integer environment variable.
  """
  @spec parse_int_env(String.t()) :: integer() | nil
  def parse_int_env(var_name) do
    case System.get_env(var_name) do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {int, ""} -> int
          _ -> nil
        end
    end
  end
end
