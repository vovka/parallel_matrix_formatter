# frozen_string_literal: true

# Matrix digital rain RSpec formatter for test suites split across processes
# with parallel_split_test or parallel_tests.
#
# Every test process loads the Formatter, which silences the process and sends
# each example's result to process 1 over a UNIX socket. Process 1 also hosts
# the Orchestrator, which renders the shared display and, once every process has
# reported, the consolidated summary.

require 'rspec/core'

require_relative 'parallel_matrix_formatter/version'
require_relative 'parallel_matrix_formatter/error'
require_relative 'parallel_matrix_formatter/formatter'
