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

    def self.build(total_processes, test_env_number, output, renderer)
      if test_env_number == 1
        self
      else
        BlankOrchestrator
      end.new(total_processes, test_env_number, output, renderer)
    end

    def initialize(total_processes, test_env_number, output, renderer)
      @ipc = ParallelMatrixFormatter::Ipc::Server.new
      @total_processes = total_processes
      @test_env_number = test_env_number
      @output = output
      @renderer = renderer
      @data = {}
      @buffered_messages = []
      @process_completion = {}
    end

    def puts(message)
      if message&.include?("dump_") && @total_processes > 1
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

    def process_buffered_messages_if_complete
      return unless all_processes_complete?
      @buffered_messages.each { |msg| @output.puts(msg) }
      @buffered_messages.clear
    end

    def track_process_completion(process_number, progress)
      @process_completion[process_number] = progress >= 1.0
    end

    def start
      Thread.new do
        @ipc.start do |message|
          # Track process completion based on progress
          if message && message['process_number'] && message['message'] && message['message']['progress']
            track_process_completion(message['process_number'], message['message']['progress'])
          end
          
          update = @renderer.update(message)
          @output.print update #if update
          
          # Process any buffered messages if all processes are complete
          process_buffered_messages_if_complete
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

    def wait_for_completion
      # Wait until all processes have completed
      # This will wait indefinitely as per requirements
      sleep 0.1 until all_processes_complete?
    end
  end
end
