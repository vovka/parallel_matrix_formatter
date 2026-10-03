#!/usr/bin/env ruby
# frozen_string_literal: true

# Previews the display without a test suite: ruby demo/matrix_demo.rb
require_relative '../lib/parallel_matrix_formatter'

PROCESSES = 3
EXAMPLES = 40
STATUSES = [*['passed'] * 18, 'pending', 'failed'].freeze

config = ParallelMatrixFormatter::Config.load
config['progress_update'] = { 'always' => false, 'interval_seconds' => 0.5, 'percent_threshold' => 0 }
display = ParallelMatrixFormatter::Rendering::Display.new(config, PROCESSES)

failures = Hash.new(0)
pending = Hash.new(0)
steps = (1..PROCESSES).flat_map { |process| (1..EXAMPLES).map { |step| [process, step] } }
steps.sort_by! { |_process, step| [step, rand] }
steps.each do |process, step|
  status = STATUSES.sample
  failures[process] += 1 if status == 'failed'
  pending[process] += 1 if status == 'pending'
  print display.example(process, status, step.fdiv(EXAMPLES))
  sleep 0.03
end

summaries = (1..PROCESSES).map do |process|
  failed = Array.new(failures[process]) do |index|
    location = "./spec/widget_#{process}_spec.rb:#{10 + index}"
    { 'description' => "Widget ##{process}.#{index} does the thing", 'location' => location,
      'message_lines' => ['Failure/Error: expect(actual).to eq(expected)', '  expected: 1', '       got: 2'],
      'backtrace' => ["# #{location}:in 'block (2 levels) in <top (required)>'"] }
  end
  { 'examples' => EXAMPLES, 'failures' => failures[process], 'pending' => pending[process],
    'duration' => EXAMPLES * 0.03, 'failed_examples' => failed }
end
puts display.summary(summaries, [])
