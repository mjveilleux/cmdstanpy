defmodule CmdStanTest do
  use ExUnit.Case

  describe "install_cmdstan/1" do
    # Skip for now until we add proper mocking
    @tag :skip
    test "accepts configuration options" do
      # Test that the function accepts options without crashing
      # In a real test, we'd mock the network calls
      result = CmdStan.install_cmdstan(version: "2.32.2", dir: "/tmp/test_cmdstan")
      # This will fail with network errors, but at least it doesn't crash
      assert match?({:error, _}, result) or result == :ok
    end
  end

  describe "CmdStan.Config" do
    test "creates config with defaults" do
      config = CmdStan.Config.new([])
      assert config.dir == CmdStan.Config.default_install_dir()
      assert config.overwrite == false
      assert config.progress == false
      assert config.verbose == false
      assert config.cores >= 1
    end

    test "accepts custom options" do
      config = CmdStan.Config.new(version: "2.32.2", progress: true)
      assert config.version == "2.32.2"
      assert config.progress == true
    end
  end

  describe "CmdStan.Platform" do
    test "detects operating system" do
      os = CmdStan.Platform.os()
      assert os in [:linux, :macos, :windows, :unknown]
    end

    test "returns correct executable extension" do
      extension = CmdStan.Platform.extension()

      case CmdStan.Platform.os() do
        :windows -> assert extension == ".exe"
        _ -> assert extension == ""
      end
    end
  end
end
