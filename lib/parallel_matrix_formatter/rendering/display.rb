# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Turns the orchestrator's events into terminal text. Remembers the latest
    # progress of every process so a progress line can show all of them.
    class Display
      def initialize(config, total_processes)
        @progress = {}
        @policy = ProgressUpdatePolicy.new(config['progress_update'], total_processes)
        @progress_line = ProgressLine.new(config['progress_line'], config['digits'])
        @example_status = ExampleStatus.new(config['example_status'])
        @summary = Summary.new
      end

      # @return [String] the example's status symbol, preceded by a progress line when one is due
      def example(process, status, progress)
        @progress[process] = progress
        line = @policy.update?(@progress) ? @progress_line.render(@progress) : ''
        line + @example_status.render(process, status)
      end

      def summary(summaries, missing_processes)
        @summary.render(summaries, missing_processes)
      end
    end
  end
end
