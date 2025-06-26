#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test the Matrix Digital Rain formatter rendering
require_relative '../lib/parallel_matrix_formatter/config_loader'
require_relative '../lib/parallel_matrix_formatter/digital_rain_renderer'

config = ParallelMatrixFormatter::ConfigLoader.load
renderer = ParallelMatrixFormatter::DigitalRainRenderer.new(config)

puts 'Matrix Digital Rain Formatter Demo'
puts '=' * 50
puts

# Demo time rendering
puts 'Time Column:'
time_column = renderer.render_time_column
puts time_column
puts

# Demo process columns with different progress levels
puts 'Process Columns:'
[25, 50, 75, 100].each_with_index do |progress, index|
  process_column = renderer.render_process_column(index + 1, progress, 15)
  puts "Process #{index + 1} (#{progress}%): #{process_column}"
end
puts

# Demo test dots
puts 'Test Result Dots:'
test_results = [
  { status: :passed },
  { status: :failed },
  { status: :pending },
  { status: :passed },
  { status: :failed }
]
test_dots = renderer.render_test_dots(test_results)
puts test_dots
puts

# Demo full matrix line
puts 'Full Matrix Line:'
time_col = renderer.render_time_column
process_cols = [
  renderer.render_process_column(1, 34, 15),
  renderer.render_process_column(2, 67, 15)
]
dots = renderer.render_test_dots([
                                   { status: :passed },
                                   { status: :failed },
                                   { status: :pending },
                                   { status: :passed },
                                   { status: :passed }
                                 ])
matrix_line = renderer.render_matrix_line(time_col, process_cols, dots)
puts matrix_line
puts

# Demo final summary
puts 'Final Summary:'
summary = renderer.render_final_summary(100, 5, 2, 45.5, [20.1, 25.4], 2)
puts summary
