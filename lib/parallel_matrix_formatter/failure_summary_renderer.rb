# frozen_string_literal: true

require_relative 'ansi_colorizer'

module ParallelMatrixFormatter
  # FailureSummaryRenderer handles rendering of test failure summaries and final results.
  # This class was extracted from DigitalRainRenderer to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Render detailed failure information with stack traces
  # - Generate final test summary with counts and timing
  # - Format duration strings in human-readable format
  #
  class FailureSummaryRenderer
    def initialize(config)
      @config = config
    end

    # Render detailed failure summary with descriptions and locations
    # @param failures [Array<Hash>] Array of failure details
    # @return [String] Formatted failure summary
    def render_failure_summary(failures)
      return '' if failures.empty?

      lines = []
      lines << ''
      lines << AnsiColorizer.colorize('FAILED EXAMPLES', 'red')
      lines << ''

      failures.each_with_index do |failure, index|
        lines << AnsiColorizer.colorize("#{index + 1}. #{failure[:description]}", 'red')
        lines << AnsiColorizer.colorize("   Location: #{failure[:location]}", 'cyan') if failure[:location]
        # Split message into lines and indent
        failure[:message]&.split("\n")&.each do |line|
          lines << "   #{line}"
        end
        lines << ''
      end

      lines.join("\n")
    end

    # Render final test summary with statistics and timing information
    # @param total_tests [Integer] Total number of tests
    # @param failed_tests [Integer] Number of failed tests
    # @param pending_tests [Integer] Number of pending tests
    # @param total_duration [Float] Total execution time
    # @param process_durations [Array<Float>] Individual process durations
    # @param process_count [Integer] Number of parallel processes
    # @return [String] Formatted final summary
    def render_final_summary(total_tests, failed_tests, pending_tests, total_duration, process_durations, process_count)
      lines = []
      lines << ''

      # Results summary
      summary_parts = []
      summary_parts << "#{total_tests} examples"
      summary_parts << AnsiColorizer.colorize("#{failed_tests} failures", 'red') if failed_tests.positive?
      summary_parts << "#{pending_tests} pending" if pending_tests.positive?

      lines << summary_parts.join(', ')
      lines << ''

      # Timing information
      lines << "Finished in #{format_duration(total_duration)}"
      
      # Process information
      if process_count > 1
        avg_duration = process_durations.sum / process_durations.size
        lines << "Processes: #{process_count} (avg: #{format_duration(avg_duration)})"
      end

      lines.join("\n")
    end

    private

    # Format duration in a human-readable format
    # @param seconds [Float] Duration in seconds
    # @return [String] Formatted duration string
    def format_duration(seconds)
      if seconds < 1
        "#{(seconds * 1000).round(2)} ms"
      elsif seconds < 60
        "#{seconds.round(2)} seconds"
      else
        minutes = (seconds / 60).to_i
        remaining_seconds = (seconds % 60).round(2)
        "#{minutes}m #{remaining_seconds}s"
      end
    end
  end
end