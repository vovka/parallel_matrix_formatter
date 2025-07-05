# frozen_string_literal: true

module ParallelMatrixFormatter
  # Collects summary data from parallel test processes
  class SummaryCollector
    def initialize(total_processes)
      @total_processes = total_processes
      @process_summaries = {}
    end

    def collect(process_number, summary_data)
      @process_summaries[process_number] = summary_data
    end

    def all_summaries_received?
      expected_processes = (1..@total_processes).to_a
      expected_processes.all? { |process| @process_summaries.key?(process) }
    end

    def process_summaries
      @process_summaries
    end

    def missing_processes
      expected_processes = (1..@total_processes).to_a
      expected_processes - @process_summaries.keys
    end
  end
end