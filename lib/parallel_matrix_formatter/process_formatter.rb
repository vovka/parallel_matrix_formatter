# frozen_string_literal: true

require_relative 'ipc'
require_relative 'suppression_layer'

module ParallelMatrixFormatter
  # ProcessFormatter handles test progress reporting from individual test processes
  # to the orchestrator. It tracks test execution progress and sends updates via
  # either direct method calls (same process) or IPC (separate processes).
  #
  # Key responsibilities:
  # - Connect to orchestrator via IPC or direct reference
  # - Register process with orchestrator including total test count
  # - Send progress updates as tests are executed
  # - Report individual test results (pass/fail/pending) for live display
  # - Send completion notification when all tests finish
  # - Apply runner-level output suppression for clean display
  #
  # The formatter uses a centralized config object for all settings,
  # eliminating direct ENV access except during connection establishment
  # where it may fall back to reading the server path from filesystem.
  #
  class ProcessFormatter
    def initialize(config, process_id = nil, orchestrator = nil)
      @config = config
      @process_id = process_id || Process.pid
      @ipc_client = nil
      @total_examples = 0
      @current_example = 0
      @last_progress_percent = 0
      @connected = false
      @orchestrator = orchestrator  # Direct reference when in same process
      
      # Apply runner-level suppression for this role
      apply_runner_suppression
    end

    def start(total_examples)
      @total_examples = total_examples
      
      # If we have a direct orchestrator reference, use it; otherwise connect via IPC
      if @orchestrator
        @connected = true
      else
        connect_to_orchestrator
      end
      
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
      # Connect to orchestrator using centralized IPC configuration
      ipc_config = @config['ipc']
      max_attempts = ipc_config['retry_attempts']
      retry_delay = ipc_config['retry_delay']
      connection_timeout = ipc_config['connection_timeout']
      
      attempts = 0
      start_time = Time.now
      
      while attempts < max_attempts && (Time.now - start_time) < connection_timeout
        # Get server path from configuration first
        server_path = @config['environment']['server_path']
        
        # Fallback to reading from configured server path file only if explicitly configured
        if !server_path && ipc_config['server_path_file']
          server_path = File.read(ipc_config['server_path_file']).strip if File.exist?(ipc_config['server_path_file'])
        end
        
        # Use default server path from IPC config if still not found
        server_path ||= ipc_config['server_path']
        
        break unless server_path  # No server configured
        
        begin
          @ipc_client = IPC.create_client(
            server_path,
            prefer_unix_socket: ipc_config['prefer_unix_socket']
          )
          @ipc_client.connect
          @connected = true
          return
        rescue IPC::IPCError
          # Server not ready yet, wait and retry
          attempts += 1
          sleep(retry_delay) if attempts < max_attempts
        end
      end

      # Failed to connect after all attempts
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
        if @orchestrator
          # Direct communication - call orchestrator's public handle method
          @orchestrator.handle_direct_message(message)
        else
          # IPC communication
          @ipc_client.send_message(message)
        end
      rescue IPC::IPCError
        # Connection lost, mark as disconnected
        @connected = false
      rescue => e
        # Handle any other errors from direct communication
        @connected = false
      end
    end

    def calculate_progress_percent
      return 0 if @total_examples.zero?

      ((@current_example.to_f / @total_examples) * 100).to_i
    end

    def should_send_progress_update?(current_percent)
      # Always send first update
      return true if @last_progress_percent.zero? && current_percent.positive?

      # Send if progress threshold is met using configured thresholds
      thresholds = @config['update']['percent_thresholds'] || [5]
      progress_diff = current_percent - @last_progress_percent

      thresholds.any? { |threshold| progress_diff >= threshold }
    end

    def apply_runner_suppression
      # Apply role-based suppression for runner - always suppress output
      SuppressionLayer.suppress_runner_output(@config)
    end
  end
end
