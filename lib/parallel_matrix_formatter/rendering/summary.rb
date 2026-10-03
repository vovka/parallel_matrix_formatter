# frozen_string_literal: true

require 'rspec/core/formatters/helpers'

module ParallelMatrixFormatter
  module Rendering
    # Renders the end-of-run report in the style of RSpec's own: every failure
    # of every process, the totals and the commands to rerun the failures.
    class Summary
      Helpers = RSpec::Core::Formatters::Helpers

      def initialize
        @started_at = Time.now
      end

      # @param summaries [Array<Hash>] the summary message of every process that sent one
      # @param missing_processes [Array<Integer>] processes that never sent a summary
      def render(summaries, missing_processes)
        failures = summaries.flat_map { |summary| summary['failed_examples'] }
        sections = [failures_section(failures), warnings(missing_processes), totals(summaries), rerun_section(failures)]
        "\n#{sections.compact.join("\n")}"
      end

      private

      def failures_section(failures)
        return if failures.empty?

        blocks = failures.each_with_index.map { |failure, index| failure_block(failure, index + 1) }
        "\nFailures:\n\n#{blocks.join("\n")}"
      end

      def failure_block(failure, number)
        indent = ' ' * (number.to_s.length + 4)
        details = failure['message_lines'] + failure['backtrace']
        ["  #{number}) #{failure['description']}", *details.map { |line| indent + line }, ''].join("\n")
      end

      def warnings(missing_processes)
        return if missing_processes.empty?

        processes = missing_processes.join(', ')
        "\n#{Colors.wrap("WARNING: no summary received from process #{processes}, it probably crashed. " \
                         'Set suppress_output: false to see its output.', :yellow)}"
      end

      def totals(summaries)
        examples, failures, pending = %w[examples failures pending].map { |key| summaries.sum { |s| s[key] } }
        process_time = Helpers.format_duration(summaries.sum { |summary| summary['duration'] })
        "\nFinished in #{Helpers.format_duration(Time.now - @started_at)} (#{process_time} across processes)\n" +
          Colors.wrap(totals_line(examples, failures, pending), totals_color(failures, pending))
      end

      def totals_line(examples, failures, pending)
        line = "#{Helpers.pluralize(examples, 'example')}, #{Helpers.pluralize(failures, 'failure')}"
        pending.positive? ? "#{line}, #{pending} pending" : line
      end

      def totals_color(failures, pending)
        return :failure if failures.positive?

        pending.positive? ? :pending : :success
      end

      def rerun_section(failures)
        return if failures.empty?

        "\nFailed examples:\n\n#{failures.map { |failure| rerun_command(failure) }.join("\n")}"
      end

      def rerun_command(failure)
        command = Colors.wrap("rspec #{failure['location']}", :failure)
        "#{command} #{Colors.wrap("# #{failure['description']}", :detail)}"
      end
    end
  end
end
