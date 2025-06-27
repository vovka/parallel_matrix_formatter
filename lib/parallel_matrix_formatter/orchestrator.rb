module ParallelMatrixFormatter
  class Orchestrator
    class BlankOrchestrator
      def initialize(_test_env_number, _output)
        @output = _output
      end

      def puts(_message)
        # @output.puts("Blank Orchestrator. No output will be shown.")
      end
    end

    def self.build(test_env_number, output)
      if test_env_number == 1
        self
      else
        BlankOrchestrator
      end.new(test_env_number, output)
    end

    def initialize(test_env_number, output)
      @output = output
    end

    def puts(message)
      @output.puts(message)
    end
  end
end
