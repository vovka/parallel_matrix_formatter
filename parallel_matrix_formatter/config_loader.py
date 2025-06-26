"""
Centralized Configuration Loader for Parallel Matrix Formatter.

This module provides a centralized configuration management system that handles
both YAML configuration files and environment variables. It ensures that all
configuration access is controlled through a single entry point and produces
frozen configuration objects for immutable settings.

Environment Variables:
    PMF_CONFIG_FILE: Path to the YAML configuration file (default: config.yaml)
    PMF_LOG_LEVEL: Logging level (default: INFO)
    PMF_PARALLEL_WORKERS: Number of parallel workers (default: 4)
    PMF_MAX_MATRIX_SIZE: Maximum matrix size to process (default: 10000)
    PMF_OUTPUT_FORMAT: Output format for matrices (default: json)
    PMF_CACHE_ENABLED: Enable/disable caching (default: true)
    PMF_CACHE_TTL: Cache time-to-live in seconds (default: 3600)
    PMF_DEBUG_MODE: Enable debug mode (default: false)

YAML Configuration Keys:
    logging:
        level: Logging level (INFO, DEBUG, WARNING, ERROR)
        format: Log message format string
    
    parallel:
        workers: Number of parallel workers
        chunk_size: Size of data chunks for parallel processing
    
    matrix:
        max_size: Maximum matrix size to process
        default_precision: Default decimal precision for calculations
    
    output:
        format: Output format (json, csv, xml)
        compression: Enable output compression
    
    cache:
        enabled: Enable/disable caching
        ttl: Cache time-to-live in seconds
        backend: Cache backend (memory, redis)
    
    debug:
        enabled: Enable debug mode
        profiling: Enable performance profiling
"""

import os
import yaml
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, Union
from pathlib import Path


@dataclass(frozen=True)
class LoggingConfig:
    """Configuration for logging settings."""
    level: str = "INFO"
    format: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"


@dataclass(frozen=True)
class ParallelConfig:
    """Configuration for parallel processing settings."""
    workers: int = 4
    chunk_size: int = 1000


@dataclass(frozen=True)
class MatrixConfig:
    """Configuration for matrix processing settings."""
    max_size: int = 10000
    default_precision: int = 2


@dataclass(frozen=True)
class OutputConfig:
    """Configuration for output formatting settings."""
    format: str = "json"
    compression: bool = False


@dataclass(frozen=True)
class CacheConfig:
    """Configuration for caching settings."""
    enabled: bool = True
    ttl: int = 3600
    backend: str = "memory"


@dataclass(frozen=True)
class DebugConfig:
    """Configuration for debugging settings."""
    enabled: bool = False
    profiling: bool = False


@dataclass(frozen=True)
class Config:
    """
    Immutable configuration object containing all application settings.
    
    This frozen dataclass ensures that configuration values cannot be modified
    after initialization, providing a safe way to pass configuration throughout
    the application.
    """
    logging: LoggingConfig = field(default_factory=LoggingConfig)
    parallel: ParallelConfig = field(default_factory=ParallelConfig)
    matrix: MatrixConfig = field(default_factory=MatrixConfig)
    output: OutputConfig = field(default_factory=OutputConfig)
    cache: CacheConfig = field(default_factory=CacheConfig)
    debug: DebugConfig = field(default_factory=DebugConfig)


