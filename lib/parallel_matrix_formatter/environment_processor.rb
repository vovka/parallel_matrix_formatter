# frozen_string_literal: true

module ParallelMatrixFormatter
  # EnvironmentProcessor handles environment variable processing and validation.
  # This class was extracted from ConfigLoader to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Process environment variables related to configuration
  # - Detect parallel execution environment
  # - Detect debug environment settings
  # - Convert environment values to appropriate types
  #
  class EnvironmentProcessor
    # Process environment variables and extract configuration
    # @return [Hash] Environment configuration extracted from ENV variables
    def self.process_environment_variables
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

    # Check if environment variable is present (regardless of value)
    # @param var_name [String] Environment variable name
    # @return [Boolean] True if variable is set to any value
    def self.env_present?(var_name)
      !ENV[var_name].nil?
    end

    # Check if environment variable is set to a truthy value
    # @param var_name [String] Environment variable name
    # @return [Boolean] True if variable is set to 'true', '1', 'yes', 'on'
    def self.env_true?(var_name)
      value = ENV[var_name]
      return false if value.nil?

      %w[true 1 yes on].include?(value.downcase)
    end

    # Detect if running in parallel test execution environment
    # @return [Boolean] True if parallel testing is detected
    def self.detect_parallel_execution
      parallel_env_vars = %w[
        PARALLEL_SPLIT_TEST_PROCESSES
        PARALLEL_WORKERS
        TEST_ENV_NUMBER
      ]
      
      parallel_env_vars.any? { |var| env_present?(var) }
    end

    # Detect if running in a debug environment that should disable suppression
    # @return [Boolean] True if debug environment is detected
    def self.detect_debug_environment
      debug_env_vars = %w[DEBUG VERBOSE CI_DEBUG RUNNER_DEBUG]
      debug_env_vars.any? { |var| env_present?(var) && ENV[var] != 'false' }
    end
  end
end