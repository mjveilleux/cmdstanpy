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
  Run MCMC diagnostics on sampling results.

  Checks for sampling issues like divergent transitions, low E-BFMI values,
  low effective sample sizes, and high R-hat values.

  ## Parameters
  - `fit`: Fit result from `sample/3` containing `:csv_files`

  ## Returns
  A string containing the diagnostic output.

  ## Examples

      iex> fit = CmdStan.Model.sample(model, data, chains: 4, iter: 1000)
      iex> CmdStan.Model.diagnose_fit(fit)
      {:ok, "Checking sampler transitions treedepth.\\nTreedepth satisfactory for all transitions.\\n..."}

  """
  @spec diagnose_fit(map()) :: {:ok, String.t()} | {:error, term()}
  def diagnose_fit(fit) do
    csv_files = Map.get(fit, :csv_files)

    if is_nil(csv_files) or Enum.empty?(csv_files) do
      {:error, :no_csv_files_in_fit}
    else
      run_fit_diagnose(csv_files)
    end
  end

  @doc """
  Run gradient diagnostics on a compiled model.

  Compares automatic differentiation gradients with finite difference gradients
  to validate model implementation.

  ## Parameters
  - `model`: Model map returned by `compile/2`
  - `opts`: Diagnostic options
    - `:data` - Data map in Stan format (required)
    - `:inits` - Initial parameter values (map, file path, or number for range)
    - `:epsilon` - Step size for finite difference gradients (default: 1e-6)
    - `:error` - Absolute error threshold for gradient comparison (default: 1e-6)
    - `:sig_figs` - Numerical precision for output (default: nil)
    - `:require_gradients_ok` - Whether to raise error if gradients exceed threshold (default: true)
    - `:output_dir` - Directory for output files (default: system temp)

  ## Returns
  A result map containing:
  - `:diagnostics` - List of diagnostic results with columns: param_idx, value, model, finite_diff, error
  - `:metadata` - Diagnostic metadata including error threshold and pass/fail status

  ## Examples

      iex> model = %{exe_file: "bernoulli"}
      iex> data = %{"N" => 10, "y" => [0,1,0,0,0,0,0,0,0,1]}
      iex> CmdStan.Model.diagnose(model, data: data)
      {:ok, %{diagnostics: [%{param_idx: 0, value: 0.5, model: -0.123, finite_diff: -0.124, error: 0.001}], metadata: %{...}}}

  """
  @spec diagnose(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def diagnose(model, opts \\ []) do
    data = opts[:data]

    if is_nil(data) do
      {:error, {:data_file_error, :no_data_provided}}
    else
      with {:ok, exe_path} <- validate_model_executable(model),
           {:ok, data_file} <- prepare_data_file(data),
           {:ok, inits_file} <- prepare_inits_file(opts[:inits]),
           {:ok, output_dir} <- prepare_output_dir(opts),
           :ok <- copy_data_file_to_output_dir(data_file, output_dir),
           {:ok, args} <- build_diagnose_args(opts),
           {:ok, csv_file} <- run_diagnose(exe_path, args, output_dir),
           {:ok, diagnostics} <- parse_diagnose_csv(csv_file) do
        # Clean up temporary files
        File.rm(data_file)
        File.rm(inits_file || "")

        # Validate results
        error_threshold = opts[:error] || 1.0e-6
        require_ok = opts[:require_gradients_ok] != false

        {status, max_error} = validate_diagnostics(diagnostics, error_threshold)

        if require_ok and status == :failed do
          {:error, {:gradients_failed, max_error, error_threshold}}
        else
          result = %{
            diagnostics: diagnostics,
            metadata: %{
              error_threshold: error_threshold,
              max_error: max_error,
              status: status,
              require_gradients_ok: require_ok
            }
          }

          {:ok, result}
        end
      else
        error ->
          # Clean up on error
          error
      end
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
    chains = opts[:chains] || 1

    with {:ok, exe_path} <- validate_model_executable(model),
         {:ok, data_file} <- prepare_data_file(data),
         {:ok, output_dir} <- prepare_output_dir(opts),
         :ok <- copy_data_file_to_output_dir(data_file, output_dir),
         {:ok, args} <- build_sample_args(opts),
         {:ok, csv_files} <- Runner.run_model(exe_path, args, output_dir, chains),
         {:ok, result} <- parse_csv_files(csv_files) do
      # Clean up temporary data file
      File.rm(data_file)

      # Build final result
      final_result = %{
        draws: result.draws,
        metadata: %{
          chains: chains,
          iterations: opts[:iter] || 1000,
          parameters: result.parameters,
          total_draws: result.metadata.total_draws
        },
        diagnostics: %{
          # Placeholder - would need to parse from CSV
          divergences: 0
        },
        # Store CSV files for summary function
        csv_files: csv_files
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

  defp prepare_inits_file(nil), do: {:ok, nil}

  defp prepare_inits_file(inits) when is_map(inits) do
    case Data.write_temp_file(inits) do
      {:ok, file_path} -> {:ok, file_path}
      {:error, reason} -> {:error, {:inits_file_error, reason}}
    end
  end

  defp prepare_inits_file(inits) when is_binary(inits) do
    if File.exists?(inits) do
      {:ok, inits}
    else
      {:error, {:inits_file_not_found, inits}}
    end
  end

  defp prepare_inits_file(inits) when is_number(inits) do
    # Generate random inits in range [0, inits)
    inits_map = %{"dummy" => :rand.uniform() * inits}
    prepare_inits_file(inits_map)
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

  defp build_diagnose_args(opts) do
    epsilon = opts[:epsilon] || 1.0e-6
    error = opts[:error] || 1.0e-6
    sig_figs = opts[:sig_figs]

    args = [
      "diagnose",
      "test=gradient",
      "epsilon=#{epsilon}",
      "error=#{error}"
    ]

    args = if sig_figs, do: args ++ ["sig_figs=#{sig_figs}"], else: args

    # Add inits file if provided
    args = if opts[:inits], do: args ++ ["init=#{opts[:inits]}"], else: args

    {:ok, args}
  end

  defp copy_data_file_to_output_dir(data_file, output_dir) do
    expected_path = Path.join(output_dir, "data.json")

    case File.cp(data_file, expected_path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:data_file_copy, reason}}
    end
  end

  defp parse_csv_files(csv_files) do
    # For now, parse the first CSV file
    # TODO: Merge results from all chains
    case CSVParser.parse(hd(csv_files)) do
      {:ok, result} -> {:ok, result}
      error -> error
    end
  end

  defp run_diagnose(exe_path, args, output_dir) do
    output_file = Path.join(output_dir, "diagnose_output.csv")

    cmd_args =
      [
        "data",
        "file=#{output_dir}/data.json",
        "output",
        "file=#{output_file}"
      ] ++ args

    case System.cmd(exe_path, cmd_args, stderr_to_stdout: true) do
      {output, 0} ->
        if File.exists?(output_file) do
          {:ok, output_file}
        else
          {:error, {:diagnose_output_missing, output_file, output}}
        end

      {output, exit_code} ->
        {:error, {:diagnose_failed, exit_code, output}}
    end
  end

  defp parse_diagnose_csv(csv_file) do
    case File.read(csv_file) do
      {:ok, content} ->
        parse_diagnose_content(content)

      {:error, reason} ->
        {:error, {:diagnose_csv_read, reason}}
    end
  end

  defp parse_diagnose_content(content) do
    lines = String.split(content, "\n", trim: true)

    # Find the header line (first non-comment line)
    case find_diagnose_header_line(lines) do
      nil ->
        {:error, :no_diagnose_header_found}

      {header_line, data_lines} ->
        case parse_diagnose_header(header_line) do
          {:ok, _columns} ->
            parse_diagnose_data_lines(data_lines)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp find_diagnose_header_line(lines) do
    # Skip comment lines and find the first CSV header line
    case Enum.split_while(lines, &String.starts_with?(&1, "#")) do
      {_, []} ->
        # No non-comment lines found
        nil

      {_, [header_line | data_lines]} ->
        {header_line, data_lines}
    end
  end

  defp parse_diagnose_header(line) do
    # Diagnose CSV header: param_idx,value,model,finite_diff,error
    columns = NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first()

    expected_columns = ["param_idx", "value", "model", "finite_diff", "error"]

    if columns == expected_columns do
      {:ok, columns}
    else
      {:error, {:unexpected_diagnose_columns, columns, expected_columns}}
    end
  end

  defp parse_diagnose_data_lines(lines) do
    # Parse data lines, skipping comments
    data_lines = Enum.reject(lines, &String.starts_with?(&1, "#"))

    diagnostics =
      Enum.reduce(data_lines, [], fn line, acc ->
        case NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first() do
          [param_idx_str, value_str, model_str, finite_diff_str, error_str] ->
            case {
              Integer.parse(param_idx_str),
              Float.parse(value_str),
              Float.parse(model_str),
              Float.parse(finite_diff_str),
              Float.parse(error_str)
            } do
              {{param_idx, ""}, {value, ""}, {model, ""}, {finite_diff, ""}, {error, ""}} ->
                diagnostic = %{
                  param_idx: param_idx,
                  value: value,
                  model: model,
                  finite_diff: finite_diff,
                  error: error
                }

                [diagnostic | acc]

              _ ->
                # Skip malformed lines
                acc
            end

          _ ->
            # Skip malformed lines
            acc
        end
      end)

    # Reverse since we prepended
    {:ok, Enum.reverse(diagnostics)}
  end

  defp validate_diagnostics(diagnostics, error_threshold) do
    errors = Enum.map(diagnostics, &abs(&1.error))

    max_error = if Enum.empty?(errors), do: 0.0, else: Enum.max(errors)

    status = if max_error > error_threshold, do: :failed, else: :passed

    {status, max_error}
  end

  defp run_fit_diagnose(csv_files) do
    cmdstan_path = get_cmdstan_path()

    if is_nil(cmdstan_path) do
      {:error, :cmdstan_not_found}
    else
      diagnose_exe = Path.join([cmdstan_path, "bin", "diagnose"])

      if File.exists?(diagnose_exe) do
        case System.cmd(diagnose_exe, csv_files, stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, output}

          {output, exit_code} ->
            {:error, {:diagnose_failed, exit_code, output}}
        end
      else
        {:error, {:diagnose_executable_not_found, diagnose_exe}}
      end
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
