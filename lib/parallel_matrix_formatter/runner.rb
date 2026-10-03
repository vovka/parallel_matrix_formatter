# frozen_string_literal: true

require 'json'

module ParallelMatrixFormatter
  # Describes the parallel runner that started this process: how many processes
  # it runs, which run they belong to and, where the runner keeps one, the file
  # listing the processes that are still alive.
  #
  # parallel_split_test forks every process from one runner, so the constant
  # ParallelSplitTest knows the count and the parent pid identifies the run.
  # parallel_tests spawns every process from one parallel_rspec, which exports
  # the requested number of groups and a pid file that is unique per run.
  # Without a runner the only process is process 1 itself, so its own pid
  # identifies the run; the parent pid would be shared by every rspec started
  # from the same shell.
  Runner = Struct.new(:process_count, :run_id, :pid_file, keyword_init: true) do
    def self.detect
      if defined?(::ParallelSplitTest)
        new(process_count: ::ParallelSplitTest.processes, run_id: Process.ppid)
      elsif ENV['PARALLEL_TEST_GROUPS']
        parallel_tests
      else
        new(process_count: 1, run_id: Process.pid)
      end
    end

    def self.parallel_tests
      pid_file = ENV.fetch('PARALLEL_PID_FILE', nil)
      new(process_count: [ENV['PARALLEL_TEST_GROUPS'].to_i, 1].max,
          run_id: pid_file ? File.basename(pid_file) : Process.ppid, pid_file: pid_file)
    end

    # @return [Array<Integer>, nil] pids of the test processes still running, or
    #   nil when unknown: no pid file, or one that is empty or half written
    def live_pids
      return unless pid_file

      pids = JSON.parse(File.read(pid_file))
      pids if pids.is_a?(Array)
    rescue JSON::ParserError, SystemCallError
      nil
    end
  end
end
