# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'
require_relative 'output/suppressor'
require_relative 'rendering/update_renderer'
require_relative 'ipc/client'

module ParallelMatrixFormatter
  # The Formatter class is the main RSpec formatter for the ParallelMatrixFormatter gem.
  # It extends `RSpec::Core::Formatters::BaseFormatter` and is responsible for
  # capturing test events (start, example_passed, example_failed, etc.) and
  # communicating them to the `Orchestrator` via IPC. It also initializes and
  # utilizes the `UpdateRenderer` for displaying real-time progress and status.
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def initialize(output, test_env_number = ENV['TEST_ENV_NUMBER'], config = ParallelMatrixFormatter::Config.new)
      # Suppress output immediately to prevent race condition leakage
      output_suppressor = ParallelMatrixFormatter::Output::Suppressor.new(config.output_suppressor)
      output_suppressor.suppress
      output_suppressor.notify(output)
      
      @test_env_number = (test_env_number && !test_env_number.empty? ? test_env_number : '1').to_i
      renderer = ParallelMatrixFormatter::Rendering::UpdateRenderer.new(@test_env_number, config.update_renderer)
      total_processes = Object.const_defined?('ParallelSplitTest') ? ParallelSplitTest.processes : 1 # TODO: handle this better
      @orchestrator = Orchestrator.build(total_processes, @test_env_number, output, renderer)

      @total_examples = 0
      @current_example = 0

      # Create IPC client - it will wait for server to be available before proceeding
      @ipc = ParallelMatrixFormatter::Ipc::Client.new
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
          progress: @total_examples.zero? ? 0.0 : @current_example.to_f / @total_examples
        }
      )
    end

    def example_failed(notification)
      @ipc.notify(
        @test_env_number,
        {
          status: :failed,
          progress: @total_examples.zero? ? 0.0 : @current_example.to_f / @total_examples
        }
      )
    end

    def example_pending(notification)
      @ipc.notify(
        @test_env_number,
        {
          status: :pending,
          progress: @total_examples.zero? ? 0.0 : @current_example.to_f / @total_examples
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
      @orchestrator.close
    end
  end
end
