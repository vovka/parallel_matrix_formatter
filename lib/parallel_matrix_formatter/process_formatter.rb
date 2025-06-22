# frozen_string_literal: true

require_relative 'ipc'

module ParallelMatrixFormatter
  class ProcessFormatter
    def initialize(config, process_id = nil)
      @config = config
      @process_id = process_id || Process.pid
      @ipc_client = nil
      @total_examples = 0
      @current_example = 0
      @last_progress_percent = 0
      @connected = false
    end

    def start(total_examples)
      @total_examples = total_examples
      connect_to_orchestrator
      register_with_orchestrator if @connected
    end

    def example_started(_notification)
      # Called when an example starts
      @current_example += 1
      send_progress_update
    end

    def example_passed(notification)
      send_test_result(notification, :passed)
    end

    def example_failed(notification)
      send_test_result(notification, :failed)
      send_failure_details(notification)
    end

    def example_pending(notification)
      send_test_result(notification, :pending)
    end

    def stop
      send_completion_message if @connected
      @ipc_client&.close
    end

    private

    def connect_to_orchestrator
      server_path = ENV['PARALLEL_MATRIX_FORMATTER_SERVER']
      return unless server_path

      @ipc_client = IPC.create_client(server_path)
      @ipc_client.connect
      @connected = true
    rescue IPC::IPCError
      # Silently fail - orchestrator might not be available
      @connected = false
    end

    def register_with_orchestrator
      return unless @connected

      message = {
        type: 'register',
        process_id: @process_id,
        total_tests: @total_examples,
        timestamp: Time.now.to_f
      }

      send_message(message)
    end

    def send_progress_update
      return unless @connected

      progress_percent = calculate_progress_percent

      # Only send if progress has changed significantly or at certain intervals
      return unless should_send_progress_update?(progress_percent)

      message = {
        type: 'progress',
        process_id: @process_id,
        current_test: @current_example,
        progress_percent: progress_percent,
        timestamp: Time.now.to_f
      }

      send_message(message)
      @last_progress_percent = progress_percent
    end

    def send_test_result(notification, status)
      return unless @connected

      test_result = {
        status: status,
        description: notification.example.description,
        location: notification.example.location
      }

      message = {
        type: 'progress',
        process_id: @process_id,
        current_test: @current_example,
        progress_percent: calculate_progress_percent,
        test_result: test_result,
        timestamp: Time.now.to_f
      }

      send_message(message)
    end

    def send_failure_details(notification)
      return unless @connected

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

    def send_completion_message
      return unless @connected

      message = {
        type: 'complete',
        process_id: @process_id,
        timestamp: Time.now.to_f
      }

      send_message(message)
    end

    def send_message(message)
      return unless @connected

      begin
        @ipc_client.send_message(message)
      rescue IPC::IPCError
        # Connection lost, mark as disconnected
        @connected = false
      end
    end

    def calculate_progress_percent
      return 0 if @total_examples.zero?

      ((@current_example.to_f / @total_examples) * 100).round(1)
    end

    def should_send_progress_update?(current_percent)
      # Always send first update
      return true if @last_progress_percent.zero? && current_percent.positive?

      # Send if progress threshold is met
      thresholds = @config['update']['percent_thresholds'] || [5]
      progress_diff = current_percent - @last_progress_percent

      thresholds.any? { |threshold| progress_diff >= threshold }
    end
  end
end
