# frozen_string_literal: true

module ParallelMatrixFormatter
  # DefaultConfigProvider provides the default configuration for the parallel matrix formatter.
  # This class was extracted from ConfigLoader to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Define and provide default configuration structure
  # - Manage default paths for configuration files
  # - Ensure configuration consistency across the application
  #
  class DefaultConfigProvider
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
        'rain' => 'green',
        'percent' => 'red',
        'pass' => 'green',
        'fail' => 'red',
        'pending' => 'yellow'
      },
      'fade_effect' => {
        'enabled' => true,
        'fade_levels' => 5,
        'bright_positions' => [1, 2, 3]
      },
      'display' => {
        'column_width' => 12,
        'show_time_digits' => false,
        'rain_density' => 0.7
      },
      'update' => {
        'percent_thresholds' => [5, 10, 20, 25, 50, 75, 80, 90, 95, 100],
        'interval_seconds' => nil
      },
      'environment' => {
        'force_orchestrator' => false,
        'server_path' => nil,
        'is_parallel' => false
      },
      'suppression' => {
        'level' => 'auto',
        'no_suppress' => false,
        'respect_debug' => false
      },
      'ipc' => {
        'mode' => 'auto',
        'prefer_unix_socket' => true,
        'server_path' => nil,
        'temp_dir' => nil,
        'connection_timeout' => 5.0,
        'retry_attempts' => 50,
        'retry_delay' => 0.1,
        'orchestrator_lock_file' => nil,
        'server_path_file' => nil
      }
    }.freeze

    # Get the default configuration
    # @return [Hash] Default configuration structure
    def self.get_default_config
      DEFAULT_CONFIG
    end

    # Get default configuration file paths
    # @return [Array<String>] Array of default config file paths
    def self.get_default_paths
      DEFAULT_CONFIG_PATHS
    end
  end
end