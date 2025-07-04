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
require_relative 'parallel_matrix_formatter/rendering/update_renderer/format_helper'
require_relative 'parallel_matrix_formatter/rendering/update_renderer/progress_update_policy'
require_relative 'parallel_matrix_formatter/rendering/update_renderer/progress_updater'
require_relative 'parallel_matrix_formatter/rendering/update_renderer/status_renderer'
require_relative 'parallel_matrix_formatter/rendering/update_renderer'
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
