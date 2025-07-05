# frozen_string_literal: true

module ParallelMatrixFormatter
  # Tracks completion status of parallel test processes
  class ProcessTracker
    def initialize(total_processes)
      @total_processes = total_processes
      @process_completion = {}
    end

    def track_completion(process_number, progress)
      @process_completion[process_number] = progress >= 1.0
    end

    def all_processes_complete?
      return false if @process_completion.empty?
      
      expected_processes = (1..@total_processes).to_a
      completed_processes = completed_process_numbers
      expected_processes.all? { |process| completed_processes.include?(process) }
    end

    private

    def completed_process_numbers
      @process_completion.select { |_, complete| complete }.keys
    end
  end
end