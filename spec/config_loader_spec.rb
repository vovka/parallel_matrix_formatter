# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter'

RSpec.describe ParallelMatrixFormatter::ConfigLoader do
  describe '.load' do
    context 'with default configuration' do
      it 'loads default config when no config file exists' do
        config = described_class.load

        expect(config).to be_a(Hash)
        expect(config['digits']).to be_a(Hash)
        expect(config['colors']).to be_a(Hash)
        expect(config['update']).to be_a(Hash)
      end
    end

    context 'with custom digits' do
      it 'validates custom digits section' do
        expect do
          config = {
            'digits' => {
              'use_custom' => true,
              'symbols' => '012345678' # Only 9 digits
            }
          }
          loader = described_class.new
          loader.send(:validate_config, loader.send(:merge_with_defaults, config))
        end.to raise_error(ParallelMatrixFormatter::ConfigLoader::ConfigError, /exactly 10 symbols/)
      end

      it 'processes custom digits correctly' do
        config = described_class.load

        expect(config['digits']['symbols_chars']).to be_an(Array)
        expect(config['katakana_alphabet_chars']).to be_an(Array)
        expect(config['pass_symbols_chars']).to be_an(Array)
        expect(config['fail_symbols_chars']).to be_an(Array)
      end
    end

    context 'with environment variables' do
      it 'loads simplified environment configuration (debug/color vars removed)' do
        config = described_class.load

        expect(config['environment']).to be_a(Hash)
        expect(config['environment']['force_orchestrator']).to be(true).or be(false)
        expect(config['environment']['is_parallel']).to be(true).or be(false)
        # Debug and color environment variables have been removed
        expect(config['environment']['debug']).to be_nil
        expect(config['environment']['no_color']).to be_nil
        expect(config['environment']['force_color']).to be_nil
        expect(config['environment']['is_ci']).to be_nil
      end

      it 'processes orchestrator environment variable' do
        old_env = ENV['PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR']
        ENV['PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR'] = 'true'
        
        config = described_class.load
        expect(config['environment']['force_orchestrator']).to be true
        
      ensure
        ENV['PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR'] = old_env
      end

      it 'no longer processes debug or color environment variables (removed)' do
        # Verify that debug and color environment variables are no longer processed
        old_debug = ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        old_no_color = ENV['NO_COLOR']
        old_force_color = ENV['FORCE_COLOR']
        
        ENV['PARALLEL_MATRIX_FORMATTER_DEBUG'] = 'true'
        ENV['NO_COLOR'] = '1'
        ENV['FORCE_COLOR'] = 'true'
        
        config = described_class.load
        # These should all be nil since we removed debug/color environment processing
        expect(config['environment']['debug']).to be_nil
        expect(config['environment']['no_color']).to be_nil
        expect(config['environment']['force_color']).to be_nil
        
      ensure
        ENV['PARALLEL_MATRIX_FORMATTER_DEBUG'] = old_debug
        ENV['NO_COLOR'] = old_no_color
        ENV['FORCE_COLOR'] = old_force_color
      end

      it 'detects parallel execution environment' do
        old_parallel = ENV['PARALLEL_WORKERS']
        ENV['PARALLEL_WORKERS'] = '4'
        
        config = described_class.load
        expect(config['environment']['is_parallel']).to be true
        
      ensure
        ENV['PARALLEL_WORKERS'] = old_parallel
      end
    end

    context 'config object immutability' do
      it 'returns a frozen configuration object' do
        config = described_class.load
        
        expect(config).to be_frozen
        expect(config['environment']).to be_frozen
        expect(config['colors']).to be_frozen
        expect(config['digits']).to be_frozen
      end

      it 'prevents modification of nested hashes' do
        config = described_class.load
        
        expect { config['new_key'] = 'value' }.to raise_error(FrozenError)
        expect { config['environment']['new_key'] = 'value' }.to raise_error(FrozenError)
        expect { config['colors']['new_color'] = 'blue' }.to raise_error(FrozenError)
      end
    end
  end
end
