defmodule CmdStan.DataTest do
  use ExUnit.Case, async: true
  doctest CmdStan.Data

  describe "to_json/1" do
    test "converts map to JSON string" do
      data = %{"N" => 10, "y" => [0, 1, 0]}
      assert {:ok, json} = CmdStan.Data.to_json(data)
      assert json == "{\"N\":10,\"y\":[0,1,0]}"
    end
  end

  describe "write_temp_file/1" do
    test "writes data to temporary file and returns path" do
      data = %{"test" => "value"}
      assert {:ok, path} = CmdStan.Data.write_temp_file(data)
      assert File.exists?(path)

      # Clean up
      File.rm!(path)
    end
  end
end
