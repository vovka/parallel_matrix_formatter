# frozen_string_literal: true

module ParallelMatrixFormatter
  # Processes buffered messages for the Orchestrator
  class BufferedMessageProcessor
    def initialize(output)
      @output = output
      @buffered_messages = []
    end

    def buffer_message(message)
      @buffered_messages << message
    end

    def process_if_complete(process_tracker)
      return unless process_tracker.all_processes_complete?
      
      @buffered_messages.each { |msg| @output.puts(msg) }
      @buffered_messages.clear
    end

    def buffered_messages
      @buffered_messages
    end
  end
end