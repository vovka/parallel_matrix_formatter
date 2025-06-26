# frozen_string_literal: true

require_relative 'process_registry'

module ParallelMatrixFormatter
  # MessageHandler manages message processing for the orchestrator.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Process and route different message types
  # - Normalize message keys for consistent access
  # - Handle process registration, progress updates, failures, and completion
  # - Manage process state transitions
  #
  class MessageHandler
    def initialize(config, processes, all_failures, process_thresholds)
      @config = config
      @processes = processes
      @all_failures = all_failures
      @process_thresholds = process_thresholds
      @process_registry = ProcessRegistry.new(processes, process_thresholds)
    end

    # Process a message and route it to the appropriate handler
    # @param message [Hash] The message to process
    def handle_message(message)
      # Normalize message to use string keys for consistent access
      # (IPC messages come with string keys, direct messages come with symbol keys)
      normalized_message = normalize_message_keys(message)

      case normalized_message['type']
      when 'register'
        @process_registry.register_process(normalized_message)
      when 'progress'
        @process_registry.update_process_progress(normalized_message)
      when 'failure'
        handle_failure(normalized_message)
      when 'complete'
        @process_registry.complete_process(normalized_message)
      when 'error'
        handle_error(normalized_message)
      end
    end

    # Normalize message keys for consistent access
    # @param message [Hash] The message to normalize
    # @return [Hash] The normalized message
    def normalize_message_keys(message)
      # Convert symbol keys to string keys for consistent access
      if message.is_a?(Hash)
        message.transform_keys(&:to_s)
      else
        message
      end
    end

    private

    def handle_failure(message)
      @all_failures << {
        process_id: message['process_id'], description: message['description'],
        location: message['location'], message: message['message']
      }
    end

    def handle_error(message)
      warn "Orchestrator error: #{message['error']}" unless @config['environment']['no_suppress']
    end
  end
end