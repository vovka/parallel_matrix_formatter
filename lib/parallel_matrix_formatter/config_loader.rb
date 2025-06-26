# frozen_string_literal: true

require 'yaml'
require 'pathname'
require 'tmpdir'
require 'socket'
require_relative 'ipc_config_processor'
require_relative 'default_config_provider'
require_relative 'environment_processor'
require_relative 'yaml_config_loader'
require_relative 'config_validator'
require_relative 'config_processor'

module ParallelMatrixFormatter
  # ConfigLoader centralizes configuration loading for the parallel matrix formatter.
  # This class coordinates configuration loading by delegating to specialized classes
  # for improved separation of concerns and maintainability.
  #
  # Key responsibilities:
  # - Coordinate the overall configuration loading process
  # - Delegate specific tasks to specialized configuration classes
  # - Provide the main public interface for configuration loading
  #
  class ConfigLoader
    class ConfigError < StandardError; end

    # Class method to load and return a frozen configuration object
    # @return [Hash] Frozen configuration hash with all settings
    def self.load
      new.load
    end

    # Load configuration from YAML files and environment variables
    # @return [Hash] Frozen configuration hash containing all settings
    def load
      # Load YAML configuration
      default_paths = DefaultConfigProvider.get_default_paths
      yaml_config = YamlConfigLoader.load_yaml_config(default_paths)
      
      # Merge with defaults and process environment variables
      default_config = DefaultConfigProvider.get_default_config
      merged_config = ConfigProcessor.deep_merge(default_config, yaml_config)
      env_config = EnvironmentProcessor.process_environment_variables
      final_config = ConfigProcessor.deep_merge(merged_config, env_config)
      
      # Validate and process the final configuration
      ConfigValidator.validate_config(final_config)
      processed_config = ConfigProcessor.process_config(final_config)
      
      # Return frozen configuration to prevent modification
      ConfigProcessor.freeze_config(processed_config)
    end
  end
end