defmodule CmdStan.Summary do
  @moduledoc """
  Computes summary statistics for MCMC samples using CmdStan's stansummary tool.

  Provides functionality similar to CmdStanPy's fit.summary() method.
  """

  alias CmdStan.{Platform, Runner}

  @doc """
  Compute summary statistics for MCMC fit results.

  ## Parameters
  - `fit`: Fit result from `CmdStan.Model.sample/3`
  - `opts`: Summary options
    - `:percentiles` - List of percentiles to compute (default: [5, 50, 95])
    - `:sig_figs` - Number of significant figures (default: 6)

  ## Returns
  A list of maps containing summary statistics for each variable:
  - `:variable` - Variable name
  - `:mean` - Mean value
  - `:std` - Standard deviation
  - `:mcse` - Monte Carlo standard error
  - `:ess` - Effective sample size
  - `:rhat` - R-hat convergence diagnostic
  - `:percentiles` - Map of percentile values

  ## Examples

      iex> fit = CmdStan.Model.sample(model, data, chains: 4, iter: 1000)
      iex> {:ok, summary} = CmdStan.Summary.summary(fit)
      iex> Enum.find(summary, &(&1.variable == "theta"))
      %{variable: "theta", mean: 0.5, std: 0.1, mcse: 0.001, ess: 800.0, rhat: 1.01, percentiles: %{5 => 0.3, 50 => 0.5, 95 => 0.7}}

  """
  @spec summary(map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def summary(fit, opts \\ []) do
    with {:ok, validated_opts} <- validate_options(opts),
         {:ok, csv_files} <- get_csv_files(fit),
         {:ok, output_file} <- run_stansummary(csv_files, validated_opts),
         {:ok, summary_data} <- parse_stansummary_output(output_file) do
      # Clean up temp file
      File.rm(output_file)
      {:ok, summary_data}
    else
      {:error, :cmdstan_not_found} = error ->
        # Return the error directly without cleanup
        error

      error ->
        # Clean up temp file on other errors if it exists
        error
    end
  end

  # Private functions

  defp validate_options(opts) do
    percentiles = opts[:percentiles] || [5, 50, 95]
    sig_figs = opts[:sig_figs] || 6

    # Validate percentiles
    with :ok <- validate_percentiles(percentiles),
         :ok <- validate_sig_figs(sig_figs) do
      {:ok, %{percentiles: percentiles, sig_figs: sig_figs}}
    end
  end

  defp validate_percentiles(percentiles) when is_list(percentiles) do
    if Enum.empty?(percentiles) do
      {:error, :empty_percentiles}
    else
      invalid = Enum.reject(percentiles, &(is_integer(&1) and &1 >= 1 and &1 <= 99))

      if Enum.empty?(invalid) do
        # Check if sorted and unique
        sorted = Enum.sort(percentiles)

        if sorted == percentiles and length(Enum.uniq(percentiles)) == length(percentiles) do
          :ok
        else
          {:error, :percentiles_not_sorted_unique}
        end
      else
        {:error, {:invalid_percentiles, invalid}}
      end
    end
  end

  defp validate_percentiles(_), do: {:error, :percentiles_not_list}

  defp validate_sig_figs(sig_figs) when is_integer(sig_figs) do
    if sig_figs >= 1 and sig_figs <= 18 do
      :ok
    else
      {:error, {:invalid_sig_figs, sig_figs}}
    end
  end

  defp validate_sig_figs(_), do: {:error, :sig_figs_not_integer}

  defp get_csv_files(fit) do
    case Map.get(fit, :csv_files) do
      nil ->
        {:error, :no_csv_files_in_fit}

      csv_files when is_list(csv_files) ->
        if Enum.all?(csv_files, &File.exists?/1) do
          {:ok, csv_files}
        else
          missing = Enum.reject(csv_files, &File.exists?/1)
          {:error, {:csv_files_missing, missing}}
        end

      _ ->
        {:error, :invalid_csv_files_format}
    end
  end

  defp run_stansummary(csv_files, opts) do
    # Get stansummary binary path
    case Platform.cmdstan_path() do
      nil ->
        {:error, :cmdstan_not_found}

      cmdstan_path ->
        stansummary_path = Path.join(cmdstan_path, "bin/stansummary")

        if File.exists?(stansummary_path) do
          # Create temporary output file
          output_file =
            System.tmp_dir!() |> Path.join("stansummary_output_#{:rand.uniform(1_000_000)}.csv")

          # Build command arguments
          args = build_stansummary_args(csv_files, output_file, opts)

          # Run stansummary
          case System.cmd(stansummary_path, args, stderr_to_stdout: true) do
            {output, 0} ->
              if File.exists?(output_file) do
                {:ok, output_file}
              else
                {:error, {:stansummary_output_missing, output_file, output}}
              end

            {output, exit_code} ->
              {:error, {:stansummary_failed, exit_code, output}}
          end
        else
          {:error, {:stansummary_not_found, stansummary_path}}
        end
    end
  end

  defp build_stansummary_args(csv_files, output_file, opts) do
    # Build percentiles as comma-separated string
    percentiles_str = opts.percentiles |> Enum.join(",")

    [
      "--csv_filename=#{output_file}",
      "--percentiles=#{percentiles_str}",
      "--sig_figs=#{opts.sig_figs}"
    ] ++ csv_files
  end

  defp parse_stansummary_output(output_file) do
    case File.read(output_file) do
      {:ok, content} ->
        parse_stansummary_content(content)

      {:error, reason} ->
        {:error, {:stansummary_output_read, reason}}
    end
  end

  defp parse_stansummary_content(content) do
    lines = String.split(content, "\n", trim: true)

    # Find the header line (skip comments)
    case find_summary_header_line(lines) do
      nil ->
        {:error, :no_summary_header_found}

      {header_line, data_lines} ->
        case parse_summary_header(header_line) do
          {:ok, columns} ->
            case parse_summary_data(data_lines, columns) do
              {:ok, summary_rows} ->
                # Filter variables (exclude diagnostics except lp__)
                filtered_rows = filter_summary_variables(summary_rows)
                {:ok, filtered_rows}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp find_summary_header_line(lines) do
    # Skip comment lines and find the CSV header
    case Enum.split_while(lines, &String.starts_with?(&1, "#")) do
      {_, []} ->
        nil

      {_, [header_line | data_lines]} ->
        {header_line, data_lines}
    end
  end

  defp parse_summary_header(line) do
    # Parse CSV header: variable,mean,std,mcse,ess,rhat,percentile_values...
    columns = NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first()

    # At minimum: variable,mean,std,mcse,ess,rhat
    if length(columns) >= 6 do
      {:ok, columns}
    else
      {:error, :insufficient_summary_columns}
    end
  end

  defp parse_summary_data(lines, columns) do
    # Skip empty lines
    data_lines = Enum.reject(lines, &(&1 == ""))

    results =
      Enum.map(data_lines, fn line ->
        # Skip comment lines and empty lines
        if String.starts_with?(line, "#") or String.trim(line) == "" do
          {:error, :skip_line}
        else
          values = NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first()

          if values && length(values) == length(columns) do
            # Parse the row
            [variable | stat_values] = values

            # Extract values: Mean, MCSE, StdDev, ESS_bulk, R_hat
            # Indices: 1=Mean, 2=MCSE, 3=StdDev, 8=ESS_bulk, 11=R_hat
            mean_str = Enum.at(stat_values, 1) || "0"
            mcse_str = Enum.at(stat_values, 2) || "0"
            std_str = Enum.at(stat_values, 3) || "0"
            ess_str = Enum.at(stat_values, 8) || "0"
            rhat_str = Enum.at(stat_values, 11) || "1"

            # Parse numeric values, handling "nan" and other non-numeric values
            mean = parse_float_or_nan(mean_str)
            std = parse_float_or_nan(std_str)
            mcse = parse_float_or_nan(mcse_str)
            ess = parse_float_or_nan(ess_str)
            rhat = parse_float_or_nan(rhat_str)

            if (is_number(mean) or mean in [:nan, :inf, :neg_inf]) and
                 (is_number(std) or std in [:nan, :inf, :neg_inf]) and
                 (is_number(mcse) or mcse in [:nan, :inf, :neg_inf]) and
                 (is_number(ess) or ess in [:nan, :inf, :neg_inf]) and
                 (is_number(rhat) or rhat in [:nan, :inf, :neg_inf]) do
              # Parse percentiles (5%, 50%, 95% are at indices 5, 6, 7)
              percentiles = parse_percentiles(columns, stat_values)

              row = %{
                variable: variable,
                mean: mean,
                std: std,
                mcse: mcse,
                ess: ess,
                rhat: rhat,
                percentiles: percentiles
              }

              {:ok, row}
            else
              {:error, {:parse_error, variable, values}}
            end
          else
            {:error, {:column_mismatch, length(values || []), length(columns)}}
          end
        end
      end)

    # Check for errors, filtering out skipped lines
    errors =
      Enum.filter(results, fn
        {:error, :skip_line} -> false
        {:error, _} -> true
        _ -> false
      end)

    if Enum.empty?(errors) do
      rows =
        Enum.filter(results, fn
          {:ok, row} -> true
          _ -> false
        end)
        |> Enum.map(fn {:ok, row} -> row end)

      {:ok, rows}
    else
      {:error, {:summary_parse_errors, errors}}
    end
  end

  defp parse_percentiles(columns, values) do
    # Columns beyond the basic 11 are additional percentiles
    # Basic columns: name,Mean,MCSE,StdDev,MAD,5%,50%,95%,ESS_bulk,ESS_tail,ESS_bulk/s,R_hat
    # So percentiles start at index 5, 6, 7 (5%, 50%, 95%)
    percentile_columns = Enum.slice(columns, 5..7)
    percentile_values = Enum.slice(values, 5..7)

    if length(percentile_columns) == length(percentile_values) do
      Enum.zip(percentile_columns, percentile_values)
      |> Enum.map(fn {col, val} ->
        # Extract percentile number from column name (e.g., "5%" -> 5)
        percentile = extract_percentile_number(col)
        float_val = parse_float_or_nan(val)
        {percentile, float_val}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp extract_percentile_number(column_name) do
    # Column names like "5%", "50%", "95%"
    case Regex.run(~r/(\d+)%/, column_name) do
      [_, num_str] -> String.to_integer(num_str)
      _ -> 0
    end
  end

  defp parse_float_or_nan(str) do
    case str do
      "nan" ->
        :nan

      "inf" ->
        :inf

      "-inf" ->
        :neg_inf

      _ ->
        case Float.parse(str) do
          {float, ""} -> float
          _ -> nil
        end
    end
  end

  defp filter_summary_variables(rows) do
    # Include lp__ and variables that don't end with __
    Enum.filter(rows, fn row ->
      var = row.variable
      var == "lp__" or not String.ends_with?(var, "__")
    end)
  end
end
