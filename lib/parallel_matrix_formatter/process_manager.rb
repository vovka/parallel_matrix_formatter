# frozen_string_literal: true

module ParallelMatrixFormatter
  # ProcessManager handles process lifecycle and state management for the orchestrator.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Track process completion status
  # - Generate final test summaries and statistics
  # - Calculate test durations and metrics
  # - Manage process-related state
  #
  class ProcessManager
    def initialize(config, processes, all_failures, start_time)
      @config = config
      @processes = processes
      @all_failures = all_failures
      @start_time = start_time
    end

    # Check if all processes have completed
    # @return [Boolean] True if all processes are completed
    def all_processes_complete?
      @processes.values.all? { |p| p[:status] == :completed }
    end

    # Generate final summary statistics
    # @return [Hash] Summary statistics including test counts and durations
    def generate_final_summary
      # Calculate summary statistics
      total_tests = @processes.values.sum { |p| p[:total_tests] }
      failed_tests = @all_failures.length
      pending_tests = @processes.values.sum do |p|
        p[:test_results].count { |r| r[:status] == :pending }
      end

      total_duration = Time.now - @start_time
      process_durations = @processes.values.map do |p|
        if p[:end_time]
          p[:end_time] - p[:start_time]
        else
          Time.now - p[:start_time]
        end
      end
      process_count = @processes.size

      {
        total_tests: total_tests,
        failed_tests: failed_tests,
        pending_tests: pending_tests,
        total_duration: total_duration,
        process_durations: process_durations,
        process_count: process_count
      }
    end

    # Get failure summary for rendering
    # @return [Array<Hash>] Array of failure details
    def get_failures
      @all_failures
    end
  end
end