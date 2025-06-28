require_relative 'ipc/server'

module ParallelMatrixFormatter
  class Orchestrator
    class BlankOrchestrator
      def initialize(*); end
      def puts(*); end
      def start(*);end
      def close(*);end
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
    end

    def puts(message)
      @output.puts(message)
    end

    def start
      Thread.new do
        @ipc.start do |message|
          update = @renderer.update(message)
          @output.print update #if update
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
      @ipc.close
    end
  end
end
