# frozen_string_literal: true

require 'yaml'
require 'pathname'

module ParallelMatrixFormatter
  # YamlConfigLoader handles YAML configuration file loading and parsing.
  # This class was extracted from ConfigLoader to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Find configuration files from default locations
  # - Load and parse YAML configuration files
  # - Handle YAML parsing errors with descriptive messages
  # - Support environment-specified configuration files
  #
  class YamlConfigLoader
    class ConfigError < StandardError; end

    # Find and load YAML configuration from default locations or environment
    # @param default_paths [Array<String>] Default paths to check for config files
    # @return [Hash] Parsed YAML configuration or empty hash if no file found
    def self.load_yaml_config(default_paths)
      config_path = find_config_file(default_paths)
      config_path ? load_config_file(config_path) : {}
    end

    # Find configuration file path from environment or default locations
    # @param default_paths [Array<String>] Default paths to check
    # @return [Pathname, nil] Path to configuration file or nil if not found
    def self.find_config_file(default_paths)
      # Check environment variable first
      if ENV['PARALLEL_MATRIX_FORMATTER_CONFIG']
        path = Pathname.new(ENV['PARALLEL_MATRIX_FORMATTER_CONFIG'])
        return path if path.exist?

        raise ConfigError, "Config file specified in PARALLEL_MATRIX_FORMATTER_CONFIG not found: #{path}"
      end

      # Check default paths
      default_paths.each do |path|
        pathname = Pathname.new(path)
        return pathname if pathname.exist?
      end

      nil
    end

    # Load and parse YAML configuration file
    # @param path [Pathname] Path to configuration file
    # @return [Hash] Parsed configuration
    def self.load_config_file(path)
      YAML.safe_load(File.read(path), aliases: true)
    rescue Psych::SyntaxError => e
      raise ConfigError, "Invalid YAML in config file #{path}: #{e.message}"
    rescue StandardError => e
      raise ConfigError, "Error loading config file #{path}: #{e.message}"
    end
  end
end