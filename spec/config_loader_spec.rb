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
  end
end
