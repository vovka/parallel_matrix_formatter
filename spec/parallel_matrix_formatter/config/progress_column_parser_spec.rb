# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/config/progress_column_parser'

RSpec.describe ParallelMatrixFormatter::Config::ProgressColumnParser do
  let(:parser) { described_class }

  describe '.parse_progress_column_percentage' do
    it 'parses format with alignment and width' do
      percentage = { 'format' => '{v}%:^10', 'color' => 'green' }
      result = parser.parse_progress_column_percentage(percentage)
      expect(result).to eq({ value: '{v}%', align: '^', width: 10, color: 'green' })
    end

    it 'parses format with only width' do
      percentage = { 'format' => '{v}%:10', 'color' => 'blue' }
      result = parser.parse_progress_column_percentage(percentage)
      expect(result).to eq({ value: '{v}%', align: '^', width: 10, color: 'blue' })
    end

    it 'defaults color to red if not provided' do
      percentage = { 'format' => '{v}%:^8' }
      result = parser.parse_progress_column_percentage(percentage)
      expect(result).to eq({ value: '{v}%', align: '^', width: 8, color: 'red' })
    end
  end

  describe '.pad_symbol' do
    it 'returns the pad symbol if present' do
      config = { 'progress_column' => { 'pad' => { 'symbol' => '*' } } }
      expect(parser.pad_symbol(config)).to eq('*')
    end

    it 'returns default symbol if not present' do
      config = { 'progress_column' => { 'pad' => {} } }
      expect(parser.pad_symbol(config)).to eq('=')
    end
  end

  describe '.pad_color' do
    it 'returns the pad color if present' do
      config = { 'progress_column' => { 'pad' => { 'color' => 'yellow' } } }
      expect(parser.pad_color(config)).to eq('yellow')
    end

    it 'returns nil if color is not present' do
      config = { 'progress_column' => { 'pad' => {} } }
      expect(parser.pad_color(config)).to be_nil
    end
  end

  describe '.parse' do
    it 'parses and adds parsed progress column percentage and pad info' do
      raw = {
        'progress_column' => {
          'percentage' => { 'format' => '{v}%:-12', 'color' => 'cyan' },
          'pad' => { 'symbol' => '#', 'color' => 'magenta' }
        }
      }
      result = parser.parse(raw.dup)
      expect(result['progress_column']['parsed']).to eq({ value: '{v}%', align: '-', width: 12, color: 'cyan' })
      expect(result['progress_column']['pad_symbol']).to eq('#')
      expect(result['progress_column']['pad_color']).to eq('magenta')
    end
  end
end
