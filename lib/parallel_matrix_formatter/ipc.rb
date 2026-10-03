# frozen_string_literal: true

require 'tmpdir'

module ParallelMatrixFormatter
  # Communication between the test processes and the orchestrator: newline
  # separated JSON messages over a UNIX socket.
  module Ipc
    # Every process started by parallel_split_test is forked by the same
    # runner, so its pid identifies the run.
    def self.socket_path
      File.join(Dir.tmpdir, "parallel_matrix_formatter-#{Process.ppid}.sock")
    end
  end
end
