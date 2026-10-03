# frozen_string_literal: true

require 'tempfile'
require_relative '../support/child_process'

# Loading the file silences the process, so it is loaded in a forked child
# whose output goes to a pipe.
RSpec.describe 'parallel_matrix_formatter/silence' do
  include ChildProcess

  let(:path) { File.expand_path('../../lib/parallel_matrix_formatter/silence.rb', __dir__) }
  let(:config_file) { Tempfile.new(['config', '.yml']) }

  before do
    config_file.write("suppress_output: #{suppress_output}\n")
    config_file.close
  end

  after { config_file.unlink }

  def load_in_child
    capture_from_child do
      ENV['PARALLEL_MATRIX_FORMATTER_CONFIG'] = config_file.path
      load path
      STDOUT.write('visible')
    end
  end

  context 'when suppress_output is true' do
    let(:suppress_output) { true }

    it 'silences the process' do
      expect(load_in_child).to eq('')
    end
  end

  context 'when suppress_output is false' do
    let(:suppress_output) { false }

    it 'leaves the output alone' do
      expect(load_in_child).to eq('visible')
    end
  end
end
