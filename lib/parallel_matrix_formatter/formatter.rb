# frozen_string_literal: true

module ParallelMatrixFormatter
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    @@output_suppressor = ParallelMatrixFormatter::OutputSuppressor.suppress

    def initialize(output)
      @@output_suppressor.notify(output)
      @test_env_number = (ENV['TEST_ENV_NUMBER'].presence || '1').to_i
      renderer = UpdateRenderer.new(@test_env_number)
      total_processes = ParallelSplitTest.processes
      @orchestrator = Orchestrator.build(total_processes, @test_env_number, output, renderer)

      @total_examples = 0
      @current_example = 0

      @ipc = IpcClient.new
    end

    def start(start_notification)
      @orchestrator.start

      @total_examples = start_notification.count
    end

    def example_started(notification)
      @current_example += 1
    end

    def example_passed(notification)
      @ipc.notify(
        @test_env_number,
        {
          status: :passed,
          progress: @current_example.to_f / @total_examples
        }
      )
    end

    def example_failed(notification)
      @ipc.notify(
        @test_env_number,
        {
          status: :failed,
          progress: @current_example.to_f / @total_examples
        }
      )
    end

    def example_pending(notification)
      @ipc.notify(
        @test_env_number,
        {
          status: :pending,
          progress: @current_example.to_f / @total_examples
        }
      )
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
      # @ipc.close
      @orchestrator.close
    end
  end
end
