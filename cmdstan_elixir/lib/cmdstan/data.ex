defmodule CmdStan.Data do
  @moduledoc """
  Handles data serialization for CmdStan.

  Converts Elixir data structures to JSON format expected by CmdStan,
  and manages temporary data files.
  """

  @doc """
  Convert a data map to JSON string in Stan format.

  ## Examples

      iex> CmdStan.Data.to_json(%{"N" => 10, "y" => [1, 0, 1]})
      {:ok, "{\\"N\\":10,\\"y\\":[1,0,1]}"}

  """
  @spec to_json(map()) :: {:ok, String.t()} | {:error, term()}
  def to_json(data) when is_map(data) do
    try do
      json = Jason.encode!(data)
      {:ok, json}
    rescue
      error -> {:error, {:json_encode, error}}
    end
  end

  @doc """
  Write data to a temporary JSON file and return the file path.

  ## Examples

      iex> data = %{"N" => 5, "y" => [1, 0, 1, 1, 0]}
      iex> {:ok, path} = CmdStan.Data.write_temp_file(data)
      iex> File.exists?(path)
      true

  """
  @spec write_temp_file(map()) :: {:ok, String.t()} | {:error, term()}
  def write_temp_file(data) when is_map(data) do
    with {:ok, json} <- to_json(data) do
      temp_dir = System.tmp_dir!()
      temp_file = Path.join(temp_dir, "cmdstan_data_#{:erlang.unique_integer([:positive])}.json")

      case File.write(temp_file, json) do
        :ok -> {:ok, temp_file}
        {:error, reason} -> {:error, {:file_write, reason}}
      end
    end
  end
end
