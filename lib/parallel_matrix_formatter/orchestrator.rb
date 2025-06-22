# frozen_string_literal: true

require_relative 'ipc'
require_relative 'digital_rain_renderer'
require_relative 'update_strategies'

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
      
      # Clean up server path file
      server_file = '/tmp/parallel_matrix_formatter_server.path'
      File.delete(server_file) if File.exist?(server_file)
      
      print_final_summary
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
      case message['type']
      when 'register'
        handle_process_registration(message)
      when 'progress'
        handle_progress_update(message)
      when 'failure'
        handle_failure(message)
      when 'complete'
        handle_process_completion(message)
      when 'error'
        handle_error(message)
      end
    end

    def handle_process_registration(message)
      process_id = message['process_id']
      @processes[process_id] = {
        id: process_id,
        total_tests: message['total_tests'],
        current_test: 0,
        progress_percent: 0,
        status: :running,
        start_time: Time.now,
        end_time: nil,
        test_results: []
      }

      update_display
    end

    def handle_progress_update(message)
      process_id = message['process_id']
      process = @processes[process_id]
      return unless process

      process[:current_test] = message['current_test']
      process[:progress_percent] = message['progress_percent']

      # Add test result if provided
      process[:test_results] << message['test_result'] if message['test_result']

      # Check if we should update display
      return unless should_update_display?

      update_display
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

      update_display

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

      # Get max progress for percentage-based updates
      max_progress = @processes.values.map { |p| p[:progress_percent] }.max || 0
      last_max_progress = @last_max_progress || 0

      should_update = @update_strategy.should_update?(max_progress, @last_update_time, last_max_progress)

      if should_update
        @last_update_time = current_time
        @last_max_progress = max_progress
        @update_strategy.reset
      end

      should_update
    end

    def update_display
      return if @processes.empty?

      # Render time column
      time_column = @renderer.render_time_column

      # Render process columns
      process_columns = @processes.values.map do |process|
        @renderer.render_process_column(
          process[:id],
          process[:progress_percent],
          @config['display']['column_width']
        )
      end

      # Render test dots (only new test results since last display)
      all_test_results = @processes.values.flat_map { |p| p[:test_results] }
      new_test_results = all_test_results[@displayed_test_count..-1] || []
      
      test_dots = if new_test_results.any?
                    @renderer.render_test_dots(new_test_results)
                  else
                    ''
                  end

      # Update displayed test count
      @displayed_test_count = all_test_results.length

      # Render complete line
      line = @renderer.render_matrix_line(time_column, process_columns, test_dots)

      # Print to stdout (only the orchestrator should output)
      puts line
    end

    def all_processes_complete?
      @processes.values.all? { |p| p[:status] == :completed }
    end

    def print_final_summary
      # Print failure summary
      if @all_failures.any?
        failure_summary = @renderer.render_failure_summary(@all_failures)
        puts failure_summary
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
      puts final_summary
    end
  end
end
