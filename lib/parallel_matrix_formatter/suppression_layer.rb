# frozen_string_literal: true

require_relative 'suppression_config'
require_relative 'io_manager'

module ParallelMatrixFormatter
  # SuppressionLayer manages output suppression for the parallel matrix formatter.
  # It provides a clean interface for suppressing stdout, stderr, and Ruby warnings
  # based on configuration rather than direct environment variable access.
  #
  # This class ensures only one suppression level is active at a time and provides
  # methods to preserve original IO streams for orchestrator communication.
  #
  # Usage:
  #   # Create and apply suppression
  #   layer = SuppressionLayer.new(config)
  #   layer.suppress(level: :all)
  #   
  #   # Restore original output
  #   layer.restore
  #
  #   # Class-level convenience methods
  #   SuppressionLayer.suppress_with_config(config, level: :runner)
  #   SuppressionLayer.restore_all
  #
  class SuppressionLayer
    # Active suppression instance (ensures only one level active at a time)
    @@active_instance = nil

    def self.suppress_with_config(config, level: :auto, is_orchestrator: false, is_runner: false)
      new(config).suppress(level: level, is_orchestrator: is_orchestrator, is_runner: is_runner)
    end

    def self.restore_all
      @@active_instance&.restore
    end

    # Preserve original IO streams for orchestrator use
    def self.preserve_original_io
      IOManager.preserve_original_io
    end

    # Get original stdout for orchestrator use
    def self.original_stdout
      IOManager.original_stdout
    end

    # Get original stderr for orchestrator use  
    def self.original_stderr
      IOManager.original_stderr
    end

    # Apply role-based suppression - always suppress for runners
    # This method is kept for backward compatibility but uses config internally
    def self.suppress_runner_output(config = nil)
      IOManager.preserve_original_io
      
      # Create minimal config if none provided (for backward compatibility)
      config ||= { 'suppression' => { 'level' => 'runner', 'no_suppress' => false } }
      
      # For runners, always suppress output completely regardless of debug mode
      $stdout = NullIO.new
      $stderr = NullIO.new
      $VERBOSE = nil
    end

    def initialize(config)
      @config = config
      @suppression_config = SuppressionConfig.new(config)
      @original_stdout = nil
      @original_stderr = nil
      @original_verbose = nil
      @suppressed = false
      @active_level = nil
    end

    # Apply suppression based on configuration and context
    # @param level [Symbol] Override suppression level (optional)
    # @param is_orchestrator [Boolean] Whether this process is the orchestrator
    # @param is_runner [Boolean] Whether this process is a test runner
    def suppress(level: :auto, is_orchestrator: false, is_runner: false)
      # Ensure only one suppression layer is active at a time
      if @@active_instance && @@active_instance != self
        @@active_instance.restore
      end

      return if @suppressed || @suppression_config.suppression_disabled?

      # Determine the actual suppression level to use
      @active_level = determine_active_level(level, is_orchestrator, is_runner)

      # Preserve original IO at class level if not already done
      IOManager.preserve_original_io

      # Store instance-level original IO for restoration
      store_current_io

      # Apply suppression based on determined level
      apply_suppression(@active_level)

      @suppressed = true
      @@active_instance = self
    end

    def restore
      return unless @suppressed

      restore_io_streams
      @suppressed = false
      @active_level = nil
      @@active_instance = nil if @@active_instance == self
    end

    # Get the currently active suppression level
    # @return [Symbol, nil] The active suppression level or nil if not suppressed
    def active_level
      @suppressed ? @active_level : nil
    end

    private

    def determine_active_level(level, is_orchestrator, is_runner)
      if level == :auto
        @suppression_config.determine_level(
          is_orchestrator: is_orchestrator,
          is_runner: is_runner
        )
      else
        level
      end
    end

    def store_current_io
      @original_stdout = $stdout
      @original_stderr = $stderr
      @original_verbose = $VERBOSE
    end

    def restore_io_streams
      $stdout = @original_stdout if @original_stdout
      $stderr = @original_stderr if @original_stderr
      $VERBOSE = @original_verbose unless @original_verbose.nil?
    end

    # Apply the specific suppression based on level
    # @param level [Symbol] The suppression level to apply
    def apply_suppression(level)
      # Suppress Ruby warnings
      if @suppression_config.suppresses_ruby_warnings?(level)
        $VERBOSE = nil
      end

      # Suppress stderr (application and gem error output)
      if @suppression_config.suppresses_stderr?(level)
        $stderr = NullIO.new
      end

      # Suppress stdout (application and gem output)
      if @suppression_config.suppresses_stdout?(level)
        $stdout = NullIO.new
      end

      # For complete suppression (runner level), ignore debug mode
      if @suppression_config.complete_suppression?(level)
        $stdout = NullIO.new
        $stderr = NullIO.new
        $VERBOSE = nil
      end
    end
  end
end
