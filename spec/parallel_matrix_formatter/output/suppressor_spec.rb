# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/output/suppressor'

RSpec.describe ParallelMatrixFormatter::Output::Suppressor do
  let(:suppressor) { described_class.instance }
  let(:original_stdout) { $stdout }
  let(:config) { instance_double(ParallelMatrixFormatter::Config, suppress: true) }

  before do
    allow(ParallelMatrixFormatter::Config).to receive(:instance).and_return(config)
    # Reset the singleton and its state before each test
    described_class.instance_variable_set(:@suppressed, nil)
    suppressor.restore
  end

  after do
    # Ensure stdout is always restored
    $stdout = original_stdout
  end

  describe '.suppress' do
    context 'when suppression is enabled in config' do
      it 'calls the suppress instance method' do
        expect(suppressor).to receive(:suppress)
        described_class.suppress
      end

      it 'only suppresses once' do
        expect(suppressor).to receive(:suppress).once
        described_class.suppress
        described_class.suppress
      end
    end

    context 'when suppression is disabled in config' do
      let(:config) { instance_double(ParallelMatrixFormatter::Config, suppress: false) }

      it 'does not call the suppress instance method' do
        expect(suppressor).not_to receive(:suppress)
        described_class.suppress
      end
    end
  end

  describe '#suppress' do
    it 'replaces $stdout with a NullIO object' do
      suppressor.suppress
      expect($stdout).to be_an_instance_of(ParallelMatrixFormatter::Output::NullIO)
    end

    it 'disables RSpec warnings' do
      suppressor.suppress
      expect(RSpec::Support.warning_notifier.call('a warning')).to be_nil
    end
  end

  describe '#restore' do
    it 'restores the original $stdout' do
      suppressor.suppress
      suppressor.restore
      expect($stdout).to eq(original_stdout)
    end
  end

  describe '#notify' do
    let(:output) { StringIO.new }

    context 'when Rails is defined and deprecations are not silenced' do
      before do
        # Mock Rails environment
        rails_app = double('Rails.application', config: double('config', active_support: double('active_support', deprecation: :log)))
        stub_const('Rails', double('Rails', application: rails_app, respond_to?: true))
      end

      it 'prints a warning message to the output' do
        suppressor.notify(output)
        expect(output.string).to include('For better exeperience, set config.active_support.deprecation = :silence')
      end
    end

    context 'when Rails is not defined' do
      it 'does not print a message' do
        # Ensure Rails is not defined for this context
        hide_const('Rails') if defined?(Rails)
        suppressor.notify(output)
        expect(output.string).to be_empty
      end
    end
  end
end
