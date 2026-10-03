# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'

# RSpec requires only this file for --format ParallelMatrixFormatter::Formatter,
# so it loads everything the formatter needs.
require_relative 'error'
require_relative 'config'
require_relative 'output/silencer'
require_relative 'runner'
require_relative 'ipc'
require_relative 'ipc/client'
require_relative 'ipc/server'
require_relative 'rendering/colors'
require_relative 'rendering/digits'
require_relative 'rendering/progress_update_policy'
require_relative 'rendering/progress_column'
require_relative 'rendering/progress_line'
require_relative 'rendering/example_status'
require_relative 'rendering/summary'
require_relative 'rendering/display'
require_relative 'null_orchestrator'
require_relative 'orchestrator'

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
      @stream = output
      @process_number = [ENV['TEST_ENV_NUMBER'].to_i, 1].max
      @runner = Runner.detect
      @orchestrator = Orchestrator.for(@process_number, @runner, self.output, config)
      @examples_run = 0
      @failures = []
    end

    def start(notification)
      @total_examples = notification.count
      @client = Ipc::Client.connect(Ipc.socket_path(@runner.run_id))
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
      record_totals(summary)
      @client.notify(**sender, type: 'summary', duration: summary.duration,
                               examples: summary.example_count, failures: summary.failure_count,
                               pending: summary.pending_count, errors: summary.errors_outside_of_examples_count,
                               failed_examples: @failures)
    end

    def close(_notification)
      @client&.close
      @orchestrator.close
    end

    private

    # The silenced terminal is where the display goes, unless RSpec was asked
    # to write to a file with --out.
    def display_output(config, output)
      return output unless config['suppress_output']

      terminal = Output::Silencer.silence
      output.is_a?(File) ? output : terminal
    end

    # parallel_split_test builds its closing "Summary:" from what every process
    # wrote to the stream RSpec handed to the formatter. The display goes to the
    # silenced terminal instead, so the totals line goes to the stream, which
    # parallel_split_test records while its own stdout is silenced.
    def record_totals(summary)
      @stream.puts summary.totals_line unless @stream.equal?(output)
    end

    # Identifies this process to the orchestrator: its number and the pids it
    # can be told apart by in the runner's pid file.
    def sender
      { process: @process_number, pid: Process.pid, ppid: Process.ppid }
    end

    def report(status)
      progress = @examples_run.fdiv(@total_examples)
      @client.notify(**sender, type: 'example', status: status, progress: progress)
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
