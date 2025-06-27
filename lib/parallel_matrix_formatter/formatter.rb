# frozen_string_literal: true

module ParallelMatrixFormatter
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    @@output_suppressor = ParallelMatrixFormatter::OutputSuppressor.suppress

    def initialize(output)
      @@output_suppressor.notify(output)
      test_env_number = (ENV['TEST_ENV_NUMBER'].presence || '1').to_i
      @renderer = SymbolRenderer.new(test_env_number, output)
      total_processes = ParallelSplitTest.processes
      @orchestrator = Orchestrator.build(total_processes, test_env_number, output)
    end

    def start(start_notification)
      @orchestrator.start
    end

    def example_started(notification)
    end

    def example_passed(notification)
      @renderer.render_passed
    end

    def example_failed(notification)
      @renderer.render_failed
    end

    def example_pending(notification)
      @renderer.render_pending
    end

    def dump_summary(_summary_notification)
      @orchestrator.puts("\ndump_summary")
    end

    def dump_failures(_failures_notification)
      @orchestrator.puts("\ndump_failures")
    end

    def dump_pending(_pending_notification)
      @orchestrator.puts("\ndump_pending")
    end

    def dump_profile(_profile_notification)
      @orchestrator.puts("\ndump_profile")
    end

    def stop(_stop_notification)
    end

    def close(_close_notification)
    end
  end
end
