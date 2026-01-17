defmodule CmdStan.Downloader do
  @moduledoc """
  Handles downloading CmdStan releases from GitHub.

  Provides functionality to download tar.gz files, handle retries,
  and show progress during downloads.
  """

  alias CmdStan.Platform
  require Logger

  @max_retries 6
  # milliseconds
  @retry_delay 1000

  @doc """
  Get the download URL for a CmdStan version.

  ## Examples

      iex> CmdStan.Downloader.get_download_url("2.32.2")
      "https://github.com/stan-dev/cmdstan/releases/download/v2.32.2/cmdstan-2.32.2.tar.gz"

  """
  @spec get_download_url(String.t()) :: String.t()
  def get_download_url(version) do
    arch = Platform.final_arch()

    url_end =
      if arch && arch != "false" do
        "v#{version}/cmdstan-#{version}-linux-#{arch}.tar.gz"
      else
        "v#{version}/cmdstan-#{version}.tar.gz"
      end

    "https://github.com/stan-dev/cmdstan/releases/download/#{url_end}"
  end

  @doc """
  Get headers for GitHub API requests, including authorization if available.
  """
  @spec get_headers(String.t() | nil) :: [{String.t(), String.t()}]
  def get_headers(github_token \\ nil) do
    token = github_token || System.get_env("GITHUB_TOKEN")

    if token do
      [{"Authorization", "token #{token}"}]
    else
      []
    end ++ [{"User-Agent", "CmdStan-Elixir"}]
  end

  @doc """
  Get the latest CmdStan version from GitHub API.

  ## Examples

      iex> CmdStan.Downloader.get_latest_version()
      {:ok, "2.32.2"}

      iex> CmdStan.Downloader.get_latest_version("your_token")
      {:ok, "2.32.2"}

  """
  @spec get_latest_version(String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  def get_latest_version(github_token \\ nil) do
    url = "https://api.github.com/repos/stan-dev/cmdstan/releases/latest"
    headers = get_headers(github_token)

    retry_request(fn ->
      case HTTPoison.get(url, headers, timeout: 10000, recv_timeout: 10000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"tag_name" => tag_name}} ->
              # Remove leading 'v' if present
              version = String.trim_leading(tag_name, "v")
              {:ok, version}

            {:error, error} ->
              {:error, {:json_decode, error}}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          {:error, {:http_error, status_code, body}}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, {:network_error, reason}}
      end
    end)
  end

  @doc """
  Download a CmdStan version to a temporary file.

  Returns the path to the downloaded file.

  ## Examples

      iex> config = %CmdStan.Config{progress: true}
      iex> CmdStan.Downloader.download_release("2.32.2", config)
      {:ok, "/tmp/cmdstan-2.32.2.tar.gz"}

  """
  @spec download_release(String.t(), CmdStan.Config.t()) :: {:ok, String.t()} | {:error, term()}
  def download_release(version, config) do
    url = get_download_url(version)
    headers = get_headers(config.github_token)

    Logger.info("Downloading CmdStan version #{version} from #{url}")

    # Get file size for progress bar if enabled
    file_size =
      if config.progress do
        case get_file_size(url, headers) do
          {:ok, size} -> size
          {:error, _} -> nil
        end
      else
        nil
      end

    # Create temporary file
    temp_file = Path.join(System.tmp_dir!(), "cmdstan-#{version}.tar.gz")

    retry_request(fn ->
      download_with_progress(url, temp_file, headers, config.progress, file_size)
    end)
  end

  @doc """
  Clone a CmdStan git repository.

  ## Examples

      iex> CmdStan.Downloader.clone_git("develop", "/path/to/cmdstan-develop")
      :ok

  """
  @spec clone_git(String.t(), String.t()) :: :ok | {:error, term()}
  def clone_git(tag, dest_dir) do
    Logger.info("Cloning CmdStan branch '#{tag}' from stan-dev/cmdstan on GitHub")

    cmd = [
      "git",
      "clone",
      "--depth",
      "1",
      "--branch",
      tag,
      "--recursive",
      "--shallow-submodules",
      "https://github.com/stan-dev/cmdstan.git",
      dest_dir
    ]

    case System.cmd("git", cmd, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Git clone successful")
        :ok

      {output, code} ->
        Logger.error("Git clone failed with exit code #{code}: #{output}")
        {:error, {:git_clone_failed, code, output}}
    end
  end

  # Private functions

  defp retry_request(fun, attempt \\ 1) do
    case fun.() do
      {:error, reason} when attempt < @max_retries ->
        Logger.warning("Request failed (attempt #{attempt}/#{@max_retries}): #{inspect(reason)}")
        Process.sleep(@retry_delay * attempt)
        retry_request(fun, attempt + 1)

      result ->
        result
    end
  end

  defp get_file_size(url, headers) do
    case HTTPoison.head(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        case List.keyfind(headers, "Content-Length", 0) do
          {"Content-Length", size_str} ->
            case Integer.parse(size_str) do
              {size, ""} -> {:ok, size}
              _ -> {:error, :invalid_content_length}
            end

          nil ->
            {:error, :no_content_length}
        end

      _ ->
        {:error, :head_request_failed}
    end
  end

  defp download_with_progress(url, dest_file, headers, show_progress?, file_size) do
    # Use streaming download with progress bar if enabled
    if show_progress? && file_size && file_size > 0 do
      download_with_streaming_progress(url, dest_file, headers, file_size)
    else
      download_simple(url, dest_file, headers)
    end
  end

  defp download_simple(url, dest_file, headers) do
    case HTTPoison.get(url, headers, follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        File.write!(dest_file, body)
        {:ok, dest_file}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:network_error, reason}}
    end
  end

  defp download_with_streaming_progress(url, dest_file, headers, file_size) do
    filename = Path.basename(url)
    progress = CmdStan.DownloadProgress.new(filename, file_size)

    # Initial render
    initial_bar = CmdStan.ProgressRenderer.render(progress)
    IO.write("\r#{initial_bar}")

    # Stream download with progress updates
    stream_fun = fn
      {:data, chunk}, acc ->
        # Write chunk to file
        File.write!(dest_file, chunk, [:append])

        # Update progress
        progress = CmdStan.DownloadProgress.update(acc.progress, byte_size(chunk))

        # Render progress bar (throttled)
        if CmdStan.DownloadProgress.should_update?(progress) do
          bar = CmdStan.ProgressRenderer.render(progress)
          IO.write("\r#{bar}")
        end

        %{acc | progress: progress}

      other, acc ->
        acc
    end

    initial_acc = %{progress: progress}

    result = HTTPoison.get(url, headers, stream_to: stream_fun, follow_redirect: true)

    # Final newline
    final_progress = CmdStan.DownloadProgress.update(initial_acc.progress, 0)
    final_bar = CmdStan.ProgressRenderer.render(final_progress)
    IO.puts("\r#{final_bar}")

    case result do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, dest_file}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:network_error, reason}}
    end
  end
end
