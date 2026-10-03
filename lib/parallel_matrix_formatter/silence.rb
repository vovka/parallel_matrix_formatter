# frozen_string_literal: true

# Silences the process as early as possible. RSpec only instantiates the
# formatter after the --require'd files have loaded, so output printed while
# the application boots would otherwise reach the terminal. Load this file
# before anything else to silence it:
#
#   RUBYOPT="-rparallel_matrix_formatter/silence" bundle exec parallel_split_test ...
require_relative 'config'
require_relative 'output/silencer'

ParallelMatrixFormatter::Output::Silencer.silence if ParallelMatrixFormatter::Config.load['suppress_output']
