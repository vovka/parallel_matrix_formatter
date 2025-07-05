require_relative 'ipc/server'

module ParallelMatrixFormatter
  # The Orchestrator class coordinates communication between different test processes
  # and the main RSpec formatter. It acts as an IPC server, receiving updates from
  # parallel test processes and using the `UpdateRenderer` to display real-time
  # progress and status to the console.
  class Orchestrator
    # The BlankOrchestrator is a no-op orchestrator used when the current process
    # is not the primary process (i.e., `test_env_number` is not 1). It provides
    # a null implementation of the orchestrator interface to avoid unnecessary
    # IPC server setup and message processing in secondary processes.
    class BlankOrchestrator
      def initialize(*); end
      def puts(*); end
      def start(*); end
      def close(*); end
      def all_processes_complete?; true; end
    end

    DUMP_PREFIX = "dump_"

    def self.build(total_processes, test_env_number, output, renderer)
      if test_env_number == 1
        self
      else
        BlankOrchestrator
      end.new(total_processes, test_env_number, output, renderer)
    end

    attr_reader :total_processes

    def initialize(total_processes, test_env_number, output, renderer)
      @ipc = ParallelMatrixFormatter::Ipc::Server.new
      @total_processes = total_processes
      @test_env_number = test_env_number
      @output = output
      @renderer = renderer
      @data = {}
      @buffered_messages = []
      @process_completion = {}
      @process_summaries = {}
      @start_time = Time.now
    end

    def puts(message)
      if message&.include?(DUMP_PREFIX) && @total_processes > 1
        @buffered_messages << message
        process_buffered_messages_if_complete
      else
        @output.puts(message)
      end
    end

    def all_processes_complete?
      return false if @process_completion.empty?
      expected_processes = (1..@total_processes).to_a
      completed_processes = @process_completion.select { |_, complete| complete }.keys
      expected_processes.all? { |process| completed_processes.include?(process) }
    end

    def track_process_completion(process_number, progress)
      @process_completion[process_number] = progress >= 1.0
    end

    def start
      Thread.new do
        @ipc.start do |message|
          # Handle summary messages
          if message && message['message'] && message['message']['type'] == 'summary'
            @process_summaries[message['process_number']] = message['message']['data']
            # Check if all summaries are received and render consolidated summary
            render_consolidated_summary if all_summaries_received?
          else
            # Track process completion based on progress
            if message && message['process_number'] && message['message'] && message['message']['progress']
              track_process_completion(message['process_number'], message['message']['progress'])
            end

            update = @renderer.update(message)
            @output.print update #if update

            # Process any buffered messages if all processes are complete
            process_buffered_messages_if_complete
          end
        rescue IOError => e
          @output.puts "Error in IPC server: #{e.message}"
          @output.puts e.backtrace.join("\n")
        rescue StandardError => e
          # TODO: Error messages and backtraces from the IPC server thread are being
          # printed directly to @output, which is the RSpec output stream. This
          # could corrupt the formatter's output, making it unreadable. It would
          # be safer to log these errors to $stderr or a dedicated log file to
          # keep the main output stream clean.
          @output.puts "Unexpected error in IPC server: #{e.message}"
          @output.puts e.backtrace.join("\n")
        ensure
          @output.flush
        end
      end
    end

    def close
      # Wait for all processes to complete before closing if in multi-process mode
      wait_for_completion if @total_processes > 1
      @ipc.close
    end

    private

    def process_buffered_messages_if_complete
      return unless all_processes_complete?
      @buffered_messages.each { |msg| @output.puts(msg) }
      @buffered_messages.clear
    end

    def wait_for_completion
      # Wait until all processes have completed
      # This will wait indefinitely as per requirements
      sleep 0.1 until all_processes_complete?
    end

    def all_summaries_received?
      expected_processes = (1..@total_processes).to_a
      expected_processes.all? { |process| @process_summaries.key?(process) }
    end

    def render_consolidated_summary
      total_examples = @process_summaries.values.sum { |summary| summary['total_examples'] }
      all_failed_examples = @process_summaries.values.flat_map { |summary| summary['failed_examples'] }
      total_pending = @process_summaries.values.sum { |summary| summary['pending_count'] }
      total_process_time = @process_summaries.values.sum { |summary| summary['duration'] }
      wall_clock_time = Time.now - @start_time

      @output.puts "\n"
      
      # Print failed examples
      unless all_failed_examples.empty?
        @output.puts "Failures:"
        @output.puts
        all_failed_examples.each_with_index do |failure, index|
          @output.puts "  #{index + 1}) #{failure['description']}"
          @output.puts "     #{failure['location']}" if failure['location']
          @output.puts "     #{failure['message']}" if failure['message']
          @output.puts "     #{failure['formatted_backtrace']}" if failure['formatted_backtrace']
          @output.puts
        end
      end
      
      # Print statistics
      failure_count = all_failed_examples.length
      @output.puts format_summary_line(total_examples, failure_count, total_pending)
      @output.puts "Finished in #{format_duration(wall_clock_time)} (files took #{format_duration(total_process_time)} to load)"
    end

    def format_summary_line(total, failures, pending)
      parts = ["#{total} example#{'s' if total != 1}"]
      parts << "#{failures} failure#{'s' if failures != 1}" if failures > 0
      parts << "#{pending} pending" if pending > 0
      parts.join(', ')
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round(2)} seconds"
      else
        minutes = (seconds / 60).floor
        remaining_seconds = seconds % 60
        "#{minutes} minute#{'s' if minutes != 1} #{remaining_seconds.round(2)} seconds"
      end
    end
  end
end
