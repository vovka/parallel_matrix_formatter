# frozen_string_literal: true

require_relative 'parallel_matrix_formatter/version'
require_relative 'parallel_matrix_formatter/config'
require_relative 'parallel_matrix_formatter/symbol_renderer'
require_relative 'parallel_matrix_formatter/output_suppressor'
require_relative 'parallel_matrix_formatter/orchestrator'

require_relative 'parallel_matrix_formatter/formatter'

module ParallelMatrixFormatter
end

RSpec::Core::Formatters.register(
  ParallelMatrixFormatter::Formatter,
  :start,
  :example_started,
  :example_passed,
  :example_failed,
  :example_pending,
  :dump_summary,
  :dump_failures,
  :dump_pending,
  :dump_profile,
  :stop,
  :close
)
