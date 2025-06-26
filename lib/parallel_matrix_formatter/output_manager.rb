# frozen_string_literal: true

require_relative 'suppression_layer'

module ParallelMatrixFormatter
  # OutputManager handles output operations for the orchestrator.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Manage output to stdout/stderr bypassing suppression
  # - Handle print, puts, and flush operations consistently
  # - Provide fallback mechanisms when original streams unavailable
  #
  class OutputManager
    # Print a line of output with newline
    # @param message [String] Message to output (default: empty string)
    def puts(message = '')
      # Use original stdout for orchestrator output, bypassing suppression
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.puts(message)
      else
        # Fallback to regular puts if original stdout not available
        Kernel.puts(message)
      end
    end

    # Print output without newline
    # @param message [String] Message to output
    def print(message)
      # Use original stdout for orchestrator output, bypassing suppression
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.print(message)
      else
        # Fallback to regular print if original stdout not available
        Kernel.print(message)
      end
    end

    # Flush output buffer
    def flush
      # Flush original stdout for orchestrator output
      if SuppressionLayer.original_stdout
        SuppressionLayer.original_stdout.flush
      else
        # Fallback to regular flush if original stdout not available
        $stdout.flush
      end
    end
  end
end