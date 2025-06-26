# frozen_string_literal: true

require_relative 'orchestrator'
require_relative 'suppression_layer'

module ParallelMatrixFormatter
  # OrchestratorStarter handles orchestrator initialization and startup messaging.
  # This class was extracted from Formatter to reduce class size.
  #
  # Key responsibilities:
  # - Initialize and start the orchestrator
  # - Handle startup messaging and output
  # - Manage fallback scenarios when orchestrator fails to start
  #
  class OrchestratorStarter
    def initialize(config)
      @config = config
    end

    # Start the orchestrator and return it
    # @return [Orchestrator, nil] The started orchestrator or nil if failed
    def start_orchestrator
      orchestrator = Orchestrator.new(@config)

      server_path = orchestrator.start
      if server_path
        # Only output if not suppressed
        unless @config['environment']['no_suppress']
          output_startup_message(server_path)
        end
        orchestrator
      else
        warn 'Failed to start orchestrator - falling back to standard output'
        nil
      end
    end

    private

    def output_startup_message(server_path)
      if SuppressionLayer.original_stderr
        SuppressionLayer.original_stderr.puts 'Matrix Digital Rain formatter started (orchestrator mode)'
        SuppressionLayer.original_stderr.puts "Server: #{server_path}"
      else
        $stderr.puts 'Matrix Digital Rain formatter started (orchestrator mode)'
        $stderr.puts "Server: #{server_path}"
      end
    end
  end
end