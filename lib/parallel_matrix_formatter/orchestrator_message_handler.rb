# frozen_string_literal: true

module ParallelMatrixFormatter
  # Handles message processing for the Orchestrator
  class OrchestratorMessageHandler
    def initialize(output, renderer, message_processor, process_tracker, summary_collector)
      @output = output
      @renderer = renderer
      @message_processor = message_processor
      @process_tracker = process_tracker
      @summary_collector = summary_collector
    end

    def handle_message(message)
      if summary_message?(message)
        handle_summary_message(message)
      else
        handle_regular_message(message)
      end
    end

    def handle_io_error(error)
      @output.puts "Error in IPC server: #{error.message}"
      @output.puts error.backtrace.join("\n")
    end

    def handle_standard_error(error)
      @output.puts "Unexpected error in IPC server: #{error.message}"
      @output.puts error.backtrace.join("\n")
    end

    private

    def summary_message?(message)
      message && message['message'] && message['message']['type'] == 'summary'
    end

    def handle_summary_message(message)
      @summary_collector.collect(message['process_number'], message['message']['data'])
    end

    def handle_regular_message(message)
      track_progress(message)
      update = @renderer.update(message)
      @output.print update
      process_buffered_messages_if_complete
    end

    def track_progress(message)
      return unless message && message['process_number'] && message['message'] && message['message']['progress']
      
      @process_tracker.track_completion(message['process_number'], message['message']['progress'])
    end

    def process_buffered_messages_if_complete
      @message_processor.process_if_complete(@process_tracker)
    end
  end
end