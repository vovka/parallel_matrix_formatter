# frozen_string_literal: true

module ParallelMatrixFormatter
  # Waits for summary data from all processes with timeout handling
  class SummaryWaiter
    def initialize(summary_collector, output, timeout = 30.0)
      @summary_collector = summary_collector
      @output = output
      @timeout = timeout
    end

    def wait_and_render(renderer)
      wait_for_summaries
      handle_missing_summaries
      render_if_available(renderer)
    end

    private

    def wait_for_summaries
      start_time = Time.now
      
      while !@summary_collector.all_summaries_received? && !timeout_reached?(start_time)
        sleep 0.1
      end
    end

    def timeout_reached?(start_time)
      (Time.now - start_time) >= @timeout
    end

    def handle_missing_summaries
      return if @summary_collector.all_summaries_received?
      
      missing_processes = @summary_collector.missing_processes
      @output.puts "\nWarning: Did not receive summaries from process(es): #{missing_processes.join(', ')}"
    end

    def render_if_available(renderer)
      return unless @summary_collector.process_summaries.any?
      
      renderer.render(@summary_collector.process_summaries)
    end
  end
end