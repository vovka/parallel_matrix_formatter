# frozen_string_literal: true

module ParallelMatrixFormatter
  # Handles initialization for the Orchestrator
  class OrchestratorInitializer
    def initialize(total_processes, test_env_number, output, renderer)
      @total_processes = total_processes
      @test_env_number = test_env_number
      @output = output
      @renderer = renderer
    end

    def initialize_components
      {
        ipc: ParallelMatrixFormatter::Ipc::Server.new,
        message_processor: BufferedMessageProcessor.new(@output),
        process_tracker: ProcessTracker.new(@total_processes),
        summary_collector: SummaryCollector.new(@total_processes),
        start_time: Time.now
      }
    end

    def create_message_handler(components)
      OrchestratorMessageHandler.new(
        @output,
        @renderer,
        components[:message_processor],
        components[:process_tracker],
        components[:summary_collector]
      )
    end
  end
end