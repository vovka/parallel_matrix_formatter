# frozen_string_literal: true

module ParallelMatrixFormatter
  # MessageSender handles message creation and sending for process formatters.
  # This class was extracted from ProcessFormatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Create registration messages for orchestrator
  # - Send progress updates with test results
  # - Send failure details with exception information
  # - Send completion notifications
  # - Handle both direct and IPC message delivery
  #
  class MessageSender
    def initialize(process_id, orchestrator = nil, ipc_connection_manager = nil)
      @process_id = process_id
      @orchestrator = orchestrator
      @ipc_connection_manager = ipc_connection_manager
    end

    # Send registration message to orchestrator
    # @param total_examples [Integer] Total number of test examples
    def send_registration(total_examples)
      message = {
        type: 'register',
        process_id: @process_id,
        total_tests: total_examples,
        timestamp: Time.now.to_f
      }
      send_message(message)
    end

    # Send progress update message
    # @param current_example [Integer] Current example number
    # @param progress_percent [Integer] Progress percentage
    # @param test_result [Hash, nil] Optional test result data
    def send_progress_update(current_example, progress_percent, test_result = nil)
      message = {
        type: 'progress',
        process_id: @process_id,
        current_test: current_example,
        progress_percent: progress_percent,
        timestamp: Time.now.to_f
      }
      message[:test_result] = test_result if test_result
      send_message(message)
    end

    # Send failure details message
    # @param notification [Object] RSpec failure notification
    def send_failure_details(notification)
      exception = notification.exception
      message = {
        type: 'failure',
        process_id: @process_id,
        description: notification.example.full_description,
        location: notification.example.location,
        message: exception ? exception.message : 'Unknown error',
        backtrace: exception ? exception.backtrace : [],
        timestamp: Time.now.to_f
      }
      send_message(message)
    end

    # Send completion message
    def send_completion
      message = {
        type: 'complete',
        process_id: @process_id,
        timestamp: Time.now.to_f
      }
      send_message(message)
    end

    private

    # Send message through either direct or IPC channel
    # @param message [Hash] Message to send
    def send_message(message)
      begin
        if @orchestrator
          # Direct communication - call orchestrator's public handle method
          @orchestrator.handle_direct_message(message)
        elsif @ipc_connection_manager&.connected?
          # IPC communication
          @ipc_connection_manager.send_message(message)
        end
      rescue => e
        # Handle any communication errors silently
      end
    end
  end
end