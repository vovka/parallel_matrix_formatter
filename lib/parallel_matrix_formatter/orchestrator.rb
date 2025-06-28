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
      @ipc = IpcServer.new
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
      previous_line_at = nil
      Thread.new do
        @ipc.start do |message|
          update = @renderer.update(message)
          @output.print update #if update
        rescue IOError => e
          @output.puts "Error in IPC server: #{e.message}"
          @output.puts e.backtrace.join("\n")
        rescue StandardError => e
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
