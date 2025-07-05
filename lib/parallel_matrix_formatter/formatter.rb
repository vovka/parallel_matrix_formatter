# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'
require_relative 'formatter_initializer'
require_relative 'failed_example_collector'
require_relative 'summary_data_builder'
require_relative 'formatter_dump_methods'

module ParallelMatrixFormatter
  # The Formatter class is the main RSpec formatter for the ParallelMatrixFormatter gem.
  # It extends `RSpec::Core::Formatters::BaseFormatter` and is responsible for
  # capturing test events (start, example_passed, example_failed, etc.) and
  # communicating them to the `Orchestrator` via IPC. It also initializes and
  # utilizes the `UpdateRenderer` for displaying real-time progress and status.
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def initialize(output, test_env_number = ENV['TEST_ENV_NUMBER'], config = ParallelMatrixFormatter::Config.new)
      initializer = FormatterInitializer.new(output, test_env_number, config)
      initializer.initialize_formatter
      
      @test_env_number = initializer.test_env_number
      @orchestrator = initializer.orchestrator
      @notifier = FormatterNotifier.new(@test_env_number)
      @dump_methods = FormatterDumpMethods.new(@orchestrator)
      
      initialize_state
    end

    def start(start_notification)
      @start_time = Time.now
      @orchestrator.start
      @notifier.initialize_ipc
      @total_examples = start_notification.count
    end

    def example_started(notification)
      @current_example += 1
    end

    def example_passed(notification)
      @notifier.notify_status(:passed, calculate_progress)
    end

    def example_failed(notification)
      @failed_example_collector.collect(notification)
      @notifier.notify_status(:failed, calculate_progress)
    end

    def example_pending(notification)
      @pending_count += 1
      @notifier.notify_status(:pending, calculate_progress)
    end

    def dump_summary(summary_notification)
      duration = calculate_duration(summary_notification)
      summary_data = build_summary_data(summary_notification, duration)
      @notifier.notify_summary(summary_data)
    end

    def dump_failures(_failures_notification)
      @dump_methods.dump_failures
    end

    def dump_pending(_pending_notification)
      @dump_methods.dump_pending
    end

    def dump_profile(_profile_notification)
      @dump_methods.dump_profile
    end

    def stop(_stop_notification); end

    def close(_close_notification)
      @orchestrator.close
    end

    private

    def initialize_state
      @total_examples = 0
      @current_example = 0
      @failed_example_collector = FailedExampleCollector.new
      @pending_count = 0
      @start_time = nil
    end

    def calculate_progress
      @total_examples.zero? ? 0.0 : @current_example.to_f / @total_examples
    end

    def calculate_duration(summary_notification)
      return Time.now - @start_time if @start_time
      return summary_notification.duration if summary_notification.respond_to?(:duration)
      0.0
    end

    def build_summary_data(summary_notification, duration)
      builder = SummaryDataBuilder.new(@test_env_number)
      builder.build(summary_notification, @failed_example_collector.failed_examples, @pending_count, duration)
    end
  end
end
