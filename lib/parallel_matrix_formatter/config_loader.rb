# frozen_string_literal: true

require 'yaml'
require 'pathname'
require 'tmpdir'
require 'socket'

module ParallelMatrixFormatter
  # ConfigLoader centralizes configuration loading for the parallel matrix formatter.
  # This class loads YAML configuration files and processes environment variables,
  # producing a frozen configuration object for use by application components.
  #
  # Refactored to remove debug-related environment variable handling as per 
  # issue requirements to eliminate debug logic from the codebase.
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
  #
  # Parallel Testing Detection:
  # - PARALLEL_SPLIT_TEST_PROCESSES: Number of parallel test processes (parallel_split_test)
  # - PARALLEL_WORKERS: Number of parallel workers (parallel_tests gem)
  # - TEST_ENV_NUMBER: Test environment number for parallel execution
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
      'colors' => {
        'time' => 'green',
        'percent' => 'red',
        'rain' => 'green',
        'pass_dot' => 'green',
        'fail_dot' => 'red',
        'pending_dot' => 'white',
        'method' => 'auto'
      },
      'update' => {
        'interval_seconds' => 1,
        'percent_thresholds' => [5]
      },
      'display' => {
        'column_width' => 15,
        'show_time_digits' => true,
        'rain_density' => 0.7
      },
      # Environment-based runtime configuration (simplified, debug variables removed)
      'environment' => {
        'force_orchestrator' => false,
        'server_path' => nil,
        'is_parallel' => false
      },
      # Suppression configuration
      'suppression' => {
        'level' => 'auto',  # auto, none, ruby_warnings, app_warnings, app_output, gem_output, all, runner
        'no_suppress' => false,
        'respect_debug' => false
      },
      # IPC (Inter-Process Communication) configuration
      # All IPC settings are centralized here to eliminate direct ENV access
      # and file-based server discovery except for explicit fallback scenarios
      'ipc' => {
        'mode' => 'auto',              # auto, unix_socket, file_based
        'prefer_unix_socket' => true,  # Prefer Unix sockets when available (not on Windows)
        'server_path' => nil,          # Server socket path or base directory (auto-generated if nil)
        'temp_dir' => nil,             # Base temp directory for IPC files (uses system temp if nil)
        'connection_timeout' => 5.0,   # Timeout in seconds for client connections
        'retry_attempts' => 50,        # Number of connection retry attempts
        'retry_delay' => 0.1,          # Delay between retry attempts in seconds
        'orchestrator_lock_file' => nil, # Path to orchestrator lock file (auto-generated if nil)
        'server_path_file' => nil      # Path to server path file for fallback discovery (auto-generated if nil)
      }
    }.freeze

    # CI environments list removed (no longer needed without color environment detection)

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
      required_sections = %w[colors update display]
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

      # Process IPC configuration - generate paths and validate settings
      process_ipc_config(config)

      config
    end

    # Process environment variables (simplified, debug and color vars removed)
    # @return [Hash] Environment configuration extracted from ENV variables
    def process_environment_variables
      {
        'environment' => {
          'force_orchestrator' => env_true?('PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR'),
          'server_path' => ENV['PARALLEL_MATRIX_FORMATTER_SERVER'],
          'is_parallel' => detect_parallel_execution
        },
        'suppression' => {
          'no_suppress' => env_true?('PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS') || 
                          detect_debug_environment,
          'respect_debug' => env_true?('PARALLEL_MATRIX_FORMATTER_RESPECT_DEBUG')
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

    # Process IPC configuration by generating default paths and validating settings
    # This method centralizes all IPC path generation and configuration processing
    # to eliminate scattered path generation throughout the codebase
    # @param config [Hash] Configuration to process
    def process_ipc_config(config)
      ipc_config = config['ipc']
      
      # Set default temp directory if not specified
      ipc_config['temp_dir'] ||= Dir.tmpdir
      
      # Generate default server path if not specified
      # Use environment server path if provided, otherwise generate default
      if config['environment']['server_path']
        ipc_config['server_path'] = config['environment']['server_path']
      elsif ipc_config['server_path'].nil?
        # Generate appropriate default path based on mode preference
        if ipc_config['prefer_unix_socket'] && unix_socket_supported?
          ipc_config['server_path'] = File.join(ipc_config['temp_dir'], "parallel_matrix_formatter_#{Process.pid}.sock")
        else
          ipc_config['server_path'] = File.join(ipc_config['temp_dir'], "parallel_matrix_formatter_#{Process.pid}")
        end
      end
      
      # Generate orchestrator lock file path if not specified
      ipc_config['orchestrator_lock_file'] ||= File.join(ipc_config['temp_dir'], 'parallel_matrix_formatter_orchestrator.lock')
      
      # Generate server path file for fallback discovery if not specified
      ipc_config['server_path_file'] ||= File.join(ipc_config['temp_dir'], 'parallel_matrix_formatter_server.path')
      
      # Validate and process mode setting
      case ipc_config['mode']
      when 'auto'
        # Auto mode: prefer unix_socket if supported and preferred, otherwise file_based
        ipc_config['resolved_mode'] = if ipc_config['prefer_unix_socket'] && unix_socket_supported?
                                        'unix_socket'
                                      else
                                        'file_based'
                                      end
      when 'unix_socket'
        unless unix_socket_supported?
          # Fall back to file_based if unix_socket not supported
          ipc_config['resolved_mode'] = 'file_based'
        else
          ipc_config['resolved_mode'] = 'unix_socket'
        end
      when 'file_based'
        ipc_config['resolved_mode'] = 'file_based'
      else
        raise ConfigError, "Invalid IPC mode '#{ipc_config['mode']}'. Must be 'auto', 'unix_socket', or 'file_based'"
      end
      
      # Ensure paths are absolute
      %w[server_path temp_dir orchestrator_lock_file server_path_file].each do |path_key|
        ipc_config[path_key] = File.expand_path(ipc_config[path_key]) if ipc_config[path_key]
      end
    end

    # Check if Unix sockets are supported on this platform
    # @return [Boolean] True if Unix sockets are supported
    def unix_socket_supported?
      # Check if Unix sockets are supported (not on Windows in general)
      !Gem.win_platform? && defined?(UNIXSocket)
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

    # Detect if running in a debug environment that should disable suppression
    # @return [Boolean] True if debug environment is detected
    def detect_debug_environment
      debug_env_vars = %w[DEBUG VERBOSE CI_DEBUG RUNNER_DEBUG]
      debug_env_vars.any? { |var| env_present?(var) && ENV[var] != 'false' }
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
