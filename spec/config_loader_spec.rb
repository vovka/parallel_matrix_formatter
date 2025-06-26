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
      it 'loads environment configuration' do
        config = described_class.load

        expect(config['environment']).to be_a(Hash)
        expect(config['environment']['no_suppress']).to be_in([true, false])
        expect(config['environment']['is_parallel']).to be_in([true, false])
      end

      it 'detects parallel execution environment' do
        old_parallel = ENV['PARALLEL_WORKERS']
        ENV['PARALLEL_WORKERS'] = '4'
        
        config = described_class.load
        expect(config['environment']['is_parallel']).to be true
        
      ensure
        ENV['PARALLEL_WORKERS'] = old_parallel
      end

      it 'processes suppression environment variables' do
        old_no_suppress = ENV['PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS']
        old_suppress_level = ENV['PARALLEL_MATRIX_FORMATTER_SUPPRESS']
        
        ENV['PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS'] = 'true'
        ENV['PARALLEL_MATRIX_FORMATTER_SUPPRESS'] = 'runner'
        
        config = described_class.load
        expect(config['environment']['no_suppress']).to be true
        expect(config['environment']['suppress_level']).to eq('runner')
        
      ensure
        ENV['PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS'] = old_no_suppress
        ENV['PARALLEL_MATRIX_FORMATTER_SUPPRESS'] = old_suppress_level
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
