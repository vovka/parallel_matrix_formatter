# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter/ansi_colorizer'

RSpec.describe ParallelMatrixFormatter::AnsiColorizer do
  describe '.colorize' do
    it 'applies red color to text' do
      result = described_class.colorize('test', 'red')
      expect(result).to eq("\e[31mtest\e[0m")
    end

    it 'applies green color to text' do
      result = described_class.colorize('test', 'green')
      expect(result).to eq("\e[32mtest\e[0m")
    end

    it 'applies bright green color to text' do
      result = described_class.colorize('test', 'bright_green')
      expect(result).to eq("\e[1;32mtest\e[0m")
    end

    it 'returns text unchanged for unsupported color' do
      result = described_class.colorize('test', 'purple')
      expect(result).to eq('test')
    end

    it 'returns text unchanged for nil color' do
      result = described_class.colorize('test', nil)
      expect(result).to eq('test')
    end

    it 'returns text unchanged for empty color' do
      result = described_class.colorize('test', '')
      expect(result).to eq('test')
    end
  end

  describe '.supported_color?' do
    it 'returns true for supported colors' do
      expect(described_class.supported_color?('red')).to be true
      expect(described_class.supported_color?('green')).to be true
      expect(described_class.supported_color?('bright_green')).to be true
    end

    it 'returns false for unsupported colors' do
      expect(described_class.supported_color?('purple')).to be false
      expect(described_class.supported_color?('orange')).to be false
    end
  end

  describe '.supported_colors' do
    it 'returns array of supported color names' do
      colors = described_class.supported_colors
      expect(colors).to include('red', 'green', 'blue', 'yellow', 'cyan', 'magenta', 'white', 'black', 'bright_green')
      expect(colors).to be_an(Array)
    end
  end
end