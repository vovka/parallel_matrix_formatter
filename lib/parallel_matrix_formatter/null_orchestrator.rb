# frozen_string_literal: true

module ParallelMatrixFormatter
  # Stands in for the Orchestrator in every process but process 1, which only
  # report to the orchestrator and never render anything themselves.
  class NullOrchestrator
    def close; end
  end
end
