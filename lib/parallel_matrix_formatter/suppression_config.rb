# frozen_string_literal: true

module ParallelMatrixFormatter
  # SuppressionConfig handles determination of the appropriate suppression level
  # based on configuration and runtime context. This class centralizes the logic
  # for deciding which suppression level should be active.
  #
  # Suppression Levels:
  # ==================
  # - none (0): No suppression at all
  # - ruby_warnings (1): Suppress Ruby warning messages ($VERBOSE = nil)
  # - app_warnings (2): Reserved for future application warning suppression
  # - app_output (3): Suppress application stderr output
  # - gem_output (4): Suppress stdout output (gem and application stdout)
  # - all (5): Suppress all output (stdout and stderr) unless debug mode is active
  # - runner (6): Complete suppression for test runners, ignores debug mode
  #
  # Configuration Options:
  # =====================
  # - suppression.level: Explicit level override ('auto', 'none', 'ruby_warnings', etc.)
  # - suppression.no_suppress: Disable all suppression when true
  # - suppression.respect_debug: When true, respects debug environment variables
  #
  class SuppressionConfig
    # Map of level names to numeric values for easy comparison
    SUPPRESSION_LEVELS = {
      none: 0,
      ruby_warnings: 1,
      app_warnings: 2,
      app_output: 3,
      gem_output: 4,
      all: 5,
      runner: 6
    }.freeze

    def initialize(config)
      @config = config
    end

    # Determine the appropriate suppression level based on configuration and context
    # @param is_orchestrator [Boolean] Whether this process is the orchestrator
    # @param is_runner [Boolean] Whether this process is a test runner
    # @return [Symbol] The suppression level to use
    def determine_level(is_orchestrator: false, is_runner: false)
      # If suppression is explicitly disabled, return none
      return :none if suppression_disabled?

      # If explicit level is set and not 'auto', use it
      explicit_level = @config.dig('suppression', 'level')
      if explicit_level && explicit_level != 'auto' && SUPPRESSION_LEVELS.key?(explicit_level.to_sym)
        return explicit_level.to_sym
      end

      # Auto-determination based on role
      if is_runner
        :runner  # Runners always use complete suppression
      elsif is_orchestrator
        :all     # Orchestrators use full suppression but respect debug mode
      else
        :all     # Default to full suppression for other processes
      end
    end

    # Check if suppression should be skipped entirely
    # @return [Boolean] True if suppression should be disabled
    def suppression_disabled?
      # Check explicit no_suppress configuration
      return true if @config.dig('suppression', 'no_suppress')

      # Check if debug environment should be respected
      if @config.dig('suppression', 'respect_debug')
        # Additional debug environment variables are already processed
        # by ConfigLoader and stored in no_suppress
        return @config.dig('suppression', 'no_suppress')
      end

      false
    end

    # Get the numeric level value for a given level symbol
    # @param level [Symbol] The suppression level
    # @return [Integer] The numeric level value
    def level_value(level)
      SUPPRESSION_LEVELS[level] || 0
    end

    # Check if a level suppresses Ruby warnings
    # @param level [Symbol] The suppression level
    # @return [Boolean] True if this level suppresses Ruby warnings
    def suppresses_ruby_warnings?(level)
      level_value(level) >= SUPPRESSION_LEVELS[:ruby_warnings]
    end

    # Check if a level suppresses stderr
    # @param level [Symbol] The suppression level
    # @return [Boolean] True if this level suppresses stderr
    def suppresses_stderr?(level)
      level_value(level) >= SUPPRESSION_LEVELS[:app_output]
    end

    # Check if a level suppresses stdout
    # @param level [Symbol] The suppression level
    # @return [Boolean] True if this level suppresses stdout
    def suppresses_stdout?(level)
      level_value(level) >= SUPPRESSION_LEVELS[:gem_output]
    end

    # Check if this is complete suppression (ignores debug mode)
    # @param level [Symbol] The suppression level
    # @return [Boolean] True if this is complete suppression
    def complete_suppression?(level)
      level_value(level) >= SUPPRESSION_LEVELS[:runner]
    end
  end
end