module ParallelMatrixFormatter
  class Orchestrator
    class BlankOrchestrator
      def initialize(_total_processes, _test_env_number, _output)
        @output = _output
      end

      def puts(_message)
        # @output.puts("Blank Orchestrator. No output will be shown.")
      end

      def start
        # No operation for blank orchestrator
      end
    end

    def self.build(total_processes, test_env_number, output)
      if test_env_number == 1
        self
      else
        BlankOrchestrator
      end.new(total_processes, test_env_number, output)
    end

    def initialize(total_processes, test_env_number, output)
      @total_processes = total_processes
      @test_env_number = test_env_number
      @output = output
    end

    def puts(message)
      @output.puts(message)
    end

    def start
      Thread.new do
        loop do
          sleep 3
          @output.print "\nOrchestrator is running for test environment #{@test_env_number}/#{@total_processes}. "
        end
      end
    # rescue StandardError => e
    #   puts "Error in orchestrator: #{e.message}"
    #   puts e.backtrace.join("\n")
    end
  end
end
