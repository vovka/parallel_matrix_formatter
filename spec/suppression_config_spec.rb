# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/suppression_config'

RSpec.describe ParallelMatrixFormatter::SuppressionConfig do
  let(:base_config) do
    {
      'suppression' => {
        'level' => 'auto',
        'no_suppress' => false,
        'respect_debug' => false
      }
    }
  end

  describe '#determine_level' do
    context 'with auto level (default behavior)' do
      it 'returns runner level for test runners' do
        config = ParallelMatrixFormatter::SuppressionConfig.new(base_config)
        level = config.determine_level(is_runner: true)
        expect(level).to eq(:runner)
      end

      it 'returns all level for orchestrators' do
        config = ParallelMatrixFormatter::SuppressionConfig.new(base_config)
        level = config.determine_level(is_orchestrator: true)
        expect(level).to eq(:all)
      end

      it 'returns all level for other processes' do
        config = ParallelMatrixFormatter::SuppressionConfig.new(base_config)
        level = config.determine_level
        expect(level).to eq(:all)
      end
    end

    context 'with explicit level configuration' do
      it 'respects explicit level setting' do
        config_with_level = base_config.dup
        config_with_level['suppression']['level'] = 'ruby_warnings'
        
        config = ParallelMatrixFormatter::SuppressionConfig.new(config_with_level)
        level = config.determine_level(is_runner: true)
        expect(level).to eq(:ruby_warnings)
      end

      it 'falls back to auto when level is auto' do
        config_with_auto = base_config.dup
        config_with_auto['suppression']['level'] = 'auto'
        
        config = ParallelMatrixFormatter::SuppressionConfig.new(config_with_auto)
        level = config.determine_level(is_runner: true)
        expect(level).to eq(:runner)
      end
    end
  end

  describe '#suppression_disabled?' do
    it 'returns true when no_suppress is set' do
      config_no_suppress = base_config.dup
      config_no_suppress['suppression']['no_suppress'] = true
      
      config = ParallelMatrixFormatter::SuppressionConfig.new(config_no_suppress)
      expect(config.suppression_disabled?).to be true
    end

    it 'returns false when no_suppress is false' do
      config = ParallelMatrixFormatter::SuppressionConfig.new(base_config)
      expect(config.suppression_disabled?).to be false
    end
  end

  describe 'level checking methods' do
    let(:config) { ParallelMatrixFormatter::SuppressionConfig.new(base_config) }

    it 'correctly identifies Ruby warning suppression levels' do
      expect(config.suppresses_ruby_warnings?(:none)).to be false
      expect(config.suppresses_ruby_warnings?(:ruby_warnings)).to be true
      expect(config.suppresses_ruby_warnings?(:all)).to be true
      expect(config.suppresses_ruby_warnings?(:runner)).to be true
    end

    it 'correctly identifies stderr suppression levels' do
      expect(config.suppresses_stderr?(:none)).to be false
      expect(config.suppresses_stderr?(:ruby_warnings)).to be false
      expect(config.suppresses_stderr?(:app_output)).to be true
      expect(config.suppresses_stderr?(:all)).to be true
      expect(config.suppresses_stderr?(:runner)).to be true
    end

    it 'correctly identifies stdout suppression levels' do
      expect(config.suppresses_stdout?(:none)).to be false
      expect(config.suppresses_stdout?(:app_output)).to be false
      expect(config.suppresses_stdout?(:gem_output)).to be true
      expect(config.suppresses_stdout?(:all)).to be true
      expect(config.suppresses_stdout?(:runner)).to be true
    end

    it 'correctly identifies complete suppression levels' do
      expect(config.complete_suppression?(:none)).to be false
      expect(config.complete_suppression?(:all)).to be false
      expect(config.complete_suppression?(:runner)).to be true
    end
  end

  describe 'level values' do
    let(:config) { ParallelMatrixFormatter::SuppressionConfig.new(base_config) }

    it 'returns correct numeric values for levels' do
      expect(config.level_value(:none)).to eq(0)
      expect(config.level_value(:ruby_warnings)).to eq(1)
      expect(config.level_value(:app_warnings)).to eq(2)
      expect(config.level_value(:app_output)).to eq(3)
      expect(config.level_value(:gem_output)).to eq(4)
      expect(config.level_value(:all)).to eq(5)
      expect(config.level_value(:runner)).to eq(6)
    end
  end
end