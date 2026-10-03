# frozen_string_literal: true

require 'tmpdir'

module ParallelMatrixFormatter
  # Communication between the test processes and the orchestrator: newline
  # separated JSON messages over a UNIX socket.
  module Ipc
    # @param run_id [String, Integer] identifies the run, see Runner#run_id
    def self.socket_path(run_id)
      File.join(Dir.tmpdir, "parallel_matrix_formatter-#{run_id}.sock")
    end
  end
end
