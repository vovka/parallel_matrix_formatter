#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test the Matrix Digital Rain formatter rendering
require_relative '../lib/parallel_matrix_formatter/rendering/update_renderer'
require_relative '../lib/parallel_matrix_formatter/rendering/symbol_renderer'

puts 'Matrix Digital Rain Formatter Demo'
puts '=' * 50
puts

# Demo UpdateRenderer
puts 'UpdateRenderer Demo:'
update_renderer = ParallelMatrixFormatter::Rendering::UpdateRenderer.new(1) # Process 1

puts "Simulating updates for process 1:"
update_renderer.update({ 'process_number' => 1, 'message' => { 'status' => :passed, 'progress' => 0.25 } })
sleep(0.1)
update_renderer.update({ 'process_number' => 1, 'message' => { 'status' => :failed, 'progress' => 0.50 } })
sleep(0.1)
update_renderer.update({ 'process_number' => 1, 'message' => { 'status' => :pending, 'progress' => 0.75 } })
sleep(0.1)
update_renderer.update({ 'process_number' => 1, 'message' => { 'status' => :passed, 'progress' => 1.0 } })
puts

puts "Simulating updates for process 2:"
update_renderer.update({ 'process_number' => 2, 'message' => { 'status' => :passed, 'progress' => 0.33 } })
sleep(0.1)
update_renderer.update({ 'process_number' => 2, 'message' => { 'status' => :failed, 'progress' => 0.66 } })
sleep(0.1)
update_renderer.update({ 'process_number' => 2, 'message' => { 'status' => :pending, 'progress' => 1.0 } })
puts

# Demo SymbolRenderer
puts 'SymbolRenderer Demo:'
symbol_renderer = ParallelMatrixFormatter::Rendering::SymbolRenderer.new(1) # Process 1

puts "Passed symbol: #{symbol_renderer.render_passed}"
puts "Failed symbol: #{symbol_renderer.render_failed}"
puts "Pending symbol: #{symbol_renderer.render_pending}"
puts

symbol_renderer_process_b = ParallelMatrixFormatter::Rendering::SymbolRenderer.new(2) # Process 2
puts "Passed symbol (Process B): #{symbol_renderer_process_b.render_passed}"
puts "Failed symbol (Process B): #{symbol_renderer_process_b.render_failed}"
puts "Pending symbol (Process B): #{symbol_renderer_process_b.render_pending}"
puts

puts "Demo complete."