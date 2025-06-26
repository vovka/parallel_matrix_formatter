# Parallel Matrix Formatter

A Python application demonstrating centralized configuration management for processing matrices in parallel.

## Overview

This project showcases a robust configuration management pattern where all configuration and environment variable handling is centralized in a single `ConfigLoader` class. This approach ensures consistency, maintainability, and eliminates scattered environment variable access throughout the codebase.

## Key Features

- **Centralized Configuration**: All configuration access goes through a single `ConfigLoader` class
- **Immutable Config Objects**: Configuration is provided as frozen dataclasses to prevent accidental modification
- **Environment Variable Override**: Environment variables take precedence over YAML configuration
- **Type Safety**: Automatic type conversion and validation for configuration values
- **Comprehensive Documentation**: All configuration keys are documented at the module level

## Architecture

### Configuration Precedence

1. **Environment Variables** (highest priority)
2. **YAML Configuration File**
3. **Default Values** (lowest priority)

### Configuration Sources

#### Environment Variables

All environment variables use the `PMF_` prefix:

- `PMF_CONFIG_FILE`: Path to YAML configuration file
- `PMF_LOG_LEVEL`: Logging level (INFO, DEBUG, WARNING, ERROR)
- `PMF_PARALLEL_WORKERS`: Number of parallel workers
- `PMF_MAX_MATRIX_SIZE`: Maximum matrix size to process
- `PMF_OUTPUT_FORMAT`: Output format (json, csv)
- `PMF_CACHE_ENABLED`: Enable/disable caching (true/false)
- `PMF_CACHE_TTL`: Cache time-to-live in seconds
- `PMF_DEBUG_MODE`: Enable debug mode (true/false)

#### YAML Configuration

The application supports YAML configuration files with the following structure:

```yaml
logging:
  level: "INFO"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

parallel:
  workers: 4
  chunk_size: 1000

matrix:
  max_size: 10000
  default_precision: 2

output:
  format: "json"
  compression: false

cache:
  enabled: true
  ttl: 3600
  backend: "memory"

debug:
  enabled: false
  profiling: false
```

## Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Install the package in development mode
pip install -e .
```

## Usage

### Basic Usage

```python
from parallel_matrix_formatter.config_loader import get_config
from parallel_matrix_formatter.matrix_processor import create_formatter

# Load centralized configuration
config = get_config()

# Create components with the shared config
formatter = create_formatter()

# Use the formatter
matrices = [...]  # Your matrix data
results = formatter.process_matrices(matrices)
```

### Running the Example

```bash
# Run with default configuration
python -m parallel_matrix_formatter.main

# Run with environment variable overrides
PMF_OUTPUT_FORMAT=csv PMF_PARALLEL_WORKERS=8 python -m parallel_matrix_formatter.main

# Run with custom config file
PMF_CONFIG_FILE=my_config.yaml python -m parallel_matrix_formatter.main
```

### Configuration in Components

Components receive configuration through the `Config` object instead of accessing environment variables directly:

```python
class MyComponent:
    def __init__(self, config: Config):
        self._config = config
        
        # Use config instead of os.getenv()
        log_level = self._config.logging.level
        workers = self._config.parallel.workers
        
        # No direct environment variable access!
        # Don't do: os.getenv('PMF_LOG_LEVEL')
```

## Testing

```bash
# Run unit tests
python -m unittest tests.test_config_loader -v

# Test with different configurations
PMF_CACHE_ENABLED=false python -m unittest tests.test_config_loader.TestConfigLoader.test_boolean_conversion
```

## Configuration Benefits

### Before (Anti-pattern)
```python
class SomeClass:
    def __init__(self):
        # Scattered ENV access throughout codebase
        self.workers = int(os.getenv('WORKERS', '4'))
        self.log_level = os.getenv('LOG_LEVEL', 'INFO')
        self.cache_ttl = int(os.getenv('CACHE_TTL', '3600'))
```

### After (Centralized pattern)
```python
class SomeClass:
    def __init__(self, config: Config):
        # Clean, testable, documented configuration
        self.workers = config.parallel.workers
        self.log_level = config.logging.level
        self.cache_ttl = config.cache.ttl
```

## Development

### Adding New Configuration

1. **Update environment variable documentation** in `config_loader.py`
2. **Add the field** to the appropriate dataclass
3. **Add environment variable mapping** in `_load_env_config()`
4. **Update the YAML example** in `config.yaml`
5. **Add tests** for the new configuration

### Best Practices

- **Never access `os.environ` directly** outside of `ConfigLoader`
- **Pass `Config` objects** to components that need configuration
- **Use factory functions** to create components with proper configuration
- **Document all configuration keys** in the module docstring
- **Add tests** for new configuration options

## Project Structure

```
parallel_matrix_formatter/
├── parallel_matrix_formatter/
│   ├── __init__.py
│   ├── config_loader.py       # Centralized configuration management
│   ├── matrix_processor.py    # Example component using config
│   ├── cache_manager.py       # Another example component
│   └── main.py               # Application entry point
├── tests/
│   ├── __init__.py
│   └── test_config_loader.py  # Configuration tests
├── config.yaml               # Default configuration
├── requirements.txt          # Python dependencies
├── setup.py                 # Package setup
└── README.md               # This file
```

## Contributing

When adding new features:

1. Follow the centralized configuration pattern
2. Add comprehensive tests
3. Update documentation
4. Ensure no direct environment variable access outside `ConfigLoader`
