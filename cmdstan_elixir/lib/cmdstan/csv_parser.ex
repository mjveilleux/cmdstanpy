defmodule CmdStan.CSVParser do
  @moduledoc """
  Parses CmdStan CSV output files.

  Extracts draws, metadata, and basic diagnostics from CmdStan CSV files.
  """

  @doc """
  Parse a CmdStan CSV file and return structured results.

  ## Examples

      iex> {:ok, result} = CmdStan.CSVParser.parse("output.csv")
      iex> result.parameters
      ["theta"]
      iex> result.draws["theta"] |> length()
      1000

  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, term()}
  def parse(csv_file) do
    case File.read(csv_file) do
      {:ok, content} ->
        parse_csv_content(content)

      {:error, reason} ->
        {:error, {:file_read, reason}}
    end
  end

  # Private functions

  defp parse_csv_content(content) do
    lines = String.split(content, "\n", trim: true)

    # Find the header line (first non-comment line)
    case find_header_line(lines) do
      nil ->
        {:error, :no_header_found}

      {header_line, data_lines} ->
        case parse_header(header_line) do
          {:ok, parameters} ->
            case parse_data_lines(data_lines, parameters) do
              {:ok, draws} ->
                result = %{
                  parameters: parameters,
                  draws: draws,
                  metadata: %{
                    total_draws: length(draws[hd(parameters)] || [])
                  }
                }

                {:ok, result}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp find_header_line(lines) do
    # Skip comment lines and find the first CSV header line
    case Enum.split_while(lines, &String.starts_with?(&1, "#")) do
      {_, []} ->
        # No non-comment lines found
        nil

      {_, [header_line | data_lines]} ->
        {header_line, data_lines}
    end
  end

  defp parse_header(line) do
    # CSV header format: lp__,accept_stat__,stepsize__,treedepth__,n_leapfrog__,divergent__,energy__,theta
    # We want to extract parameter names (everything after the diagnostic columns)
    columns = NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first()

    # Skip diagnostic columns and extract parameter names
    # This is a simplified approach - in reality CmdStan has many diagnostic columns
    # Skip first 7 diagnostic columns
    parameters = Enum.drop(columns, 7)

    if Enum.empty?(parameters) do
      {:error, :no_parameters_found}
    else
      {:ok, parameters}
    end
  end

  defp parse_data_lines(lines, parameters) do
    # Parse data lines, skipping comments (lines starting with #)
    data_lines = Enum.reject(lines, &String.starts_with?(&1, "#"))

    # Initialize draws map
    draws =
      Enum.reduce(parameters, %{}, fn param, acc ->
        Map.put(acc, param, [])
      end)

    # Parse each data line
    result =
      Enum.reduce_while(data_lines, {:ok, draws}, fn line, {:ok, current_draws} ->
        case NimbleCSV.RFC4180.parse_string(line, skip_headers: false) |> List.first() do
          [] ->
            # Empty line, skip
            {:cont, {:ok, current_draws}}

          values when length(values) >= 7 ->
            # Extract parameter values (skip diagnostic columns)
            param_values = Enum.drop(values, 7)

            if length(param_values) == length(parameters) do
              # Add values to draws
              new_draws =
                Enum.zip(parameters, param_values)
                |> Enum.reduce(current_draws, fn {param, value_str}, acc ->
                  # Convert string to float
                  case Float.parse(value_str) do
                    {value, ""} ->
                      Map.update!(acc, param, &[value | &1])

                    _ ->
                      # If not a valid float, keep as string
                      Map.update!(acc, param, &[value_str | &1])
                  end
                end)

              {:cont, {:ok, new_draws}}
            else
              {:halt,
               {:error, {:parameter_count_mismatch, length(param_values), length(parameters)}}}
            end

          _ ->
            # Malformed line, skip
            {:cont, {:ok, current_draws}}
        end
      end)

    case result do
      {:ok, final_draws} ->
        # Reverse lists since we prepended
        reversed_draws =
          Enum.map(final_draws, fn {param, values} ->
            {param, Enum.reverse(values)}
          end)
          |> Map.new()

        {:ok, reversed_draws}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
