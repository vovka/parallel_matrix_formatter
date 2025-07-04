# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/output/suppressor'

RSpec.describe ParallelMatrixFormatter::Output::Suppressor do
  let(:original_stdout) { $stdout }

  before do
    # Reset the class variable and its state before each test
    described_class.class_variable_set(:@@suppressed, false)
  end

  after do
    # Ensure stdout is always restored
    $stdout = original_stdout
  end

  describe '#suppress' do
    let(:config) { { "suppress" => true } }

    it 'replaces $stdout with a NullIO object' do
      suppressor = described_class.new(config)
      suppressor.suppress
      expect($stdout).to be_an_instance_of(ParallelMatrixFormatter::Output::NullIO)
    end

    it 'disables RSpec warnings' do
      suppressor = described_class.new(config)
      suppressor.suppress
      expect(RSpec::Support.warning_notifier.call('a warning')).to be_nil
    end
  end

  describe '#restore' do
    let(:config) { { "suppress" => true } }

    it 'restores the original $stdout' do
      suppressor = described_class.new(config)
      suppressor.suppress
      suppressor.restore
      expect($stdout).to eq(original_stdout)
    end
  end

  describe '#notify' do
    let(:output) { StringIO.new }

    context 'when Rails is defined and deprecations are not silenced' do
      let(:config) { { "suppress" => true } }

      before do
        # Mock Rails environment
        rails_app = double('Rails.application', config: double('config', active_support: double('active_support', deprecation: :log)))
        stub_const('Rails', double('Rails', application: rails_app, respond_to?: true))
      end

      it 'prints a warning message to the output' do
        suppressor = described_class.new(config)
        suppressor.notify(output)
        expect(output.string).to include('For better exeperience, set config.active_support.deprecation = :silence')
      end
    end

    context 'when Rails is not defined' do
      let(:config) { { "suppress" => true } }

      it 'does not print a message' do
        # Ensure Rails is not defined for this context
        hide_const('Rails') if defined?(Rails)
        suppressor = described_class.new(config)
        suppressor.notify(output)
        expect(output.string).to be_empty
      end
    end
  end
end