class ConfigLoader:
    """
    Centralized configuration loader that handles YAML files and environment variables.
    
    This class is responsible for loading configuration from multiple sources and
    merging them into a single, immutable configuration object. It follows the
    principle of centralized configuration management where all configuration
    access is controlled through this single entry point.
    
    Environment variables take precedence over YAML configuration values.
    """
    
    # Default configuration file path
    DEFAULT_CONFIG_FILE = "config.yaml"
    
    # Environment variable prefix for this application
    ENV_PREFIX = "PMF_"
    
    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize the configuration loader.
        
        Args:
            config_file: Path to the YAML configuration file. If None, uses
                        the PMF_CONFIG_FILE environment variable or default.
        """
        self._config_file = self._get_config_file_path(config_file)
        self._yaml_config = self._load_yaml_config()
        self._env_config = self._load_env_config()
    
    def _get_config_file_path(self, config_file: Optional[str]) -> str:
        """
        Determine the configuration file path from multiple sources.
        
        Priority order:
        1. Explicitly provided config_file parameter
        2. PMF_CONFIG_FILE environment variable
        3. Default config.yaml
        
        Args:
            config_file: Explicitly provided config file path
            
        Returns:
            Path to the configuration file
        """
        if config_file:
            return config_file
        
        env_config_file = os.getenv(f"{self.ENV_PREFIX}CONFIG_FILE")
        if env_config_file:
            return env_config_file
            
        return self.DEFAULT_CONFIG_FILE
    
    def _load_yaml_config(self) -> Dict[str, Any]:
        """
        Load configuration from YAML file.
        
        Returns:
            Dictionary containing YAML configuration, empty dict if file not found
        """
        config_path = Path(self._config_file)
        
        if not config_path.exists():
            # Return empty config if file doesn't exist
            return {}
        
        try:
            with open(config_path, 'r', encoding='utf-8') as file:
                config = yaml.safe_load(file) or {}
                return config
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML configuration file: {e}")
        except IOError as e:
            raise IOError(f"Cannot read configuration file: {e}")
    
    def _load_env_config(self) -> Dict[str, Any]:
        """
        Load configuration from environment variables.
        
        All environment variables with the PMF_ prefix are loaded and
        converted to the appropriate data types.
        
        Returns:
            Dictionary containing environment configuration
        """
        env_config = {}
        
        # Load specific environment variables with type conversion
        env_mappings = {
            f"{self.ENV_PREFIX}LOG_LEVEL": ("logging", "level", str),
            f"{self.ENV_PREFIX}PARALLEL_WORKERS": ("parallel", "workers", int),
            f"{self.ENV_PREFIX}MAX_MATRIX_SIZE": ("matrix", "max_size", int),
            f"{self.ENV_PREFIX}OUTPUT_FORMAT": ("output", "format", str),
            f"{self.ENV_PREFIX}CACHE_ENABLED": ("cache", "enabled", self._str_to_bool),
            f"{self.ENV_PREFIX}CACHE_TTL": ("cache", "ttl", int),
            f"{self.ENV_PREFIX}DEBUG_MODE": ("debug", "enabled", self._str_to_bool),
        }
        
        for env_var, (section, key, type_converter) in env_mappings.items():
            value = os.getenv(env_var)
            if value is not None:
                try:
                    converted_value = type_converter(value)
                    if section not in env_config:
                        env_config[section] = {}
                    env_config[section][key] = converted_value
                except (ValueError, TypeError) as e:
                    raise ValueError(f"Invalid value for {env_var}: {value} ({e})")
        
        return env_config
    
    def _str_to_bool(self, value: str) -> bool:
        """
        Convert string to boolean value.
        
        Args:
            value: String value to convert
            
        Returns:
            Boolean representation of the string
            
        Raises:
            ValueError: If the string cannot be converted to boolean
        """
        if value.lower() in ('true', '1', 'yes', 'on'):
            return True
        elif value.lower() in ('false', '0', 'no', 'off'):
            return False
        else:
            raise ValueError(f"Cannot convert '{value}' to boolean")
    
    def _merge_configs(self, yaml_config: Dict[str, Any], env_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Merge YAML and environment configurations with environment taking precedence.
        
        Args:
            yaml_config: Configuration loaded from YAML file
            env_config: Configuration loaded from environment variables
            
        Returns:
            Merged configuration dictionary
        """
        merged = yaml_config.copy()
        
        # Deep merge environment config over YAML config
        for section, values in env_config.items():
            if section not in merged:
                merged[section] = {}
            merged[section].update(values)
        
        return merged
    
    def _create_config_objects(self, config_dict: Dict[str, Any]) -> Config:
        """
        Create typed configuration objects from the merged configuration dictionary.
        
        Args:
            config_dict: Merged configuration dictionary
            
        Returns:
            Immutable Config object with all settings
        """
        # Extract sections with defaults
        logging_config = config_dict.get('logging', {})
        parallel_config = config_dict.get('parallel', {})
        matrix_config = config_dict.get('matrix', {})
        output_config = config_dict.get('output', {})
        cache_config = config_dict.get('cache', {})
        debug_config = config_dict.get('debug', {})
        
        return Config(
            logging=LoggingConfig(**logging_config),
            parallel=ParallelConfig(**parallel_config),
            matrix=MatrixConfig(**matrix_config),
            output=OutputConfig(**output_config),
            cache=CacheConfig(**cache_config),
            debug=DebugConfig(**debug_config)
        )
    
    def load_config(self) -> Config:
        """
        Load and merge configuration from all sources to create a frozen Config object.
        
        This method combines YAML configuration and environment variables,
        giving precedence to environment variables, and returns an immutable
        configuration object.
        
        Returns:
            Frozen Config object containing all application settings
            
        Raises:
            ValueError: If configuration values are invalid
            IOError: If configuration file cannot be read
        """
        # Merge configurations with environment taking precedence
        merged_config = self._merge_configs(self._yaml_config, self._env_config)
        
        # Create and return frozen config object
        return self._create_config_objects(merged_config)


# Singleton instance for global configuration access
_config_loader: Optional[ConfigLoader] = None
_config: Optional[Config] = None


def get_config_loader(config_file: Optional[str] = None) -> ConfigLoader:
    """
    Get the singleton ConfigLoader instance.
    
    Args:
        config_file: Path to configuration file (only used on first call)
        
    Returns:
        ConfigLoader instance
    """
    global _config_loader
    if _config_loader is None:
        _config_loader = ConfigLoader(config_file)
    return _config_loader


def get_config(config_file: Optional[str] = None) -> Config:
    """
    Get the application configuration.
    
    This is the primary entry point for accessing configuration throughout
    the application. It ensures that configuration is loaded only once and
    provides a consistent interface for all components.
    
    Args:
        config_file: Path to configuration file (only used on first call)
        
    Returns:
        Frozen Config object containing all application settings
    """
    global _config
    if _config is None:
        loader = get_config_loader(config_file)
        _config = loader.load_config()
    return _config


def reset_config():
    """
    Reset the global configuration state.
    
    This function is primarily used for testing purposes to ensure
    clean state between test runs.
    """
    global _config_loader, _config
    _config_loader = None
    _config = None