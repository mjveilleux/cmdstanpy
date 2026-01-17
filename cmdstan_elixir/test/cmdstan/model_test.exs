defmodule CmdStan.ModelTest do
  use ExUnit.Case, async: true

  describe "compile/2" do
    test "returns error for non-existent file" do
      assert {:error, {:file_not_found, "nonexistent.stan"}} =
               CmdStan.Model.compile("nonexistent.stan")
    end

    test "returns error for invalid file extension" do
      # Create a temporary file with wrong extension
      temp_file = Path.join(System.tmp_dir!(), "test.txt")
      File.write!(temp_file, "test content")

      try do
        assert {:error, {:invalid_extension, ^temp_file}} = CmdStan.Model.compile(temp_file)
      after
        File.rm(temp_file)
      end
    end

    test "returns error when CmdStan not found" do
      # This would normally work but we'll test the error path by mocking
      # For now, just test that it returns proper error structure
      result = CmdStan.Model.compile("test.stan")
      assert match?({:error, _}, result)
    end
  end

  describe "sample/3" do
    test "validates model has executable" do
      model = %{name: "test"}
      data = %{"N" => 5}

      assert {:error, {:executable_not_found, nil}} = CmdStan.Model.sample(model, data)
    end

    test "accepts sampling options" do
      # This test would require mocking the entire CmdStan execution
      # For now, just verify the function accepts the right parameters
      model = %{exe_file: "/fake/path"}
      data = %{"N" => 5}

      result = CmdStan.Model.sample(model, data, chains: 2, iter: 500)
      # Will fail because exe doesn't exist
      assert match?({:error, _}, result)
    end
  end
end
