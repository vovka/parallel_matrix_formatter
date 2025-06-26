# frozen_string_literal: true

# Parallel Matrix Formatter - RSpec formatter with Matrix-style digital rain display
#
# REFACTORING CHANGES (Issue #11):
# ===============================
# 
# Debug Logic Removal:
# - Removed all debug-related environment variable handling from ConfigLoader
# - Removed debug_puts methods and debug conditional blocks from all classes  
# - Eliminated PARALLEL_MATRIX_FORMATTER_DEBUG and related env var processing
# - Simplified error handling to remove debug warnings
#
# Color Logic Simplification:
# - DigitalRainRenderer now only outputs ANSI color codes, no environment detection
# - Removed NO_COLOR, FORCE_COLOR, and CI environment color detection
# - Created AnsiColorizer class for consistent ANSI color handling (47 lines)
# - Removed Rainbow gem dependency detection and complex color method selection
#
# Class Size Reduction:
# - Split FailureSummaryRenderer from DigitalRainRenderer (93 lines)
# - Reduced DigitalRainRenderer from 301 to 246 lines
# - AnsiColorizer extracted as focused 47-line utility class
#
# The formatter now has cleaner, more predictable behavior with consistent ANSI output.

require_relative 'parallel_matrix_formatter/version'
require_relative 'parallel_matrix_formatter/config_loader'
require_relative 'parallel_matrix_formatter/suppression_layer'
require_relative 'parallel_matrix_formatter/orchestrator'
require_relative 'parallel_matrix_formatter/process_formatter'
require_relative 'parallel_matrix_formatter/digital_rain_renderer'
require_relative 'parallel_matrix_formatter/ansi_colorizer'
require_relative 'parallel_matrix_formatter/failure_summary_renderer'
require_relative 'parallel_matrix_formatter/update_strategies'
require_relative 'parallel_matrix_formatter/ipc'
require_relative 'parallel_matrix_formatter/formatter'

module ParallelMatrixFormatter
  class Error < StandardError; end
end
