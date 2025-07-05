# frozen_string_literal: true

module ParallelMatrixFormatter
  # Builds summary data structure for IPC transmission
  class SummaryDataBuilder
    def initialize(process_number)
      @process_number = process_number
    end

    def build(summary_notification, failed_examples, pending_count, duration)
      {
        total_examples: extract_total_examples(summary_notification),
        failed_examples: failed_examples,
        pending_count: pending_count,
        duration: duration,
        process_number: @process_number
      }
    end

    private

    def extract_total_examples(summary_notification)
      return 0 unless summary_notification.respond_to?(:example_count)
      
      summary_notification.example_count
    end
  end
end