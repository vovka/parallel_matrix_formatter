require_relative 'orchestrator_initializer'
require_relative 'blank_orchestrator'

module ParallelMatrixFormatter
  # The Orchestrator class coordinates communication between different test processes
  # and the main RSpec formatter.
  class Orchestrator
    DUMP_PREFIX = "dump_"

    def self.build(total_processes, test_env_number, output, renderer)
      orchestrator_class = test_env_number == 1 ? self : BlankOrchestrator
      orchestrator_class.new(total_processes, test_env_number, output, renderer)
    end

    attr_reader :total_processes

    def initialize(total_processes, test_env_number, output, renderer)
      @total_processes = total_processes
      @test_env_number = test_env_number
      @output = output
      @renderer = renderer
      @data = {}
      setup_components(total_processes, test_env_number, output, renderer)
    end

    def puts(message)
      if message&.include?(DUMP_PREFIX) && @total_processes > 1
        @message_processor.buffer_message(message)
        @message_processor.process_if_complete(@process_tracker)
      else
        @output.puts(message)
      end
    end

    def all_processes_complete?
      @process_tracker.all_processes_complete?
    end

    def track_process_completion(process_number, progress)
      @process_tracker.track_completion(process_number, progress)
    end

    def start
      Thread.new do
        @ipc.start do |message|
          @message_handler.handle_message(message)
          render_summary_if_ready
        rescue IOError => e
          @message_handler.handle_io_error(e)
        rescue StandardError => e
          @message_handler.handle_standard_error(e)
        ensure
          @output.flush
        end
      end
    end

    def close
      if @total_processes > 1
        wait_for_completion
        wait_for_summaries
      end
      @ipc.close
    end

    private

    def setup_components(total_processes, test_env_number, output, renderer)
      initializer = OrchestratorInitializer.new(total_processes, test_env_number, output, renderer)
      components = initializer.initialize_components
      assign_components(components)
      @message_handler = initializer.create_message_handler(components)
    end

    def assign_components(components)
      @ipc = components[:ipc]
      @message_processor = components[:message_processor]
      @process_tracker = components[:process_tracker]
      @summary_collector = components[:summary_collector]
      @start_time = components[:start_time]
    end

    def wait_for_completion
      sleep 0.1 until all_processes_complete?
    end

    def wait_for_summaries
      renderer = ConsolidatedSummaryRenderer.new(@output, @start_time)
      waiter = SummaryWaiter.new(@summary_collector, @output)
      waiter.wait_and_render(renderer)
    end

    def render_summary_if_ready
      return unless @summary_collector.all_summaries_received?
      render_consolidated_summary
    end

    def render_consolidated_summary
      renderer = ConsolidatedSummaryRenderer.new(@output, @start_time)
      renderer.render(@summary_collector.process_summaries)
    end
  end
end
