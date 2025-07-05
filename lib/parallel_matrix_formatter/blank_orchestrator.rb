# frozen_string_literal: true

module ParallelMatrixFormatter
  # The BlankOrchestrator is a no-op orchestrator used when the current process
  # is not the primary process (i.e., `test_env_number` is not 1).
  class BlankOrchestrator
    def initialize(*); end
    def puts(*); end
    def start(*); end
    def close(*); end
    def all_processes_complete?; true; end
  end
end