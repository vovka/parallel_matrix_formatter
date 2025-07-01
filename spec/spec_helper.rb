# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each) do
    allow_any_instance_of(ParallelMatrixFormatter::Config).to receive(:update_renderer_config).and_return({})
    allow_any_instance_of(ParallelMatrixFormatter::Config).to receive(:suppress).and_return(true)
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = false

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end