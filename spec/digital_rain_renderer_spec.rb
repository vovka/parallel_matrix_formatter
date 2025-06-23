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
      },
      'fade_effect' => {
        'enabled' => false,
        'column_height' => 5,
        'fade_levels' => 5,
        'bright_color' => 'bright_green',
        'dim_color' => 'green'
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

    it 'renders 100% in red for first completion' do
      result = renderer.render_process_column(1, 100, 15, true)

      expect(result).to be_a(String)
      stripped_result = result.gsub(/\e\[[\d;]*m/, '') # Remove ANSI codes
      expect(stripped_result).to include('100%')
      # Should contain red color codes for first completion
      expect(result).to match(/\e\[31m/) # Red ANSI code
    end

    it 'renders 100% in green for subsequent completions' do
      result = renderer.render_process_column(1, 100, 15, false)

      expect(result).to be_a(String)
      stripped_result = result.gsub(/\e\[[\d;]*m/, '') # Remove ANSI codes
      expect(stripped_result).to include('100%')
      # Should contain green color codes for subsequent completions
      expect(result).to match(/\e\[32m/) # Green ANSI code
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

  describe 'color support detection' do
    it 'detects GitHub Actions CI environment' do
      # Create config with colors enabled
      ci_config = config.merge('colors' => config['colors'].merge('method' => 'auto'))
      
      # Mock GitHub Actions environment
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GITHUB_ACTIONS').and_return('true')
      allow(ENV).to receive(:[]).with('NO_COLOR').and_return(nil)
      allow(ENV).to receive(:[]).with('FORCE_COLOR').and_return(nil)
      
      renderer = described_class.new(ci_config)
      result = renderer.render_process_column(1, 50, 15)
      
      # Should produce colored output in GitHub Actions
      expect(result).to match(/\e\[[\d;]*m/) # Contains ANSI codes
    end

    it 'respects NO_COLOR environment variable' do
      # Create config with colors enabled  
      no_color_config = config.merge('colors' => config['colors'].merge('method' => 'auto'))
      
      # Mock NO_COLOR environment
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('NO_COLOR').and_return('1')
      allow(ENV).to receive(:[]).with('FORCE_COLOR').and_return(nil)
      allow(ENV).to receive(:[]).with('GITHUB_ACTIONS').and_return(nil)
      
      renderer = described_class.new(no_color_config)
      result = renderer.render_process_column(1, 50, 15)
      
      # Should not produce colored output when NO_COLOR is set
      expect(result).not_to match(/\e\[[\d;]*m/) # No ANSI codes
    end

    it 'forces colors with FORCE_COLOR environment variable' do
      # Create config with colors enabled
      force_color_config = config.merge('colors' => config['colors'].merge('method' => 'auto'))
      
      # Mock FORCE_COLOR environment and non-TTY stdout
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FORCE_COLOR').and_return('1')
      allow(ENV).to receive(:[]).with('NO_COLOR').and_return(nil)
      allow(ENV).to receive(:[]).with('GITHUB_ACTIONS').and_return(nil)
      allow($stdout).to receive(:tty?).and_return(false)
      
      renderer = described_class.new(force_color_config)
      result = renderer.render_process_column(1, 50, 15)
      
      # Should produce colored output even when stdout is not a TTY
      expect(result).to match(/\e\[[\d;]*m/) # Contains ANSI codes
    end
  end

  describe 'ANSI color fallback' do
    it 'uses direct ANSI codes when configured' do
      # Create config with ANSI method specifically
      ansi_config = config.merge('colors' => config['colors'].merge('method' => 'ansi'))
      
      # Mock environment to enable colors
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('NO_COLOR').and_return(nil)
      allow(ENV).to receive(:[]).with('FORCE_COLOR').and_return('1')
      
      ansi_renderer = described_class.new(ansi_config)
      result = ansi_renderer.render_process_column(1, 100, 15, true)
      
      # Should contain red ANSI code for 100% first completion
      expect(result).to match(/\e\[31m/) # Red ANSI code
      # Should contain green ANSI code for rain
      expect(result).to match(/\e\[32m/) # Green ANSI code  
      # Should contain reset code
      expect(result).to match(/\e\[0m/) # Reset code
    end
  end
end
