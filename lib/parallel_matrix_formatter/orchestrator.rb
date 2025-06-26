# frozen_string_literal: true

require_relative 'ipc'
require_relative 'digital_rain_renderer'
require_relative 'update_strategies'
require_relative 'suppression_layer'

module ParallelMatrixFormatter
  class Orchestrator
    def initialize(config)
      @config = config
      @renderer = DigitalRainRenderer.new(config)
      @update_strategy = UpdateStrategies.create_strategy(config)
      @ipc_server = nil
      @processes = {}
      @all_failures = []
      @start_time = nil
      @last_update_time = nil
      @running = false
      @displayed_test_count = 0  # Track how many test results have been displayed
      @current_line_rendered = false  # Track if current line base has been rendered
      @process_thresholds = {}  # Track threshold progress for each process
    end

    def start
      @start_time = Time.now
      @last_update_time = @start_time
      @running = true

      # Start IPC server
      @ipc_server = IPC.create_server
      server_path = @ipc_server.start

      # Store server path for child processes to connect
      ENV['PARALLEL_MATRIX_FORMATTER_SERVER'] = server_path

      # Also write to a file for other processes to read
      server_file = '/tmp/parallel_matrix_formatter_server.path'
      File.write(server_file, server_path)

      # Start processing messages
      process_messages

      server_path
    rescue IPC::IPCError => e
      warn "Failed to start orchestrator: #{e.message}" unless ENV['PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS']
      nil
    end

    def stop
      @running = false
      @ipc_server&.stop

      # Finalize current line before printing summaries
      finalize_current_line

      # Clean up server path file
      server_file = '/tmp/parallel_matrix_formatter_server.path'
      File.delete(server_file) if File.exist?(server_file)

      print_final_summary
    end

    def handle_direct_message(message)
      # Public method to handle messages from same-process formatters
      if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        message_type = message.is_a?(Hash) ? (message[:type] || message['type']) : 'unknown'
        process_id = message.is_a?(Hash) ? (message[:process_id] || message['process_id']) : 'unknown'
        debug_puts "Orchestrator: Received direct #{message_type} message from process #{process_id}"
      end
      handle_message(message)
    end

    private

    def process_messages
      Thread.new do
        @ipc_server.each_message do |message|
          handle_message(message)
        end
      end
    end

    def handle_message(message)
      # Normalize message to use string keys for consistent access
      # (IPC messages come with string keys, direct messages come with symbol keys)
      normalized_message = normalize_message_keys(message)

      case normalized_message['type']
      when 'register'
        handle_process_registration(normalized_message)
      when 'progress'
        handle_progress_update(normalized_message)
      when 'failure'
        handle_failure(normalized_message)
      when 'complete'
        handle_process_completion(normalized_message)
      when 'error'
        handle_error(normalized_message)
      end
    end

    def normalize_message_keys(message)
      # Convert symbol keys to string keys for consistent access
      if message.is_a?(Hash)
        message.transform_keys(&:to_s)
      else
        message
      end
    end

    def handle_process_registration(message)
      process_id = message['process_id']

      if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        debug_puts "Orchestrator: Registering process #{process_id} with #{message['total_tests']} tests"
        debug_puts "Orchestrator: Total registered processes: #{@processes.keys.length + 1}"
      end

      @processes[process_id] = {
        id: process_id,
        total_tests: message['total_tests'],
        current_test: 0,
        progress_percent: 0,
        status: :running,
        start_time: Time.now,
        end_time: nil,
        test_results: [],
        first_completion_shown: false
      }

      # Initialize threshold tracking for this process
      @process_thresholds[process_id] = 0

      update_base_display
    end

    def handle_progress_update(message)
      process_id = message['process_id']
      process = @processes[process_id]
      return unless process

      process[:current_test] = message['current_test']
      process[:progress_percent] = message['progress_percent']

      # If test result is provided, render it immediately
      if message['test_result']
        process[:test_results] << message['test_result']

        if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
          debug_puts "Orchestrator: Rendering live test result #{message['test_result']['status']} from process #{process_id}"
        end

        render_live_test_result(message['test_result'])
      end

      # Check if we should update display (for base line)
      return unless should_update_display?

      update_base_display
    end

    def handle_failure(message)
      @all_failures << {
        process_id: message['process_id'],
        description: message['description'],
        location: message['location'],
        message: message['message']
      }
    end

    def handle_process_completion(message)
      process_id = message['process_id']
      process = @processes[process_id]
      return unless process

      process[:status] = :completed
      process[:end_time] = Time.now
      process[:progress_percent] = 100

      update_base_display

      # Check if all processes are complete
      return unless all_processes_complete?

      @running = false
    end

    def handle_error(message)
      # Log error but continue processing
      warn "Orchestrator error: #{message['error']}" unless ENV['PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS']
    end

    def should_update_display?
      current_time = Time.now.to_f

      # Check if any process has crossed a threshold
      threshold_crossed = false
      thresholds = @config['update']['percent_thresholds'] || [5]

      @processes.each do |process_id, process|
        current_progress = process[:progress_percent]
        last_threshold = @process_thresholds[process_id] || 0

        # Check if this process has crossed any threshold
        thresholds.each do |threshold|
          # Calculate the threshold levels this process has crossed
          current_threshold_level = (current_progress / threshold).floor * threshold
          last_threshold_level = (last_threshold / threshold).floor * threshold

          if current_threshold_level > last_threshold_level
            threshold_crossed = true
            @process_thresholds[process_id] = current_progress

            if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
              debug_puts "Orchestrator: Process #{process_id} crossed threshold: #{last_threshold_level}% -> #{current_threshold_level}%"
            end
            break
          end
        end
      end

      # Also check time-based strategy if configured
      time_based_update = false
      if @config['update']['interval_seconds']
        time_based_update = (current_time - @last_update_time.to_f) / 1_000 >= @config['update']['interval_seconds']
      end

      should_update = threshold_crossed || time_based_update

      if should_update
        @last_update_time = current_time
      end

      should_update
    end

    def update_base_display
      return if @processes.empty?

      if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        debug_puts "Orchestrator: Updating display with #{@processes.size} processes: #{@processes.keys.join(', ')}"
      end

      # Finalize previous line if one was already rendered
      finalize_current_line

      # Render time column
      time_column = @renderer.render_time_column

      # Render process columns
      process_columns = @processes.values.map do |process|
        # Check if this is the first time showing 100%
        is_first_completion = (process[:progress_percent] >= 100 && !process[:first_completion_shown])

        # Mark as shown if we're displaying 100% for the first time
        if is_first_completion
          process[:first_completion_shown] = true
        end

        @renderer.render_process_column(
          process[:id],
          process[:progress_percent],
          @config['display']['column_width'],
          is_first_completion
        )
      end

      if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        debug_puts "Orchestrator: Rendered #{process_columns.size} process columns"
      end

      # Render base line (time + processes only)
      base_line = @renderer.render_matrix_line(time_column, process_columns, '')

      # Print base line and stay on same line for test dots
      orchestrator_print "#{base_line} "
      orchestrator_flush
      @current_line_rendered = true
    end

    def render_live_test_result(test_result)
      # Only render if we have a base line rendered
      return unless @current_line_rendered

      test_dot = @renderer.render_test_dots([test_result])
      orchestrator_print test_dot
      orchestrator_flush
    end

    def finalize_current_line
      # Move to next line when we're done with current line
      if @current_line_rendered
        orchestrator_puts
        @current_line_rendered = false
      end
    end

    def all_processes_complete?
      @processes.values.all? { |p| p[:status] == :completed }
    end

    def print_final_summary
      # Print failure summary
      if @all_failures.any?
        failure_summary = @renderer.render_failure_summary(@all_failures)
        orchestrator_puts failure_summary
      end

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

      # Print final summary
      final_summary = @renderer.render_final_summary(
        total_tests,
        failed_tests,
        pending_tests,
        total_duration,
        process_durations,
        process_count
      )
      orchestrator_puts final_summary
    end

    private

    def debug_puts(message)
      # Use original stderr for debug output, bypassing suppression
      if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG'] && SuppressionLayer.original_stderr
        SuppressionLayer.original_stderr.puts(message)
      end
    end

    def orchestrator_puts(message = '')
      # Use original stdout for orchestrator output, bypassing suppression
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.puts(message)
      else
        # Fallback to regular puts if original stdout not available
        puts(message)
      end
    end

    def orchestrator_print(message)
      # Use original stdout for orchestrator output, bypassing suppression
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.print(message)
      else
        # Fallback to regular print if original stdout not available
        print(message)
      end
    end

    def orchestrator_flush
      # Flush original stdout for orchestrator output
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.flush
      else
        # Fallback to regular flush if original stdout not available
        $stdout.flush
      end
    end
  end
end
