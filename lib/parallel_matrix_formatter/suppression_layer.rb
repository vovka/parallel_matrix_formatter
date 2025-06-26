# frozen_string_literal: true

module ParallelMatrixFormatter
  class SuppressionLayer
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

    SUPPRESSION_LEVELS = {
      none: 0,
      ruby_warnings: 1,
      app_warnings: 2,
      app_output: 3,
      gem_output: 4,
      all: 5,
      runner: 6  # Complete suppression for test runners, ignores debug mode
    }.freeze

    # Class-level storage for original IO streams (before any suppression)
    @@original_stdout = nil
    @@original_stderr = nil
    @@original_verbose = nil
    @@io_preserved = false

    def self.suppress(level = :all)
      new(level).suppress
    end

    def self.restore
      @instance&.restore
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
    def self.suppress_runner_output
      preserve_original_io unless @@io_preserved
      
      # For runners, always suppress output completely regardless of debug mode
      $stdout = NullIO.new
      $stderr = NullIO.new
      $VERBOSE = nil
    end

    def initialize(level = :all)
      @level = level.is_a?(Symbol) ? SUPPRESSION_LEVELS[level] : level
      @original_stdout = nil
      @original_stderr = nil
      @original_verbose = nil
      @suppressed = false
    end

    def suppress
      return if @suppressed || should_skip_suppression?

      # Preserve original IO at class level if not already done
      self.class.preserve_original_io

      @original_stdout = $stdout
      @original_stderr = $stderr
      @original_verbose = $VERBOSE

      $VERBOSE = nil if @level >= 1

      $stderr = NullIO.new if @level >= 3

      $stdout = NullIO.new if @level >= 4

      if @level >= 5
        $stdout = NullIO.new
        # Only suppress stderr if debug mode is not enabled
        unless ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
          $stderr = NullIO.new
        end
        $VERBOSE = nil
      end

      # Level 6 (runner) - Complete suppression regardless of debug mode
      if @level >= 6
        $stdout = NullIO.new
        $stderr = NullIO.new
        $VERBOSE = nil
      end

      @suppressed = true
      self.class.instance_variable_set(:@instance, self)
    end

    def restore
      return unless @suppressed

      $stdout = @original_stdout if @original_stdout
      $stderr = @original_stderr if @original_stderr
      $VERBOSE = @original_verbose unless @original_verbose.nil?

      @suppressed = false
      self.class.instance_variable_set(:@instance, nil)
    end

    private

    def should_skip_suppression?
      # Check various environment variables that might indicate we should not suppress output
      # Only skip suppression if explicitly disabled, not for general debug flags
      env_vars = %w[
        PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS
      ]

      # Only check for general debug flags if explicitly enabled
      if ENV['PARALLEL_MATRIX_FORMATTER_RESPECT_DEBUG']
        env_vars += %w[DEBUG VERBOSE CI_DEBUG RUNNER_DEBUG]
      end

      env_vars.any? { |var| ENV.fetch(var, nil) && ENV[var] != 'false' }
    end
  end
end
