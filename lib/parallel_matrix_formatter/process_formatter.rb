# frozen_string_literal: true

require_relative 'ipc'
require_relative 'suppression_layer'
require_relative 'ipc_connection_manager'
require_relative 'progress_tracker'
require_relative 'message_sender'

module ParallelMatrixFormatter
  # ProcessFormatter handles test progress reporting from individual test processes
  # to the orchestrator via either direct method calls or IPC.
  class ProcessFormatter
    def initialize(config, process_id = nil, orchestrator = nil)
      @config = config
      @process_id = process_id || Process.pid
      @orchestrator = orchestrator
      @connected = false
      @progress_tracker = nil
      @message_sender = nil
      @ipc_connection_manager = nil
      apply_runner_suppression
    end

    def start(total_examples)
      @progress_tracker = ProgressTracker.new(@config, total_examples)
      
      if @orchestrator
        @connected = true
        @message_sender = MessageSender.new(@process_id, @orchestrator)
      else
        @ipc_connection_manager = IpcConnectionManager.new(@config)
        @connected = @ipc_connection_manager.connect_to_orchestrator
        @message_sender = MessageSender.new(@process_id, nil, @ipc_connection_manager)
      end
      
      register_with_orchestrator if @connected
    end

    def example_started(_notification)
      @progress_tracker.increment_example
      send_progress_update
    end

    def example_passed(notification)
      send_test_result(notification, :passed)
    end

    def example_failed(notification)
      send_test_result(notification, :failed)
      @message_sender.send_failure_details(notification) if @connected
    end

    def example_pending(notification)
      send_test_result(notification, :pending)
    end

    def stop
      @message_sender.send_completion if @connected
      @ipc_connection_manager&.close
    end

    private

    def register_with_orchestrator
      return unless @connected
      @message_sender.send_registration(@progress_tracker.total_examples)
    end

    def send_progress_update
      return unless @connected
      progress_percent = @progress_tracker.calculate_progress_percent
      return unless @progress_tracker.should_send_progress_update?(progress_percent)

      @message_sender.send_progress_update(@progress_tracker.current_example, progress_percent)
      @progress_tracker.update_last_progress_percent(progress_percent)
    end

    def send_test_result(notification, status)
      return unless @connected

      test_result = {
        status: status, description: notification.example.description,
        location: notification.example.location
      }

      @message_sender.send_progress_update(
        @progress_tracker.current_example,
        @progress_tracker.calculate_progress_percent,
        test_result
      )
    end

    def apply_runner_suppression
      SuppressionLayer.suppress_runner_output(@config)
    end
  end
end