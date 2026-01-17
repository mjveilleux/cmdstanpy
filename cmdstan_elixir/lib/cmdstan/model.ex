defmodule CmdStan.Model do
  @moduledoc """
  CmdStan model compilation and sampling.

  Provides functions to compile Stan models and run MCMC sampling.
  """

  alias CmdStan.{Data, CSVParser, Runner}

  @doc """
  Compile a Stan model file to an executable.

  ## Parameters
  - `stan_file`: Path to the Stan model file (.stan)
  - `opts`: Compilation options (currently unused)

  ## Returns
  A map containing model information:
  - `:name` - Model name (derived from filename)
  - `:stan_file` - Path to Stan file
  - `:exe_file` - Path to compiled executable

  ## Examples

      iex> CmdStan.Model.compile("model.stan")
      {:ok, %{name: "model", stan_file: "model.stan", exe_file: "model"}}

  """
  @spec compile(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def compile(stan_file, _opts \\ []) do
    cond do
      not File.exists?(stan_file) ->
        {:error, {:file_not_found, stan_file}}

      not String.ends_with?(stan_file, ".stan") ->
        {:error, {:invalid_extension, stan_file}}

      true ->
        compile_model(stan_file)
    end
  end

  @doc """
  Run MCMC sampling on a compiled model.

  ## Parameters
  - `model`: Model map returned by `compile/2`
  - `data`: Data map in Stan format
  - `opts`: Sampling options
    - `:chains` - Number of chains (default: 1)
    - `:iter` - Total iterations per chain (default: 1000)
    - `:warmup` - Warmup iterations (default: iter/2)
    - `:output_dir` - Directory for output files (default: system temp)

  ## Returns
  A result map containing:
  - `:draws` - Map of parameter draws
  - `:metadata` - Sampling metadata
  - `:diagnostics` - Basic diagnostics

  ## Examples

      iex> model = %{exe_file: "bernoulli"}
      iex> data = %{"N" => 10, "y" => [0,1,0,0,0,0,0,0,0,1]}
      iex> CmdStan.Model.sample(model, data, chains: 1, iter: 100)
      {:ok, %{draws: %{"theta" => [0.2, 0.3, ...]}, metadata: %{...}, diagnostics: %{...}}}

  """
  @spec sample(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def sample(model, data, opts \\ []) do
    with {:ok, exe_path} <- validate_model_executable(model),
         {:ok, data_file} <- prepare_data_file(data),
         {:ok, output_dir} <- prepare_output_dir(opts),
         :ok <- copy_data_file_to_output_dir(data_file, output_dir),
         {:ok, args} <- build_sample_args(opts),
         {:ok, csv_file} <- Runner.run_model(exe_path, args, output_dir),
         {:ok, result} <- CSVParser.parse(csv_file) do
      # Clean up temporary data file
      File.rm(data_file)

      # Build final result
      final_result = %{
        draws: result.draws,
        metadata: %{
          chains: opts[:chains] || 1,
          iterations: opts[:iter] || 1000,
          parameters: result.parameters,
          total_draws: result.metadata.total_draws
        },
        diagnostics: %{
          # Placeholder - would need to parse from CSV
          divergences: 0
        }
      }

      {:ok, final_result}
    else
      error ->
        # Clean up on error
        error
    end
  end

  # Private functions

  defp compile_model(stan_file) do
    # Get CmdStan installation path
    cmdstan_path = get_cmdstan_path()

    if is_nil(cmdstan_path) do
      {:error, :cmdstan_not_found}
    else
      # Change to CmdStan directory and run make
      original_cwd = File.cwd!()
      model_name = Path.basename(stan_file, ".stan")
      model_dir = Path.dirname(stan_file)

      try do
        # Copy stan file to CmdStan directory if needed
        cmdstan_model_file = Path.join([cmdstan_path, "#{model_name}.stan"])

        if model_dir != cmdstan_path do
          case File.copy(stan_file, cmdstan_model_file) do
            {:ok, _bytes} -> :ok
            {:error, reason} -> throw({:error, {:file_copy, reason}})
          end
        end

        # Change to CmdStan directory
        File.cd!(cmdstan_path)

        # Run make to compile
        case System.cmd("make", [model_name], stderr_to_stdout: true) do
          {output, 0} ->
            exe_path = Path.join(cmdstan_path, model_name)

            if File.exists?(exe_path) do
              result = %{
                name: model_name,
                stan_file: stan_file,
                exe_file: exe_path
              }

              {:ok, result}
            else
              {:error, {:executable_not_created, exe_path}}
            end

          {output, exit_code} ->
            {:error, {:compilation_failed, exit_code, output}}

          {:error, reason} ->
            {:error, {:make_command_error, reason}}
        end
      catch
        {:error, reason} -> {:error, reason}
      after
        File.cd!(original_cwd)
      end
    end
  end

  defp validate_model_executable(model) do
    exe_path = Map.get(model, :exe_file)

    if exe_path && File.exists?(exe_path) do
      {:ok, exe_path}
    else
      {:error, {:executable_not_found, exe_path}}
    end
  end

  defp prepare_data_file(data) do
    case Data.write_temp_file(data) do
      {:ok, file_path} -> {:ok, file_path}
      {:error, reason} -> {:error, {:data_file_error, reason}}
    end
  end

  defp prepare_output_dir(opts) do
    output_dir = opts[:output_dir] || System.tmp_dir!()

    case File.mkdir_p(output_dir) do
      :ok -> {:ok, output_dir}
      {:error, reason} -> {:error, {:output_dir_error, reason}}
    end
  end

  defp build_sample_args(opts) do
    chains = opts[:chains] || 1
    iter = opts[:iter] || 1000
    warmup = opts[:warmup] || div(iter, 2)

    args = [
      "method=sample",
      "num_chains=#{chains}",
      "num_samples=#{iter - warmup}",
      "num_warmup=#{warmup}"
    ]

    {:ok, args}
  end

  defp copy_data_file_to_output_dir(data_file, output_dir) do
    expected_path = Path.join(output_dir, "data.json")

    case File.cp(data_file, expected_path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:data_file_copy, reason}}
    end
  end

  defp get_cmdstan_path do
    # Check environment variable first
    case System.get_env("CMDSTAN") do
      nil ->
        # Try default location
        default_path = Path.expand("~/.cmdstan")

        if File.exists?(default_path) do
          # Find the latest version
          case File.ls(default_path) do
            {:ok, entries} ->
              cmdstan_dirs = Enum.filter(entries, &String.starts_with?(&1, "cmdstan-"))

              if Enum.empty?(cmdstan_dirs) do
                nil
              else
                latest = Enum.max(cmdstan_dirs)
                Path.join(default_path, latest)
              end

            _ ->
              nil
          end
        else
          nil
        end

      path ->
        path
    end
  end
end
