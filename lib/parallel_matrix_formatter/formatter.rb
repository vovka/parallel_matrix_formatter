# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'

module ParallelMatrixFormatter
  # The RSpec formatter loaded into every test process. It silences the
  # process, turns RSpec notifications into IPC messages for the orchestrator
  # and, in process 1, hosts the orchestrator that renders the shared display.
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    RSpec::Core::Formatters.register self, :start, :example_started, :example_passed,
                                     :example_failed, :example_pending, :dump_summary, :close

    def initialize(output)
      config = Config.load
      super(display_output(config, output))
      @process_number = [ENV['TEST_ENV_NUMBER'].to_i, 1].max
      @orchestrator = Orchestrator.for(@process_number, total_processes, self.output, config)
      @examples_run = 0
      @failures = []
    end

    def start(notification)
      @total_examples = notification.count
      @client = Ipc::Client.connect
    end

    def example_started(_notification)
      @examples_run += 1
    end

    def example_passed(_notification)
      report(:passed)
    end

    def example_pending(_notification)
      report(:pending)
    end

    def example_failed(notification)
      @failures << failure_details(notification)
      report(:failed)
    end

    def dump_summary(summary)
      @client.notify(type: 'summary', process: @process_number, duration: summary.duration,
                     examples: summary.example_count, failures: summary.failure_count,
                     pending: summary.pending_count, failed_examples: @failures)
    end

    def close(_notification)
      @client&.close
      @orchestrator.close
    end

    private

    # Under parallel_split_test every process is forked by the same runner,
    # which records the process count before forking.
    def total_processes
      (ParallelSplitTest.processes if defined?(ParallelSplitTest)) || 1
    end

    # The silenced terminal is where the display goes, unless RSpec was asked
    # to write to a file with --out.
    def display_output(config, output)
      return output unless config['suppress_output']

      terminal = Output::Silencer.silence
      output.is_a?(File) ? output : terminal
    end

    def report(status)
      progress = @examples_run.fdiv(@total_examples)
      @client.notify(type: 'example', process: @process_number, status: status, progress: progress)
    end

    def failure_details(notification)
      {
        description: notification.description,
        location: notification.example.location_rerun_argument,
        message_lines: notification.colorized_message_lines(Rendering::Colors),
        backtrace: notification.colorized_formatted_backtrace(Rendering::Colors)
      }
    end
  end
end
