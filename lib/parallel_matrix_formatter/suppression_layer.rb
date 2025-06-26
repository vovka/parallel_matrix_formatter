# frozen_string_literal: true

require_relative 'suppression_config'

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
  #   layer = SuppressionLayer.new(config, level: :all)
  #   layer.suppress
  #   
  #   # Restore original output
  #   layer.restore
  #
  #   # Class-level convenience methods
  #   SuppressionLayer.suppress_with_config(config, level: :runner)
  #   SuppressionLayer.restore_all
  #
  class SuppressionLayer
    # Class-level storage for original IO streams (before any suppression)
    @@original_stdout = nil
    @@original_stderr = nil
    @@original_verbose = nil
    @@io_preserved = false

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
      return if @@io_preserved
      
      @@original_stdout = $stdout
      @@original_stderr = $stderr
      @@original_verbose = $VERBOSE
      @@io_preserved = true
    end

    # Get original stdout for orchestrator use
    def self.original_stdout
      preserve_original_io unless @@io_preserved
      @@original_stdout
    end

    # Get original stderr for orchestrator use  
    def self.original_stderr
      preserve_original_io unless @@io_preserved
      @@original_stderr
    end

    # Apply role-based suppression - always suppress for runners
    # This method is kept for backward compatibility but uses config internally
    def self.suppress_runner_output(config = nil)
      preserve_original_io unless @@io_preserved
      
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
      @active_level = if level == :auto
                        @suppression_config.determine_level(
                          is_orchestrator: is_orchestrator,
                          is_runner: is_runner
                        )
                      else
                        level
                      end

      # Preserve original IO at class level if not already done
      self.class.preserve_original_io

      # Store instance-level original IO for restoration
      @original_stdout = $stdout
      @original_stderr = $stderr
      @original_verbose = $VERBOSE

      # Apply suppression based on determined level
      apply_suppression(@active_level)

      @suppressed = true
      @@active_instance = self
    end

    def restore
      return unless @suppressed

      $stdout = @original_stdout if @original_stdout
      $stderr = @original_stderr if @original_stderr
      $VERBOSE = @original_verbose unless @original_verbose.nil?

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

    # NullIO class for redirecting output to nowhere
    class NullIO
      def write(*args); end
      def puts(*args); end
      def print(*args); end
      def printf(*args); end
      def flush; end
      def sync=(*args); end
      def close; end

      def closed?
        false
      end

      def tty?
        false
      end
    end
  end
end
