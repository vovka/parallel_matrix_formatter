# frozen_string_literal: true

module ParallelMatrixFormatter
  module Output
    # Redirects the process's stdout and stderr to /dev/null and keeps a private
    # copy of the original stdout for the display. The redirection happens at
    # the file descriptor level, so output written through loggers holding
    # STDOUT, C extensions or child processes is silenced as well.
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

        private

        def redirect_to_null
          terminal = STDOUT.dup
          terminal.sync = true
          STDOUT.reopen(File::NULL, 'w')
          STDERR.reopen(File::NULL, 'w')
          terminal
        end
      end
    end
  end
end
