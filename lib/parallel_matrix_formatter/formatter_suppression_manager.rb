# frozen_string_literal: true

require_relative 'suppression_layer'
require_relative 'early_suppression_manager'

module ParallelMatrixFormatter
  # FormatterSuppressionManager handles suppression setup for formatter processes.
  # This class was extracted from Formatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Set up appropriate suppression based on process role
  # - Coordinate with early suppression manager
  # - Handle orchestrator vs worker suppression differently
  # - Preserve original IO for orchestrator processes
  #
  class FormatterSuppressionManager
    def initialize(config)
      @config = config
      @suppression_layer = nil
    end

    # Set up environment-appropriate suppression
    # @param is_orchestrator [Boolean] Whether this is the orchestrator process
    def setup_suppression(is_orchestrator)
      # If early suppression was applied and we're the orchestrator, we need to restore it
      # so the orchestrator can output
      if EarlySuppressionManager.early_suppression_applied? && is_orchestrator
        EarlySuppressionManager.restore_for_orchestrator
      end
      
      # For role-based suppression: only suppress non-orchestrator processes at the formatter level
      # ProcessFormatter will handle its own suppression regardless of process role
      should_suppress = !is_orchestrator
      
      if should_suppress
        # Apply suppression for non-orchestrator processes
        @suppression_layer = SuppressionLayer.new(@config)
        @suppression_layer.suppress(
          level: :auto,
          is_orchestrator: is_orchestrator,
          is_runner: true  # Non-orchestrator processes are typically runners
        )
      else
        # Orchestrator processes: preserve original IO but don't suppress at formatter level
        # ProcessFormatter within orchestrator will handle its own suppression
        SuppressionLayer.preserve_original_io
      end
    end

    # Restore suppression if active
    def restore_suppression
      @suppression_layer&.restore
    end

    # Determine suppression level (for backward compatibility)
    # @param is_orchestrator [Boolean] Whether this is the orchestrator process
    # @return [Symbol] Suppression level
    def determine_suppression_level(is_orchestrator)
      # This method is kept for backward compatibility but is no longer used
      # The SuppressionLayer now determines levels automatically based on config
      is_orchestrator ? :all : :runner
    end
  end
end