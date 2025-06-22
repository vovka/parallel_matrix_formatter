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
      all: 5
    }.freeze

    def self.suppress(level = :all)
      new(level).suppress
    end

    def self.restore
      @instance&.restore
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
