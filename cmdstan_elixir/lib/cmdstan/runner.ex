defmodule CmdStan.Runner do
  @moduledoc """
  Executes CmdStan model binaries and manages output files.
  """

  @doc """
  Run a CmdStan model executable with given arguments.

  Returns the paths to the output CSV files containing the results (one per chain).

  ## Examples

      iex> CmdStan.Runner.run_model("/path/to/model", ["data", "file=/tmp/data.json"], "/tmp/output", 4)
      {:ok, ["/tmp/output/model_output_1.csv", "/tmp/output/model_output_2.csv", "/tmp/output/model_output_3.csv", "/tmp/output/model_output_4.csv"]}

  """
  @spec run_model(String.t(), [String.t()], String.t(), non_neg_integer()) ::
          {:ok, [String.t()]} | {:error, term()}
  def run_model(exe_path, args, output_dir, chains \\ 1) do
    case File.mkdir_p(output_dir) do
      :ok ->
        run_model_in_dir(exe_path, args, output_dir, chains)

      {:error, reason} ->
        {:error, {:output_dir_create, reason}}
    end
  end

  defp run_model_in_dir(exe_path, args, output_dir, chains) do
    base_name = Path.basename(exe_path, Path.extname(exe_path))

    if chains == 1 do
      # Single chain - use existing logic
      output_file = Path.join(output_dir, "#{base_name}_output_1.csv")

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
            {:ok, [output_file]}
          else
            {:error, {:output_file_missing, output_file, output}}
          end

        {output, exit_code} ->
          {:error, {:execution_failed, exit_code, output}}
      end
    else
      # Multiple chains - CmdStan will create numbered output files
      cmd_args =
        [
          "data",
          "file=#{output_dir}/data.json"
        ] ++ args

      case System.cmd(exe_path, cmd_args, stderr_to_stdout: true, cd: output_dir) do
        {output, 0} ->
          # Check if all expected output files were created
          expected_files =
            for i <- 1..chains do
              Path.join(output_dir, "output_#{i}.csv")
            end

          missing_files = Enum.reject(expected_files, &File.exists?/1)

          if Enum.empty?(missing_files) do
            {:ok, expected_files}
          else
            {:error, {:output_files_missing, missing_files, output}}
          end

        {output, exit_code} ->
          {:error, {:execution_failed, exit_code, output}}
      end
    end
  end
end
