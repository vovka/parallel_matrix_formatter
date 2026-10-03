# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# Dogfooding: the specs run split across processes with the formatter itself.
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_path = Gem.bin_path('parallel_split_test', 'parallel_split_test')
  task.rspec_opts = '--format ParallelMatrixFormatter::Formatter'
end
RuboCop::RakeTask.new

desc 'Run tests'
task default: %i[spec rubocop]
