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

## Running Models

After installing CmdStan, you can compile and run Stan models directly from Elixir's IEx shell.

### Quick Start: Bernoulli Example

#### Prerequisites
```elixir
# Install CmdStan (run once)
CmdStan.install_cmdstan(version: "2.37.0", progress: true)
```

#### Navigate to Project Directory
```bash
cd cmdstan_elixir
iex -S mix
```

#### Compile and Run the Example
```elixir
# 1. Compile the Bernoulli model
{:ok, model} = CmdStan.compile_model("lib/example/bernoulli.stan")

# 2. Prepare the data
data = %{
  "N" => 10,
  "y" => [0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
}

# 3. Run MCMC sampling
{:ok, fit} = CmdStan.sample(model, data, chains: 1, iter: 100)

# 4. Examine results
IO.inspect(fit.draws["theta"])  # Parameter samples (around 0.3)
IO.inspect(fit.metadata)        # Sampling information
length(fit.draws["theta"])      # Should be 100 samples
```

### Step-by-Step Guide

#### Step 1: Install CmdStan
```elixir
CmdStan.install_cmdstan(version: "2.37.0", progress: true)
```

#### Step 2: Start IEx in Project Directory
```bash
cd cmdstan_elixir
iex -S mix
```

#### Step 3: Compile a Model
```elixir
# For the included example
{:ok, model} = CmdStan.compile_model("lib/example/bernoulli.stan")

# Returns: {:ok, %{name: "bernoulli", exe_file: "/path/to/bernoulli", ...}}
```

#### Step 4: Prepare Data
```elixir
# Inline data
data = %{"N" => 10, "y" => [0, 1, 0, 0, 0, 0, 0, 0, 0, 1]}

# Or load from JSON file
{:ok, data} = File.read!("lib/example/data.json") |> Jason.decode!()
```

#### Step 5: Run MCMC Sampling
```elixir
# Basic sampling
{:ok, fit} = CmdStan.sample(model, data)

# Advanced sampling options
{:ok, fit} = CmdStan.sample(model, data, %{
  chains: 2,        # Number of chains
  iter: 1000,       # Total iterations per chain
  warmup: 500,      # Warmup iterations
  max_treedepth: 10 # HMC tree depth
})
```

#### Step 6: Analyze Results
```elixir
# Access parameter draws
theta_samples = fit.draws["theta"]
length(theta_samples)  # Number of samples

# Calculate summary statistics
mean_theta = Enum.sum(theta_samples) / length(theta_samples)
IO.puts("Mean theta: #{mean_theta}")  # Should be ~0.3

# Check metadata
fit.metadata.chains      # Number of chains
fit.metadata.iterations  # Iterations per chain
fit.parameters           # Parameter names
```

### Custom Models

Compile and run your own Stan models:

```elixir
# Compile your model
{:ok, model} = CmdStan.compile_model("my_model.stan")

# Run with custom data and options
{:ok, fit} = CmdStan.sample(model, my_data,
  chains: 2,
  iter: 1000,
  warmup: 500
)
```

### Loading Data from JSON Files

You can also load data from JSON files:

```elixir
# Read data from JSON file
{:ok, json_content} = File.read!("my_data.json")
{:ok, data} = Jason.decode(json_content)

# Use with sampling
{:ok, fit} = CmdStan.sample(model, data)
```

### Troubleshooting

#### File Not Found Errors
```elixir
# Use absolute paths if relative paths don't work
abs_path = Path.expand("lib/example/bernoulli.stan")
{:ok, model} = CmdStan.compile_model(abs_path)
```

#### CmdStan Not Found
```elixir
# Install CmdStan first
CmdStan.install_cmdstan(version: "2.37.0")

# Or set path manually
System.put_env("CMDSTAN", "/path/to/cmdstan")
```

#### Sampling Takes Too Long
```elixir
# Use fewer iterations for testing
{:ok, fit} = CmdStan.sample(model, data, iter: 100, warmup: 50)
```

#### Poor Convergence
```elixir
# Adjust sampler settings
{:ok, fit} = CmdStan.sample(model, data,
  max_treedepth: 12,
  adapt_delta: 0.95
)
```

Then compile and run the included Bernoulli example:

```elixir
# Compile the Bernoulli model
{:ok, model} = CmdStan.compile_model("lib/example/bernoulli.stan")

# Prepare data
data = %{
  "N" => 10,
  "y" => [0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
}

# Run MCMC sampling
{:ok, fit} = CmdStan.sample(model, data, chains: 1, iter: 100)

# Access results
IO.inspect(fit.draws["theta"])  # Parameter samples
IO.inspect(fit.metadata)        # Sampling information
IO.inspect(fit.diagnostics)     # Basic diagnostics
```

### Custom Models

Compile and run your own Stan models:

```elixir
# Compile your model
{:ok, model} = CmdStan.compile_model("my_model.stan")

# Run with custom data and options
{:ok, fit} = CmdStan.sample(model, my_data,
  chains: 2,
  iter: 1000,
  warmup: 500
)
```

### Loading Data from JSON Files

```elixir
# Read data from JSON file
{:ok, json_content} = File.read!("my_data.json")
{:ok, data} = Jason.decode(json_content)

# Use with sampling
{:ok, fit} = CmdStan.sample(model, data)
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
- ✅ Progress reporting for downloads
- ✅ Model compilation from Stan files
- ✅ MCMC sampling execution
- ✅ CSV result parsing
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

