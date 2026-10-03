# frozen_string_literal: true

require 'rspec/core'

require_relative 'parallel_matrix_formatter/version'
require_relative 'parallel_matrix_formatter/config'
require_relative 'parallel_matrix_formatter/output/silencer'
require_relative 'parallel_matrix_formatter/ipc'
require_relative 'parallel_matrix_formatter/ipc/client'
require_relative 'parallel_matrix_formatter/ipc/server'
require_relative 'parallel_matrix_formatter/rendering/colors'
require_relative 'parallel_matrix_formatter/rendering/digits'
require_relative 'parallel_matrix_formatter/rendering/progress_update_policy'
require_relative 'parallel_matrix_formatter/rendering/progress_column'
require_relative 'parallel_matrix_formatter/rendering/progress_line'
require_relative 'parallel_matrix_formatter/rendering/example_status'
require_relative 'parallel_matrix_formatter/rendering/summary'
require_relative 'parallel_matrix_formatter/rendering/display'
require_relative 'parallel_matrix_formatter/null_orchestrator'
require_relative 'parallel_matrix_formatter/orchestrator'
require_relative 'parallel_matrix_formatter/formatter'

# Matrix digital rain RSpec formatter for test suites split across processes
# with parallel_split_test.
#
# Every test process loads the Formatter, which silences the process and sends
# each example's result to process 1 over a UNIX socket. Process 1 also hosts
# the Orchestrator, which renders the shared display and, once every process has
# reported, the consolidated summary.
module ParallelMatrixFormatter
  class Error < StandardError; end
end
