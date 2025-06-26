# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/suppression_layer'

RSpec.describe ParallelMatrixFormatter::SuppressionLayer do
  let(:base_config) do
    {
      'suppression' => {
        'level' => 'auto',
        'no_suppress' => false,
        'respect_debug' => false
      }
    }
  end

  let(:original_stdout) { $stdout }
  let(:original_stderr) { $stderr }
  let(:original_verbose) { $VERBOSE }

  before do
    # Reset class-level state
    described_class.class_variable_set(:@@io_preserved, false)
    described_class.class_variable_set(:@@active_instance, nil)
  end

  after do
    # Restore original IO
    $stdout = original_stdout
    $stderr = original_stderr
    $VERBOSE = original_verbose
  end

  describe '#suppress' do
    it 'suppresses output for runner level' do
      layer = described_class.new(base_config)
      layer.suppress(level: :runner)

      expect($stdout).to be_a(described_class::NullIO)
      expect($stderr).to be_a(described_class::NullIO)
      expect($VERBOSE).to be_nil
    end

    it 'suppresses only warnings for ruby_warnings level' do
      layer = described_class.new(base_config)
      layer.suppress(level: :ruby_warnings)

      expect($stdout).to eq(original_stdout)
      expect($stderr).to eq(original_stderr)
      expect($VERBOSE).to be_nil
    end

    it 'tracks active level' do
      layer = described_class.new(base_config)
      expect(layer.active_level).to be_nil

      layer.suppress(level: :all)
      expect(layer.active_level).to eq(:all)
    end

    it 'ensures only one suppression layer is active' do
      layer1 = described_class.new(base_config)
      layer2 = described_class.new(base_config)

      layer1.suppress(level: :ruby_warnings)
      expect(layer1.active_level).to eq(:ruby_warnings)

      # This should replace layer1's suppression
      layer2.suppress(level: :all)
      expect(layer1.active_level).to be_nil
      expect(layer2.active_level).to eq(:all)
    end

    it 'skips suppression when disabled in config' do
      no_suppress_config = base_config.dup
      no_suppress_config['suppression']['no_suppress'] = true

      layer = described_class.new(no_suppress_config)
      layer.suppress(level: :runner)

      expect($stdout).to eq(original_stdout)
      expect($stderr).to eq(original_stderr)
      expect($VERBOSE).to eq(original_verbose)
      expect(layer.active_level).to be_nil
    end
  end

  describe '#restore' do
    it 'restores original IO streams' do
      layer = described_class.new(base_config)
      layer.suppress(level: :runner)

      # Verify suppression is active
      expect($stdout).to be_a(described_class::NullIO)
      expect($stderr).to be_a(described_class::NullIO)

      layer.restore

      # Verify restoration
      expect($stdout).to eq(original_stdout)
      expect($stderr).to eq(original_stderr)
      expect($VERBOSE).to eq(original_verbose)
      expect(layer.active_level).to be_nil
    end
  end

  describe '.suppress_with_config' do
    it 'creates and applies suppression in one call' do
      described_class.suppress_with_config(base_config, level: :runner)

      expect($stdout).to be_a(described_class::NullIO)
      expect($stderr).to be_a(described_class::NullIO)
    end
  end

  describe '.restore_all' do
    it 'restores active suppression' do
      described_class.suppress_with_config(base_config, level: :runner)
      described_class.restore_all

      expect($stdout).to eq(original_stdout)
      expect($stderr).to eq(original_stderr)
    end
  end

  describe '.suppress_runner_output' do
    it 'applies complete suppression for backward compatibility' do
      described_class.suppress_runner_output(base_config)

      expect($stdout).to be_a(described_class::NullIO)
      expect($stderr).to be_a(described_class::NullIO)
      expect($VERBOSE).to be_nil
    end

    it 'works without config for backward compatibility' do
      described_class.suppress_runner_output

      expect($stdout).to be_a(described_class::NullIO)
      expect($stderr).to be_a(described_class::NullIO)
      expect($VERBOSE).to be_nil
    end
  end

  describe 'IO preservation' do
    it 'preserves original IO streams at class level' do
      described_class.preserve_original_io
      
      expect(described_class.original_stdout).to eq(original_stdout)
      expect(described_class.original_stderr).to eq(original_stderr)
    end
  end
end