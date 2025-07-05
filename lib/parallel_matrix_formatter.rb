# frozen_string_literal: true

require_relative 'parallel_matrix_formatter/version'
require_relative 'parallel_matrix_formatter/config/progress_column_parser'
require_relative 'parallel_matrix_formatter/config'

# Module definitions
require_relative 'parallel_matrix_formatter/ipc'
require_relative 'parallel_matrix_formatter/output'
require_relative 'parallel_matrix_formatter/rendering'

# Class definitions
require_relative 'parallel_matrix_formatter/ipc/client'
require_relative 'parallel_matrix_formatter/ipc/server'
require_relative 'parallel_matrix_formatter/output/null_io'
require_relative 'parallel_matrix_formatter/output/suppressor'
require_relative 'parallel_matrix_formatter/rendering/ansi_color'
require_relative 'parallel_matrix_formatter/rendering/update_renderer'
require_relative 'parallel_matrix_formatter/failed_example_collector'
require_relative 'parallel_matrix_formatter/summary_data_builder'
require_relative 'parallel_matrix_formatter/formatter_initializer'
require_relative 'parallel_matrix_formatter/formatter_notifier'
require_relative 'parallel_matrix_formatter/formatter_dump_methods'
require_relative 'parallel_matrix_formatter/process_tracker'
require_relative 'parallel_matrix_formatter/summary_collector'
require_relative 'parallel_matrix_formatter/consolidated_summary_renderer'
require_relative 'parallel_matrix_formatter/summary_waiter'
require_relative 'parallel_matrix_formatter/orchestrator_message_handler'
require_relative 'parallel_matrix_formatter/buffered_message_processor'
require_relative 'parallel_matrix_formatter/orchestrator_initializer'
require_relative 'parallel_matrix_formatter/blank_orchestrator'
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
