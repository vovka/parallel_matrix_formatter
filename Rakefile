# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require_relative 'spec/support/released_formatter'

file ReleasedFormatter::ENTRY do
  Bundler.with_unbundled_env { sh(*ReleasedFormatter.install_command) }
end

# Dogfooding: the specs run split across processes and are rendered by the
# formatter as released on RubyGems, see spec/support/released_formatter.rb.
RSpec::Core::RakeTask.new(spec: ReleasedFormatter::ENTRY) do |task|
  task.rspec_path = Gem.bin_path('parallel_split_test', 'parallel_split_test')
  task.rspec_opts = '--require ./spec/support/use_released_formatter --format ReleasedMatrixFormatter::Formatter'
end
RuboCop::RakeTask.new

desc 'Run tests'
task default: %i[spec rubocop]
