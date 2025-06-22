# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter'

RSpec.describe ParallelMatrixFormatter::DigitalRainRenderer do
  let(:config) do
    {
      'digits' => {
        'use_custom' => true,
        'symbols' => '０１２３４５６７８９',
        'symbols_chars' => '０１２３４５６７８９'.chars
      },
      'katakana_alphabet_chars' => 'アイウエオカキクケコサシスセソ'.chars,
      'pass_symbols_chars' => 'アイウエオ'.chars,
      'fail_symbols_chars' => 'カキクケコ'.chars,
      'pending_symbol' => '🥄',
      'colors' => {
        'time' => 'green',
        'percent' => 'red',
        'rain' => 'green',
        'pass_dot' => 'green',
        'fail_dot' => 'red',
        'pending_dot' => 'white'
      },
      'display' => {
        'column_width' => 15,
        'show_time_digits' => true,
        'rain_density' => 0.7
      }
    }
  end

  let(:renderer) { described_class.new(config) }

  describe '#render_time_column' do
    it 'renders time with custom digits' do
      result = renderer.render_time_column

      expect(result).to be_a(String)
      expect(result).to include(':') # Should contain time format separators
    end
  end

  describe '#render_process_column' do
    it 'renders process column with progress' do
      result = renderer.render_process_column(1, 50, 15)

      expect(result).to be_a(String)
      expect(result.length).to be >= 10 # Should have some content
      # Check if the result contains percentage digits (without ANSI codes)
      stripped_result = result.gsub(/\e\[[\d;]*m/, '') # Remove ANSI codes
      expect(stripped_result).to include('50%')
    end
  end

  describe '#render_test_dots' do
    it 'renders test results as dots' do
      test_results = [
        { status: :passed },
        { status: :failed },
        { status: :pending }
      ]

      result = renderer.render_test_dots(test_results)

      expect(result).to be_a(String)
      # Check for ANSI color codes presence (indicating colored output)
      expect(result).to match(/\e\[[\d;]*m/)
      # The actual character count should be 3 (one per test) plus ANSI codes
      stripped_result = result.gsub(/\e\[[\d;]*m/, '') # Remove ANSI codes
      expect(stripped_result.length).to eq(3)
    end
  end

  describe '#render_final_summary' do
    it 'renders final summary with all statistics' do
      result = renderer.render_final_summary(100, 5, 2, 45.5, [20.1, 25.4], 2)

      expect(result).to include('100 examples')
      expect(result).to include('5 failures')
      expect(result).to include('2 pending')
      expect(result).to include('Processes: 2')
    end
  end
end
