"""Unit tests for the centralized configuration loader."""

import unittest
import os
import tempfile
import yaml
from unittest.mock import patch
from parallel_matrix_formatter.config_loader import (
    ConfigLoader, 
    Config, 
    LoggingConfig, 
    ParallelConfig,
    MatrixConfig,
    OutputConfig,
    CacheConfig,
    DebugConfig,
    get_config,
    reset_config
)


class TestConfigLoader(unittest.TestCase):
    """Test cases for the ConfigLoader class."""
    
    def setUp(self):
        """Set up test environment before each test."""
        # Reset global config state
        reset_config()
        
        # Clean up environment variables
        env_vars_to_clean = [
            'PMF_CONFIG_FILE', 'PMF_LOG_LEVEL', 'PMF_PARALLEL_WORKERS',
            'PMF_MAX_MATRIX_SIZE', 'PMF_OUTPUT_FORMAT', 'PMF_CACHE_ENABLED',
            'PMF_CACHE_TTL', 'PMF_DEBUG_MODE'
        ]
        for var in env_vars_to_clean:
            if var in os.environ:
                del os.environ[var]
    
    def tearDown(self):
        """Clean up after each test."""
        reset_config()
    
    def test_default_config_creation(self):
        """Test that default configuration is created correctly."""
        loader = ConfigLoader()
        config = loader.load_config()
        
        # Test that we get a Config object
        self.assertIsInstance(config, Config)
        
        # Test default values
        self.assertEqual(config.logging.level, "INFO")
        self.assertEqual(config.parallel.workers, 4)
        self.assertEqual(config.matrix.max_size, 10000)
        self.assertEqual(config.output.format, "json")
        self.assertTrue(config.cache.enabled)
        self.assertEqual(config.cache.ttl, 3600)
        self.assertFalse(config.debug.enabled)
    
    def test_yaml_config_loading(self):
        """Test loading configuration from YAML file."""
        # Create temporary YAML config file
        yaml_config = {
            'logging': {'level': 'DEBUG'},
            'parallel': {'workers': 8},
            'matrix': {'max_size': 20000},
            'output': {'format': 'csv'},
            'cache': {'enabled': False, 'ttl': 7200},
            'debug': {'enabled': True}
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_config, f)
            config_file = f.name
        
        try:
            loader = ConfigLoader(config_file)
            config = loader.load_config()
            
            # Test YAML values are loaded
            self.assertEqual(config.logging.level, 'DEBUG')
            self.assertEqual(config.parallel.workers, 8)
            self.assertEqual(config.matrix.max_size, 20000)
            self.assertEqual(config.output.format, 'csv')
            self.assertFalse(config.cache.enabled)
            self.assertEqual(config.cache.ttl, 7200)
            self.assertTrue(config.debug.enabled)
        
        finally:
            os.unlink(config_file)
    
    def test_env_variable_override(self):
        """Test that environment variables override YAML configuration."""
        # Create temporary YAML config file
        yaml_config = {
            'logging': {'level': 'INFO'},
            'parallel': {'workers': 4},
            'cache': {'enabled': True}
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_config, f)
            config_file = f.name
        
        try:
            # Set environment variables
            os.environ['PMF_LOG_LEVEL'] = 'ERROR'
            os.environ['PMF_PARALLEL_WORKERS'] = '12'
            os.environ['PMF_CACHE_ENABLED'] = 'false'
            
            loader = ConfigLoader(config_file)
            config = loader.load_config()
            
            # Test that env vars override YAML
            self.assertEqual(config.logging.level, 'ERROR')
            self.assertEqual(config.parallel.workers, 12)
            self.assertFalse(config.cache.enabled)
        
        finally:
            os.unlink(config_file)
    
    def test_boolean_conversion(self):
        """Test boolean conversion from environment variables."""
        test_cases = [
            ('true', True),
            ('True', True),
            ('1', True),
            ('yes', True),
            ('on', True),
            ('false', False),
            ('False', False),
            ('0', False),
            ('no', False),
            ('off', False),
        ]
        
        for env_value, expected in test_cases:
            with self.subTest(env_value=env_value):
                os.environ['PMF_CACHE_ENABLED'] = env_value
                
                loader = ConfigLoader()
                config = loader.load_config()
                
                self.assertEqual(config.cache.enabled, expected)
                
                # Clean up
                del os.environ['PMF_CACHE_ENABLED']
    
    def test_invalid_boolean_conversion(self):
        """Test that invalid boolean values raise ValueError."""
        os.environ['PMF_CACHE_ENABLED'] = 'invalid'
        
        with self.assertRaises(ValueError):
            loader = ConfigLoader()
    
    def test_invalid_integer_conversion(self):
        """Test that invalid integer values raise ValueError."""
        os.environ['PMF_PARALLEL_WORKERS'] = 'not_a_number'
        
        with self.assertRaises(ValueError):
            loader = ConfigLoader()
    
    def test_config_file_from_env(self):
        """Test loading config file path from environment variable."""
        yaml_config = {'logging': {'level': 'WARNING'}}
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_config, f)
            config_file = f.name
        
        try:
            os.environ['PMF_CONFIG_FILE'] = config_file
            
            loader = ConfigLoader()
            config = loader.load_config()
            
            self.assertEqual(config.logging.level, 'WARNING')
        
        finally:
            os.unlink(config_file)
    
    def test_nonexistent_config_file(self):
        """Test behavior when config file doesn't exist."""
        loader = ConfigLoader('nonexistent.yaml')
        config = loader.load_config()
        
        # Should use defaults when file doesn't exist
        self.assertEqual(config.logging.level, "INFO")
        self.assertEqual(config.parallel.workers, 4)
    
    def test_config_immutability(self):
        """Test that config objects are immutable (frozen)."""
        loader = ConfigLoader()
        config = loader.load_config()
        
        # Attempting to modify should raise an error
        with self.assertRaises(Exception):  # FrozenInstanceError in newer Python versions
            config.logging.level = "DEBUG"
    
    def test_get_config_singleton(self):
        """Test that get_config returns the same instance."""
        config1 = get_config()
        config2 = get_config()
        
        # Should be the same object
        self.assertIs(config1, config2)


class TestConfigClasses(unittest.TestCase):
    """Test cases for configuration dataclasses."""
    
    def test_logging_config_defaults(self):
        """Test LoggingConfig default values."""
        config = LoggingConfig()
        
        self.assertEqual(config.level, "INFO")
        self.assertIn("%(asctime)s", config.format)
        self.assertIn("%(levelname)s", config.format)
    
    def test_parallel_config_defaults(self):
        """Test ParallelConfig default values."""
        config = ParallelConfig()
        
        self.assertEqual(config.workers, 4)
        self.assertEqual(config.chunk_size, 1000)
    
    def test_matrix_config_defaults(self):
        """Test MatrixConfig default values."""
        config = MatrixConfig()
        
        self.assertEqual(config.max_size, 10000)
        self.assertEqual(config.default_precision, 2)
    
    def test_output_config_defaults(self):
        """Test OutputConfig default values."""
        config = OutputConfig()
        
        self.assertEqual(config.format, "json")
        self.assertFalse(config.compression)
    
    def test_cache_config_defaults(self):
        """Test CacheConfig default values."""
        config = CacheConfig()
        
        self.assertTrue(config.enabled)
        self.assertEqual(config.ttl, 3600)
        self.assertEqual(config.backend, "memory")
    
    def test_debug_config_defaults(self):
        """Test DebugConfig default values."""
        config = DebugConfig()
        
        self.assertFalse(config.enabled)
        self.assertFalse(config.profiling)


if __name__ == '__main__':
    unittest.main()