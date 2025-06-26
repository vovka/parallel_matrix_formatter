# frozen_string_literal: true

require_relative 'suppression_layer'

module ParallelMatrixFormatter
  # EarlySuppressionManager handles early suppression application during class loading.
  # This class was extracted from Formatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Detect parallel testing environment at class load time
  # - Apply early suppression to prevent output leakage during initialization
  # - Manage early suppression state and restoration
  # - Provide reset functionality for testing scenarios
  #
  class EarlySuppressionManager
    @@early_suppression_applied = false
    @@early_suppression_layer = nil

    # Detect parallel testing environment and apply early suppression if needed
    # @return [void]
    def self.apply_early_suppression_if_needed
      return if @@early_suppression_applied
      
      # Only apply early suppression if we detect we're in a parallel testing environment
      # We need to check ENV directly here since config isn't loaded yet
      if ENV['PARALLEL_SPLIT_TEST_PROCESSES'] || ENV['PARALLEL_WORKERS'] || ENV['TEST_ENV_NUMBER']
        begin
          # Apply complete suppression early to prevent output leakage during class loading
          # Create minimal config for early suppression since ConfigLoader isn't available yet
          minimal_config = {
            'suppression' => {
              'level' => 'runner',
              'no_suppress' => false,
              'respect_debug' => false
            }
          }
          
          @@early_suppression_layer = SuppressionLayer.new(minimal_config)
          @@early_suppression_layer.suppress(level: :runner, is_runner: true)
          @@early_suppression_applied = true
        rescue => e
          # If early suppression fails, don't break the test run
          # Just continue without early suppression
        end
      end
    end
    
    # Reset early suppression state (useful for testing)
    # @return [void]
    def self.reset_early_suppression
      if @@early_suppression_applied
        @@early_suppression_layer&.restore
        @@early_suppression_applied = false
      end
    end

    # Check if early suppression has been applied
    # @return [Boolean] True if early suppression is active
    def self.early_suppression_applied?
      @@early_suppression_applied
    end

    # Restore early suppression if it's still active
    # @return [void]
    def self.restore_early_suppression_if_needed
      if @@early_suppression_applied
        begin
          @@early_suppression_layer&.restore
          @@early_suppression_applied = false
        rescue => e
          # Silently continue if restoration fails
        end
      end
    end

    # Restore early suppression for orchestrator processes
    # @return [void]
    def self.restore_for_orchestrator
      if @@early_suppression_applied
        begin
          @@early_suppression_layer&.restore
          @@early_suppression_applied = false
        rescue => e
          # Silently continue if restoration fails
        end
      end
    end
  end
end