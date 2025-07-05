# frozen_string_literal: true

module ParallelMatrixFormatter
  # Handles complex initialization logic for the Formatter
  class FormatterInitializer
    def initialize(output, test_env_number, config)
      @output = output
      @test_env_number = normalize_test_env_number(test_env_number)
      @config = config
    end

    def initialize_formatter
      suppress_output
      create_orchestrator
      initialize_state
    end

    def test_env_number
      @test_env_number
    end

    def orchestrator
      @orchestrator
    end

    private

    def normalize_test_env_number(test_env_number)
      return 1 if test_env_number.nil? || test_env_number.empty?
      
      test_env_number.to_i
    end

    def suppress_output
      output_suppressor = create_output_suppressor
      output_suppressor.suppress
      output_suppressor.notify(@output)
    end

    def create_output_suppressor
      ParallelMatrixFormatter::Output::Suppressor.new(@config.output_suppressor)
    end

    def create_orchestrator
      renderer = create_renderer
      total_processes = get_total_processes
      @orchestrator = Orchestrator.build(total_processes, @test_env_number, @output, renderer)
    end

    def create_renderer
      ParallelMatrixFormatter::Rendering::UpdateRenderer.new(@test_env_number, @config.update_renderer)
    end

    def get_total_processes
      Object.const_defined?('ParallelSplitTest') ? ParallelSplitTest.processes : 1
    end

    def initialize_state
      {
        total_examples: 0,
        current_example: 0,
        failed_example_collector: FailedExampleCollector.new,
        pending_count: 0,
        start_time: nil,
        ipc: nil
      }
    end
  end
end