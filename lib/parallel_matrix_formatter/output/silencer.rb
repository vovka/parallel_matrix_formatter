# frozen_string_literal: true

require 'tmpdir'

module ParallelMatrixFormatter
  module Output
    # Redirects the process's stdout to /dev/null and its stderr to a log file,
    # and keeps a private copy of the original stdout for the display. The
    # redirection happens at the file descriptor level, so output written
    # through loggers holding STDOUT, C extensions or child processes is
    # silenced as well. There is one log per process, named after the run (the
    # parent pid) and the process number.
    module Silencer
      class << self
        # @return [IO] the original stdout
        def silence
          @terminal = redirect_to_null unless silenced?
          @terminal
        end

        def silenced?
          !@terminal.nil?
        end

        # @return [Array<String>] the stderr logs of every process of the run
        def stderr_logs
          @log_prefix ? Dir["#{@log_prefix}-*.stderr.log"] : []
        end

        private

        def redirect_to_null
          terminal = STDOUT.dup
          terminal.sync = true
          STDOUT.reopen(File::NULL, 'w')
          STDERR.reopen(stderr_log_path, 'w')
          STDERR.sync = true
          terminal
        end

        def stderr_log_path
          @log_prefix = File.join(Dir.tmpdir, "parallel_matrix_formatter-#{Process.ppid}")
          "#{@log_prefix}-#{[ENV['TEST_ENV_NUMBER'].to_i, 1].max}.stderr.log"
        end
      end
    end
  end
end
