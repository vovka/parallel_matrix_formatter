# frozen_string_literal: true

module ParallelMatrixFormatter
  # ProcessRegistry handles process registration and state management.
  # This utility was extracted to keep MessageHandler under 100 lines.
  #
  # Key responsibilities:
  # - Create and initialize new process entries
  # - Update existing process state
  # - Manage process completion
  #
  class ProcessRegistry
    def initialize(processes, process_thresholds)
      @processes = processes
      @process_thresholds = process_thresholds
    end

    # Register a new process
    # @param message [Hash] Registration message with process details
    def register_process(message)
      process_id = message['process_id']

      @processes[process_id] = {
        id: process_id, total_tests: message['total_tests'], current_test: 0,
        progress_percent: 0, status: :running, start_time: Time.now,
        end_time: nil, test_results: [], first_completion_shown: false
      }

      @process_thresholds[process_id] = 0
    end

    # Update process progress
    # @param message [Hash] Progress update message
    # @return [Hash, nil] Test result if provided
    def update_process_progress(message)
      process_id = message['process_id']
      process = @processes[process_id]
      return unless process

      process[:current_test] = message['current_test']
      process[:progress_percent] = message['progress_percent']

      # Store test result for later processing
      if message['test_result']
        process[:test_results] << message['test_result']
        return message['test_result']
      end
      nil
    end

    # Mark process as completed
    # @param message [Hash] Completion message
    def complete_process(message)
      process_id = message['process_id']
      process = @processes[process_id]
      return unless process

      process[:status] = :completed
      process[:end_time] = Time.now
      process[:progress_percent] = 100
    end
  end
end