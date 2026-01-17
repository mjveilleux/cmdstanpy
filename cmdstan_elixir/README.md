# CmdStan

Elixir library for installing and managing CmdStan, the command-line interface to Stan.

This library provides functionality to download, install, and manage CmdStan releases from GitHub, similar to the Python CmdStanPy library.

## Installation

Add `cmdstan` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cmdstan, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Installation

Install the latest version of CmdStan:

```elixir
CmdStan.install_cmdstan()
```

### Install Specific Version

```elixir
CmdStan.install_cmdstan(version: "2.32.2")
```

### Custom Installation Directory

```elixir
CmdStan.install_cmdstan(dir: "/opt/cmdstan", progress: true, verbose: true)
```

### All Options

```elixir
CmdStan.install_cmdstan(
  version: "2.32.2",           # CmdStan version (default: latest)
  dir: "/opt/cmdstan",         # Installation directory (default: ~/.cmdstan)
  overwrite: true,             # Overwrite existing installation
  progress: true,              # Show download progress
  verbose: true,               # Show build output
  cores: 4,                    # CPU cores for building (default: schedulers_online)
  interactive: false           # Interactive mode (default: false)
)
```

## Configuration

The library can be configured via:

1. **Environment variables**:
   - `CMDSTAN_VERSION`: Default version to install
   - `CMDSTAN_DIR`: Default installation directory
   - `CMDSTAN_OVERWRITE`: Overwrite existing installations
   - `CMDSTAN_PROGRESS`: Show progress by default
   - `CMDSTAN_VERBOSE`: Show verbose output by default
   - `CMDSTAN_CORES`: Default number of cores
   - `GITHUB_TOKEN`: GitHub token for API access

2. **Configuration file** (`~/.cmdstan.toml` or `~/.config/cmdstan/config.toml`):
   ```toml
   version = "2.32.2"
   dir = "/opt/cmdstan"
   progress = true
   verbose = true
   ```

## Features

- ✅ Cross-platform support (Linux, macOS, Windows)
- ✅ Automatic latest version detection
- ✅ Git repository cloning for development versions
- ✅ Configurable installation directory
- ✅ Progress reporting
- ✅ Comprehensive error handling
- ✅ Environment variable and file-based configuration

## Development

```bash
# Clone the repository
git clone https://github.com/your-org/cmdstan_elixir.git
cd cmdstan_elixir

# Install dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs
```

## License

This project is licensed under the BSD-3-Clause license, matching the CmdStan license.

