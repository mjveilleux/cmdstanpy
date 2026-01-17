defmodule CmdStan.Runner do
  @moduledoc """
  Executes CmdStan model binaries and manages output files.
  """

  @doc """
  Run a CmdStan model executable with given arguments.

  Returns the path to the output CSV file containing the results.

  ## Examples

      iex> CmdStan.Runner.run_model("/path/to/model", ["data", "file=/tmp/data.json"], "/tmp/output")
      {:ok, "/tmp/output/model_output_1.csv"}

  """
  @spec run_model(String.t(), [String.t()], String.t()) :: {:ok, String.t()} | {:error, term()}
  def run_model(exe_path, args, output_dir) do
    # Ensure output directory exists
    case File.mkdir_p(output_dir) do
      :ok ->
        # Generate output filename
        base_name = Path.basename(exe_path, Path.extname(exe_path))
        output_file = Path.join(output_dir, "#{base_name}_output_1.csv")

        # Build command arguments
        cmd_args =
          [
            "data",
            "file=#{output_dir}/data.json",
            "output",
            "file=#{output_file}"
          ] ++ args

        # Execute the model
        case System.cmd(exe_path, cmd_args, stderr_to_stdout: true) do
          {output, 0} ->
            # Check if output file was created
            if File.exists?(output_file) do
              {:ok, output_file}
            else
              {:error, {:output_file_missing, output_file, output}}
            end

          {output, exit_code} ->
            {:error, {:execution_failed, exit_code, output}}
        end

      {:error, reason} ->
        {:error, {:output_dir_create, reason}}
    end
  end
end
