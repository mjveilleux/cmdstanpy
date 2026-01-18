

A lightweight Elixir interface to CmdStan, the command-line interface to Stan.


## Installation with Mix

Add `cmdstanex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cmdstanex, "~> 0.1.0"}
  ]
end
```

## Installation with Github

Add `cmdstanex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cmdstanex, git: "https://github.com/mjveilleux/cmdstan_elixir.git"}
  ]
end
```

## Usage

Install the latest version of CmdStan:

```elixir
CmdStan.install_cmdstan()
```

If you want to install a specific version, specify it like this:


```elixir
CmdStan.install_cmdstan(version: "2.32.2")
```


If you have a custom installation directory, specify it like this:

```elixir
CmdStan.install_cmdstan(dir: "/opt/cmdstan", progress: true, verbose: true)
```

### All Installation Options

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

You can run the below in iex

#### Compile and Run the Example
```elixir
# Compile the model
{:ok, model} = CmdStan.compile_model("lib/example/bernoulli.stan")

# Read the json file
{:ok, data} = File.read!("lib/example/data.json") |> Jason.decode!()

# Fit the model with the data (you have all options available in cmdstanex as you do with cmdstan)
{:ok, fit} = CmdStan.sample(model, data, chains: 1, iter: 100)

# We have gradient diagnostics, MCMC diagnostics, and summary available
# CmdStan.diagnose(model, data: data)  # Gradient diagnostics (validate model)
CmdStan.diagnose_fit(fit)             # MCMC diagnostics (check convergence)
CmdStan.summary(fit)                  # Summary statistics

# Also have these options too
IO.inspect(fit.draws["theta"])  # Parameter samples (around 0.3)
IO.inspect(fit.metadata)        # Sampling information
length(fit.draws["theta"])      # Should be 100 samples
```




### Troubleshooting


#### CmdStan Not Found
```elixir
# Install CmdStan first
CmdStan.install_cmdstan(version: "2.37.0")

# Or set path manually
System.put_env("CMDSTAN", "/path/to/cmdstan")
```


## Development

```bash
# Clone the repository
git clone https://github.com/[your-username]/cmdstan_elixir.git
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

