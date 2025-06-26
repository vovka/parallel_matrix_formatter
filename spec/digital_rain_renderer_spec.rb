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
      'display' => {
        'column_width' => 15,
        'show_time_digits' => true,
        'rain_density' => 0.7
      },
      'fade_effect' => {
        'enabled' => true,
        'column_height' => 5,
        'fade_levels' => 3
      }
    }
  end

  let(:renderer) { described_class.new(config) }

  describe '#render_time_column' do
    it 'renders current time with custom digits when enabled' do
      result = renderer.render_time_column
      
      # Should contain custom digits (０-９) and colons
      expect(result).to match(/[０-９:]+/)
      # Should not contain regular digits when custom is enabled
      expect(result).not_to match(/[0-9]/)
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'renders standard time when custom digits disabled' do
      config_no_custom = config.merge('digits' => { 'use_custom' => false, 'symbols_chars' => '0123456789'.chars })
      renderer_no_custom = described_class.new(config_no_custom)
      
      result = renderer_no_custom.render_time_column
      
      # Should contain regular digits and colons
      expect(result).to match(/[0-9:]+/)
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
    end
  end

  describe '#render_process_column' do
    it 'renders progress percentage with ASCII characters only' do
      result = renderer.render_process_column(1, 50, 15)
      
      # Should contain percentage
      expect(result).to include('50%')
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
      # Should be exactly the expected width
      expect(result.length).to eq(15)
    end

    it 'renders 100% completion correctly' do
      result = renderer.render_process_column(1, 100, 15, true)
      
      # Should contain percentage
      expect(result).to include('100%')
      # Should be ASCII only
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'handles fade effect when enabled' do
      fade_config = config.merge('fade_effect' => { 'enabled' => true, 'column_height' => 5, 'fade_levels' => 3 })
      fade_renderer = described_class.new(fade_config)
      
      result = fade_renderer.render_process_column(1, 75, 15)
      
      # Should contain percentage
      expect(result).to include('75%')
      # Should be ASCII only
      expect(result).not_to match(/\e\[[\d;]*m/)
      expect(result.length).to eq(15)
    end
  end

  describe '#render_test_dots' do
    let(:test_results) do
      [
        { status: 'passed' },
        { status: 'failed' },
        { status: 'pending' }
      ]
    end

    it 'renders test results as ASCII characters without colors' do
      result = renderer.render_test_dots(test_results)
      
      # Should contain characters from the configured symbol sets
      expect(result.length).to eq(3)
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'handles symbol status values' do
      symbol_results = [
        { status: :passed },
        { status: :failed },
        { status: :pending }
      ]
      
      result = renderer.render_test_dots(symbol_results)
      
      expect(result.length).to eq(3)
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'handles unknown status' do
      unknown_results = [{ status: 'unknown' }]
      
      result = renderer.render_test_dots(unknown_results)
      
      expect(result).to eq(' ')
      expect(result).not_to match(/\e\[[\d;]*m/)
    end
  end

  describe '#render_matrix_line' do
    it 'combines components correctly' do
      time_column = '12:34:56'
      process_columns = ['Process1Col', 'Process2Col']
      test_dots = '...'
      
      result = renderer.render_matrix_line(time_column, process_columns, test_dots)
      
      expect(result).to eq('12:34:56 Process1Col Process2Col ...')
      expect(result).not_to match(/\e\[[\d;]*m/)
    end
  end

  describe '#render_failure_summary' do
    let(:failures) do
      [
        {
          description: 'example should work',
          location: 'spec/example_spec.rb:10',
          message: 'Expected true to be false'
        }
      ]
    end

    it 'renders failure summary without colors' do
      result = renderer.render_failure_summary(failures)
      
      expect(result).to include('FAILED EXAMPLES')
      expect(result).to include('1. example should work')
      expect(result).to include('Location: spec/example_spec.rb:10')
      expect(result).to include('Expected true to be false')
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'returns empty string for no failures' do
      result = renderer.render_failure_summary([])
      
      expect(result).to eq('')
    end

    it 'handles multiline error messages' do
      failures_multiline = [
        {
          description: 'multiline error',
          location: 'spec/test.rb:5',
          message: "Line 1\nLine 2\nLine 3"
        }
      ]
      
      result = renderer.render_failure_summary(failures_multiline)
      
      expect(result).to include('   Line 1')
      expect(result).to include('   Line 2')
      expect(result).to include('   Line 3')
      expect(result).not_to match(/\e\[[\d;]*m/)
    end
  end

  describe '#render_final_summary' do
    it 'renders summary without colors' do
      result = renderer.render_final_summary(100, 5, 2, 45.5, [20.1, 25.4], 2)

      expect(result).to include('100 examples')
      expect(result).to include('5 failures')
      expect(result).to include('2 pending')
      expect(result).to include('Processes: 2')
      # Should not contain any ANSI color codes
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'handles zero failures and pending' do
      result = renderer.render_final_summary(50, 0, 0, 10.0, [10.0], 1)

      expect(result).to include('50 examples')
      expect(result).not_to include('failures')
      expect(result).not_to include('pending')
      expect(result).not_to match(/\e\[[\d;]*m/)
    end

    it 'formats durations correctly' do
      result = renderer.render_final_summary(10, 0, 0, 0.5, [0.5], 1)

      expect(result).to include('500.0 ms')
      expect(result).not_to match(/\e\[[\d;]*m/)
    end
  end

  describe 'ASCII-only output verification' do
    it 'ensures all methods output ASCII characters without ANSI codes' do
      # Test all public methods to ensure no ANSI codes are output
      time_result = renderer.render_time_column
      process_result = renderer.render_process_column(1, 75, 15)
      test_result = renderer.render_test_dots([{ status: 'passed' }])
      failure_result = renderer.render_failure_summary([{ description: 'test', location: 'file:1', message: 'error' }])
      summary_result = renderer.render_final_summary(10, 1, 0, 1.5, [1.5], 1)
      matrix_result = renderer.render_matrix_line('12:34:56', ['col1'], '.')

      [time_result, process_result, test_result, failure_result, summary_result, matrix_result].each do |result|
        # Verify no ANSI escape sequences are present
        expect(result).not_to match(/\e\[[\d;]*m/), "Found ANSI codes in: #{result.inspect}"
      end
    end
  end
end