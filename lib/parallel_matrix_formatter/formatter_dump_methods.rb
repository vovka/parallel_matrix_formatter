# frozen_string_literal: true

module ParallelMatrixFormatter
  # Handles dump methods for the Formatter
  class FormatterDumpMethods
    def initialize(orchestrator)
      @orchestrator = orchestrator
    end

    def dump_failures
      @orchestrator.puts("\ndump_failures")
    end

    def dump_pending
      @orchestrator.puts("\ndump_pending")
    end

    def dump_profile
      @orchestrator.puts("\ndump_profile")
    end
  end
end