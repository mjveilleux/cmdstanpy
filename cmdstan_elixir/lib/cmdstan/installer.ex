defmodule CmdStan.Installer do
  @moduledoc """
  Main installer for CmdStan.

  Orchestrates the download, extraction, building, and testing of CmdStan installations.
  """

  alias CmdStan.{Config, Platform, Downloader, Builder}
  require Logger

  @doc """
  Install CmdStan with the given configuration.

  This is the main entry point that handles the complete installation process:
  1. Validate configuration and directory
  2. Get the version to install (latest if not specified)
  3. Download or clone the CmdStan release
  4. Extract the archive
  5. Build CmdStan
  6. Test the compilation
  7. Set the CmdStan path

  ## Examples

      iex> CmdStan.Installer.install_cmdstan(version: "2.32.2")
      :ok

      iex> CmdStan.Installer.install_cmdstan(dir: "/opt/cmdstan", progress: true, verbose: true)
      :ok

  """
  @spec install_cmdstan(keyword()) :: :ok | {:error, term()}
  def install_cmdstan(opts \\ []) do
    config = Config.new(opts)

    try do
      Logger.info("Starting CmdStan installation")

      # Validate installation directory
      Platform.validate_dir(config.dir)
      Logger.info("Installation directory: #{config.dir}")

      # Get version to install
      version = config.version || get_version_to_install(config)
      Logger.info("Installing CmdStan version: #{version}")

      # Check if already installed
      cmdstan_dir = Path.join(config.dir, cmdstan_folder_name(version))

      if already_installed?(cmdstan_dir, config.overwrite) do
        Logger.info("CmdStan version #{version} already installed")
        set_cmdstan_path(config.dir, version)
        :ok
      else
        # Download and install
        with {:ok, extracted_dir} <- download_and_extract(version, config),
             :ok <- build_and_test(extracted_dir, config) do
          set_cmdstan_path(config.dir, version)
          Logger.info("CmdStan installation completed successfully")
          :ok
        end
      end
    catch
      error ->
        Logger.error("CmdStan installation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private functions

  defp get_version_to_install(config) do
    case Downloader.get_latest_version(config.github_token) do
      {:ok, version} ->
        Logger.info("Using latest version: #{version}")
        version

      {:error, reason} ->
        raise "Failed to get latest version: #{inspect(reason)}"
    end
  end

  defp cmdstan_folder_name(version) do
    if String.starts_with?(version, "git:") do
      tag = String.replace_prefix(version, "git:", "")
      "cmdstan-#{String.replace(tag, "/", "_")}"
    else
      "cmdstan-#{version}"
    end
  end

  defp already_installed?(cmdstan_dir, overwrite) do
    if overwrite do
      false
    else
      File.exists?(cmdstan_dir) &&
        bernoulli_executable_exists?(cmdstan_dir)
    end
  end

  defp bernoulli_executable_exists?(cmdstan_dir) do
    exe_path =
      Path.join([cmdstan_dir, "examples", "bernoulli", "bernoulli#{Platform.extension()}"])

    File.exists?(exe_path)
  end

  defp download_and_extract(version, config) do
    cmdstan_dir = Path.join(config.dir, cmdstan_folder_name(version))

    # Remove existing directory if it exists
    if File.exists?(cmdstan_dir) do
      Logger.info("Removing existing installation: #{cmdstan_dir}")
      File.rm_rf!(cmdstan_dir)
    end

    if String.starts_with?(version, "git:") do
      # Clone from git
      tag = String.replace_prefix(version, "git:", "")

      case Downloader.clone_git(tag, cmdstan_dir) do
        :ok -> {:ok, cmdstan_dir}
        {:error, reason} -> {:error, reason}
      end
    else
      # Download tar.gz and extract
      case Downloader.download_release(version, config) do
        {:ok, tar_file} ->
          Logger.info("Extracting #{tar_file} to #{config.dir}")

          case extract_tar_gz(tar_file, config.dir) do
            :ok ->
              # Clean up downloaded file
              File.rm!(tar_file)
              {:ok, cmdstan_dir}

            {:error, reason} ->
              {:error, {:extraction_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:download_failed, reason}}
      end
    end
  end

  defp extract_tar_gz(tar_file, dest_dir) do
    # Use erl_tar for extraction
    case :erl_tar.extract(String.to_charlist(tar_file), [
           :compressed,
           {:cwd, String.to_charlist(dest_dir)}
         ]) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_and_test(cmdstan_dir, config) do
    with :ok <- Builder.build_cmdstan(cmdstan_dir, config),
         :ok <- Builder.test_compilation(cmdstan_dir, config) do
      :ok
    end
  end

  defp set_cmdstan_path(install_dir, version) do
    folder_name = cmdstan_folder_name(version)
    cmdstan_path = Path.join(install_dir, folder_name)

    # Set environment variable
    System.put_env("CMDSTAN", cmdstan_path)

    Logger.info("CmdStan path set to: #{cmdstan_path}")
  end
end
