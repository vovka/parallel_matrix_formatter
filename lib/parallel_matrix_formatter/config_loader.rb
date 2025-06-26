# frozen_string_literal: true

require 'yaml'
require 'pathname'

module ParallelMatrixFormatter
  # ConfigLoader centralizes configuration and environment variable handling.
  # This class is responsible for loading YAML configuration files and processing
  # environment variables, producing a frozen configuration object that contains
  # all settings needed by the application components.
  # Simplified version with debug and color logic removed.
  #
  # Environment Variables Handled:
  # ==============================
  # 
  # Configuration:
  # - PARALLEL_MATRIX_FORMATTER_CONFIG: Path to custom YAML config file
  #
  # Process Management:
  # - PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR: Force this process to be orchestrator (true/false)
  # - PARALLEL_MATRIX_FORMATTER_SERVER: IPC server socket path for inter-process communication
  # - PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS: Disable output suppression (true/false)
  # - PARALLEL_MATRIX_FORMATTER_SUPPRESS: Set suppression level (none/ruby_warnings/app_warnings/app_output/gem_output/all/runner)
  #
  # Parallel Testing Detection:
  # - PARALLEL_SPLIT_TEST_PROCESSES: Number of parallel test processes (parallel_split_test)
  # - PARALLEL_WORKERS: Number of parallel workers (parallel_tests gem)
  # - TEST_ENV_NUMBER: Test environment number for parallel execution
  #
  # Note: All debug and color environment variable processing has been removed
  # as part of refactoring to simplify the codebase.
  #
  class ConfigLoader
    class ConfigError < StandardError; end

    DEFAULT_CONFIG_PATHS = [
      'parallel_matrix_formatter.yml',
      'config/parallel_matrix_formatter.yml',
      '.parallel_matrix_formatter.yml'
    ].freeze

    DEFAULT_CONFIG = {
      'digits' => {
        'use_custom' => false,
        'symbols' => '0123456789'
      },
      'katakana_alphabet' => 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン',
      'pass_symbols' => 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン',
      'fail_symbols' => 'ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ',
      'pending_symbol' => '🥄',
      'update' => {
        'interval_seconds' => 1,
        'percent_thresholds' => [5]
      },
      'display' => {
        'column_width' => 15,
        'show_time_digits' => true,
        'rain_density' => 0.7
      },
      # Environment-based runtime configuration
      'environment' => {
        'no_suppress' => false,
        'suppress_level' => nil,
        'force_orchestrator' => false,
        'server_path' => nil,
        'is_parallel' => false
      }
    }.freeze

    # Class method to load and return a frozen configuration object
    # @return [Hash] Frozen configuration hash with all settings

    def self.load
      new.load
    end

    # Load configuration from YAML files and environment variables
    # @return [Hash] Frozen configuration hash containing all settings
    def load
      # Load YAML configuration
      config_path = find_config_file
      yaml_config = config_path ? load_config_file(config_path) : {}
      
      # Merge with defaults and process environment variables
      merged_config = merge_with_defaults(yaml_config)
      env_config = process_environment_variables
      final_config = merge_environment_config(merged_config, env_config)
      
      # Validate and process the final configuration
      validate_config(final_config)
      processed_config = process_config(final_config)
      
      # Return frozen configuration to prevent modification
      freeze_config(processed_config)
    end

    private

    # Find configuration file path from environment or default locations
    # @return [Pathname, nil] Path to configuration file or nil if not found
    def find_config_file
      # Check environment variable first (temporary ENV access during transition)
      if ENV['PARALLEL_MATRIX_FORMATTER_CONFIG']
        path = Pathname.new(ENV['PARALLEL_MATRIX_FORMATTER_CONFIG'])
        return path if path.exist?

        raise ConfigError, "Config file specified in PARALLEL_MATRIX_FORMATTER_CONFIG not found: #{path}"
      end

      # Check default paths
      DEFAULT_CONFIG_PATHS.each do |path|
        pathname = Pathname.new(path)
        return pathname if pathname.exist?
      end

      nil
    end

    # Load and parse YAML configuration file
    # @param path [Pathname] Path to configuration file
    # @return [Hash] Parsed configuration
    # Load and parse YAML configuration file
    # @param path [Pathname] Path to configuration file
    # @return [Hash] Parsed configuration
    def load_config_file(path)
      YAML.safe_load(File.read(path), aliases: true)
    rescue Psych::SyntaxError => e
      raise ConfigError, "Invalid YAML in config file #{path}: #{e.message}"
    rescue StandardError => e
      raise ConfigError, "Error loading config file #{path}: #{e.message}"
    end

    # Merge user configuration with default configuration
    # @param config [Hash] User configuration
    # @return [Hash] Merged configuration with defaults
    def merge_with_defaults(config)
      deep_merge(DEFAULT_CONFIG, config)
    end

    # Validate the final configuration for required sections and constraints
    # @param config [Hash] Configuration to validate
    # @raise [ConfigError] If configuration is invalid
    # Validate the final configuration for required sections and constraints
    # @param config [Hash] Configuration to validate
    # @raise [ConfigError] If configuration is invalid
    def validate_config(config)
      validate_digits_section(config['digits'])
      validate_required_sections(config)
    end

    # Validate the digits section of configuration
    # @param digits_config [Hash] Digits section configuration
    # @raise [ConfigError] If custom digits configuration is invalid
    # Validate the digits section of configuration
    # @param digits_config [Hash] Digits section configuration
    # @raise [ConfigError] If custom digits configuration is invalid
    def validate_digits_section(digits_config)
      return unless digits_config['use_custom']

      symbols = digits_config['symbols']
      return if symbols.nil?

      # Convert to array of characters to handle Unicode properly
      symbol_chars = symbols.chars
      return if symbol_chars.length == 10

      raise ConfigError, "Custom digits must contain exactly 10 symbols, got #{symbol_chars.length}: '#{symbols}'"
    end

    # Validate that required configuration sections are present
    # @param config [Hash] Full configuration
    # @raise [ConfigError] If required sections are missing
    # Validate that required configuration sections are present
    # @param config [Hash] Full configuration
    # @raise [ConfigError] If required sections are missing
    def validate_required_sections(config)
      required_sections = %w[update display]
      required_sections.each do |section|
        next if config[section].is_a?(Hash)

        raise ConfigError, "Missing or invalid '#{section}' section in configuration"
      end
    end

    # Process configuration by converting strings to more usable formats
    # @param config [Hash] Configuration to process
    # @return [Hash] Processed configuration with character arrays and computed values
    def process_config(config)
      # Convert symbol strings to character arrays for easier sampling
      config['katakana_alphabet_chars'] = config['katakana_alphabet'].chars
      config['pass_symbols_chars'] = config['pass_symbols'].chars
      config['fail_symbols_chars'] = config['fail_symbols'].chars

      # Process digits
      config['digits']['symbols_chars'] = if config['digits']['use_custom']
                                            config['digits']['symbols'].chars
                                          else
                                            '0123456789'.chars
                                          end

      config
    end

    # Process all environment variables and return environment configuration
    # @return [Hash] Environment configuration extracted from ENV variables
    def process_environment_variables
      {
        'environment' => {
          'no_suppress' => env_true?('PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS'),
          'suppress_level' => ENV['PARALLEL_MATRIX_FORMATTER_SUPPRESS'],
          'force_orchestrator' => env_true?('PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR'),
          'server_path' => ENV['PARALLEL_MATRIX_FORMATTER_SERVER'],
          'is_parallel' => detect_parallel_execution
        }
      }
    end

    # Merge environment configuration with the main configuration
    # @param main_config [Hash] Main configuration from YAML and defaults
    # @param env_config [Hash] Environment configuration
    # @return [Hash] Merged configuration
    def merge_environment_config(main_config, env_config)
      deep_merge(main_config, env_config)
    end

    # Freeze the configuration object recursively to prevent modifications
    # @param config [Hash] Configuration to freeze
    # @return [Hash] Frozen configuration
    def freeze_config(config)
      case config
      when Hash
        config.each { |k, v| freeze_config(v) }
        config.freeze
      when Array
        config.each { |v| freeze_config(v) }
        config.freeze
      else
        config.freeze if config.respond_to?(:freeze)
      end
    end

    # Check if environment variable is present (regardless of value)
    # @param var_name [String] Environment variable name
    # @return [Boolean] True if variable is set to any value
    def env_present?(var_name)
      !ENV[var_name].nil?
    end

    # Check if environment variable is set to a truthy value
    # @param var_name [String] Environment variable name
    # @return [Boolean] True if variable is set to 'true', '1', 'yes', 'on'
    def env_true?(var_name)
      value = ENV[var_name]
      return false if value.nil?

      %w[true 1 yes on].include?(value.downcase)
    end

    # Detect if running in parallel test execution environment
    # @return [Boolean] True if parallel testing is detected
    def detect_parallel_execution
      parallel_env_vars = %w[
        PARALLEL_SPLIT_TEST_PROCESSES
        PARALLEL_WORKERS
        TEST_ENV_NUMBER
      ]
      
      parallel_env_vars.any? { |var| env_present?(var) }
    end

    # Deep merge two hashes, with second hash taking precedence
    # @param hash1 [Hash] Base hash
    # @param hash2 [Hash] Hash to merge in (takes precedence)
    # @return [Hash] Merged hash
    def deep_merge(hash1, hash2)
      result = hash1.dup
      hash2.each do |key, value|
        result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
                        deep_merge(result[key], value)
                      else
                        value
                      end
      end
      result
    end
  end
end
