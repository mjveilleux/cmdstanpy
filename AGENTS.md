# CmdStanPy Agent Instructions

This file contains instructions for AI coding agents working on the CmdStanPy codebase. Follow these guidelines to ensure your contributions align with the project's standards and conventions.

## Build, Lint, and Test Commands

### Building and Installation
- **Build package**: `python -m build`
- **Install for development**: `python -m pip install -e .[test]`
- **Install dependencies**: `python -m pip install --upgrade pip wheel build`

### Code Quality Checks
Run these commands before committing changes:

- **Format code**: `black .`
- **Sort imports**: `isort .`
- **Lint with flake8**: `flake8 cmdstanpy test`
- **Lint with pylint**: `pylint -v cmdstanpy test`
- **Type check**: `mypy cmdstanpy test`
- **Pre-commit hooks**: `pre-commit run --all-files`

### Testing
- **Run all tests**: `pytest -v test --cov=cmdstanpy`
- **Run single test file**: `pytest test/test_filename.py -v`
- **Run single test function**: `pytest test/test_filename.py::test_function_name -v`
- **Run tests with coverage**: `pytest -v test --cov=cmdstanpy --cov-report=html`

### Documentation
- **Build docs**: `cd docsrc && make html`
- **Serve docs locally**: `cd docsrc && make github` (updates docs/ directory)

## Code Style Guidelines

### Formatting and Style
- **Code formatter**: Black with 80 character line length
- **Import sorter**: isort with 80 character line length
- **Quote style**: Preserve existing quote style (single or double)
- **No comments**: Do not add comments unless absolutely necessary for clarity

### Naming Conventions
- **Functions/methods**: `snake_case`
- **Variables**: `snake_case`
- **Constants**: `UPPER_CASE`
- **Classes**: `PascalCase`
- **Modules**: `snake_case`
- **Private members**: Prefix with single underscore `_private_method`
- **Bad names to avoid**: `foo`, `bar`, `baz`

### Type Annotations
- **Required**: All functions and methods must have type annotations
- **Strict mypy**: No untyped definitions, incomplete defs, or implicit optionals
- **Return types**: Always specify return types, even for `None`
- **Generic types**: Use proper generic syntax (e.g., `List[str]`, `Dict[str, int]`)
- **Optional types**: Use `Optional[T]` or `T | None` (Python 3.10+)

### Import Organization
Follow isort configuration:
```python
# Standard library imports
import os
import sys
from pathlib import Path

# Third-party imports
import numpy as np
import pandas as pd

# Local imports
from . import utils
from ..model import CmdStanModel
```

### Error Handling
- **Specific exceptions**: Use `ValueError`, `RuntimeError`, `TypeError`, etc. - not generic `Exception`
- **Descriptive messages**: Provide clear, actionable error messages
- **Exception chaining**: Use `raise ... from exc` when re-raising exceptions
- **Validation**: Validate inputs early with descriptive error messages

### Documentation
- **Docstrings**: Required for all public functions, classes, and methods
- **Format**: Google-style docstrings preferred
- **Private functions**: No docstrings needed (regex: `^_|test_.*|Test.*`)
- **Type hints**: Complement docstrings, don't replace them

### Code Structure
- **Max line length**: 80 characters (Black) / 100 characters (Pylint)
- **Max module lines**: 5000
- **Max function statements**: 500
- **Max function arguments**: 25
- **Max local variables**: 15
- **Max branches**: 12
- **Max returns**: 6

### Path Handling
- **Use pathlib**: Prefer `Path` over string path manipulation
- **Cross-platform**: Use `Path` methods for path operations
- **Validation**: Check path existence before operations

### Testing Patterns
- **Test framework**: pytest with extensive parametrization
- **Test naming**: `test_descriptive_name`
- **Fixtures**: Use pytest fixtures for setup/teardown
- **Assertions**: Use specific assertions (`assert isinstance`, `assert raises`, etc.)
- **Coverage**: Aim for high test coverage
- **Mocking**: Use `unittest.mock` for patching

### File Organization
- **Package structure**: `cmdstanpy/` for main code, `test/` for tests
- **Imports**: Relative imports within package, absolute imports from outside
- **__all__**: Define `__all__` in `__init__.py` files for clean public API

### Security
- **No secrets**: Never commit API keys, passwords, or credentials
- **Input validation**: Validate all user inputs
- **Path safety**: Prevent path traversal attacks
- **Command injection**: Sanitize shell commands

### Performance
- **Efficient data structures**: Use appropriate data structures for the task
- **Memory usage**: Be mindful of memory consumption with large datasets
- **Lazy evaluation**: Use generators for large data processing
- **Caching**: Implement caching where appropriate

### Dependencies
- **Minimal deps**: Only add dependencies when absolutely necessary
- **Version pinning**: Pin dependency versions in `pyproject.toml`
- **Optional deps**: Use optional dependency groups for non-core features
- **Import checking**: Verify library availability before use

### Git Workflow
- **Branching**: Follow gitflow - feature branches from `develop`
- **Commits**: Write clear, focused commit messages
- **Pre-commit**: Use pre-commit hooks for automated quality checks
- **PR reviews**: All changes require review before merging

## Common Patterns

### Exception Handling
```python
def validate_input(value: str) -> None:
    if not isinstance(value, str):
        raise TypeError(f"Expected string, got {type(value).__name__}")
    if not value.strip():
        raise ValueError("Input cannot be empty or whitespace only")
```

### Path Operations
```python
from pathlib import Path

def process_file(file_path: str | Path) -> dict:
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")
    # Process file...
```

### Type Hints
```python
from typing import Optional, Union
import numpy as np

def sample_model(
    data: dict,
    chains: int = 4,
    seed: Optional[int] = None
) -> Union[np.ndarray, dict]:
    # Implementation...
```

### Testing
```python
import pytest
import numpy as np

@pytest.mark.parametrize("chains", [1, 2, 4])
def test_sampling_chains(chains: int) -> None:
    result = sample_model({"n": 10}, chains=chains)
    assert result.shape[0] == chains
```

## Quality Assurance

Before submitting changes:
1. Run all linting and type checking
2. Run relevant tests with coverage
3. Ensure no new mypy or pylint errors
4. Verify code formatting
5. Test on multiple Python versions if applicable
6. Update documentation if needed

## Getting Help

- **Contributing guide**: See `CONTRIBUTING.md`
- **Issue tracker**: Use GitHub issues for bugs and features
- **Documentation**: Check `docsrc/` for examples
- **Code review**: Request reviews from maintainers</content>
<parameter name="filePath">AGENTS.md