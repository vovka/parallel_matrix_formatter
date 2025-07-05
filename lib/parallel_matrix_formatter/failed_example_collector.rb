# frozen_string_literal: true

module ParallelMatrixFormatter
  # Collects and formats failed example details from test notifications
  class FailedExampleCollector
    def initialize
      @failed_examples = []
    end

    def collect(notification)
      failed_example = build_failed_example(notification)
      @failed_examples << failed_example
    end

    def failed_examples
      @failed_examples
    end

    private

    def build_failed_example(notification)
      {
        description: extract_description(notification),
        location: extract_location(notification),
        message: extract_message(notification),
        formatted_backtrace: extract_backtrace(notification)
      }
    end

    def extract_description(notification)
      notification.respond_to?(:description) ? notification.description : 'Unknown example'
    end

    def extract_location(notification)
      return 'Unknown location' unless notification.respond_to?(:example)
      return 'Unknown location' unless notification.example.respond_to?(:location)
      
      notification.example.location
    end

    def extract_message(notification)
      return 'No message' unless notification.respond_to?(:message_lines)
      
      notification.message_lines.join("\n")
    end

    def extract_backtrace(notification)
      return 'No backtrace' unless notification.respond_to?(:formatted_backtrace)
      
      notification.formatted_backtrace.join("\n")
    end
  end
end