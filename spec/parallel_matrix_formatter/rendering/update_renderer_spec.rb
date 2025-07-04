# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/rendering/update_renderer'

RSpec.describe ParallelMatrixFormatter::Rendering::UpdateRenderer do
  let(:test_env_number) { 1 }
  let(:config) do
    {
      'update_interval_seconds' => 3,
      'progress_line_format' => "\nUpdate is run from process {process_number}. Progress: {progress_info} ",
      'test_status_line_format' => "{status_symbol}{process_symbol}",
      'status_symbols' => {
        'passed' => "✅",
        'failed' => "❌",
        'pending' => "⏳"
      },
      'progress_column' => {
        'parsed' => { 'align' => '^', 'width' => 6, 'value' => '{v}%', 'color' => 'red' }
      },
      'colors' => {
        'progress_info' => 'red',
        'pass_dot' => 'green',
        'fail_dot' => 'red',
        'pending_dot' => 'yellow'
      },
      'digits' => {
        'use_custom' => false,
        'symbols' => "0123456789"
      }
    }
  end
  subject(:renderer) { described_class.new(test_env_number, config) }

  describe '#initialize' do
    it 'sets the test_env_number' do
      expect(renderer.instance_variable_get(:@test_env_number)).to eq(test_env_number)
    end

    it 'initializes progress as an empty hash' do
      expect(renderer.instance_variable_get(:@progress)).to eq({})
    end
  end

  describe '#update' do
    let(:message) do
      {
        'process_number' => 1,
        'message' => {
          'status' => :passed,
          'progress' => 0.5
        }
      }
    end

    it 'updates the progress for the given process number' do
      renderer.update(message)
      expect(renderer.instance_variable_get(:@progress)).to eq({ 1 => 0.5 })
    end

    context 'when updating progress' do
      let(:update_interval) { config['update_interval_seconds'] || 3 }

      before do
        # Set initial time for testing time-based updates
        allow(Time).to receive(:now).and_return(Time.at(0))
      end

      it 'generates a progress update string if enough time has passed' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(update_interval + 1))
        output = renderer.update(message)
        expect(output).to include("\nUpdate is run from process 1. Progress: \e[31m=\e[31m50%\e[0m==\e[0m ")
      end

      it 'generates a progress update string if all processes are at 100%' do
        renderer.update({ 'process_number' => 1, 'message' => { 'progress' => 1.0 } })
        renderer.update({ 'process_number' => 2, 'message' => { 'progress' => 1.0 } })
        allow(Time).to receive(:now).and_return(Time.at(update_interval + 1))
        output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 1.0 })) # Ensure no status output
        expect(output).to include("\nUpdate is run from process 1. Progress: \e[31m=\e[31m100%\e[0m=\e[0m\e[31m=\e[31m100%\e[0m=\e[0m ")
      end

      it 'does not generate a progress update string if not enough time has passed' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(update_interval - 1))
        output = renderer.update(message)
        expect(output).not_to include("Update is run from process")
      end

      it 'formats the progress correctly' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(update_interval + 1))
        output = renderer.update(message)
        expect(output).to include("Progress: \e[31m=\e[31m50%\e[0m==\e[0m")
      end
    end

    context 'when rendering test example status' do
      it 'renders a green symbol for passed status' do
        message['message']['status'] = :passed
        output = renderer.update(message)
        expect(output).to include("\e[32m✅A\e[0m")
      end

      it 'renders a red symbol for failed status' do
        message['message']['status'] = :failed
        output = renderer.update(message)
        expect(output).to include("\e[31m❌A\e[0m")
      end

      it 'renders a yellow symbol for pending status' do
        message['message']['status'] = :pending
        output = renderer.update(message)
        expect(output).to include("\e[33m⏳A\e[0m")
      end

      it 'renders empty string if status is missing' do
        message['message'].delete('status')
        output = renderer.update(message)
        expect(output).to include("")
      end

      it 'returns an empty string if message is missing' do
        output = renderer.update(nil)
        expect(output).to eq("")
      end
    end

    context 'when generating combined output' do
      it 'includes progress update' do
        allow(Time).to receive(:now).and_return(Time.at((config['update_interval_seconds'] || 3) + 1))
        output = renderer.update(message)
        expect(output).to include("\nUpdate is run from process 1. Progress: \e[31m=\e[31m50%\e[0m==\e[0m ")
      end

      it 'includes test example status' do
        allow(Time).to receive(:now).and_return(Time.at((config['update_interval_seconds'] || 3) + 1))
        output = renderer.update(message)
        expect(output).to include("\e[32m✅A\e[0m")
      end
    end
  end

  context 'when configured with custom settings' do
    let(:config) do
      {
        'update_interval_seconds' => 5,
        'progress_line_format' => "[{time}] Process {process_number} - {progress_info}",
        'test_status_line_format' => "{status_symbol} {process_symbol} ",
        'status_symbols' => {
          'passed' => "✔",
          'failed' => "✖",
          'pending' => "..."
        }
      }
    end

    subject(:renderer) { described_class.new(test_env_number, config) }

    before do
      allow(Time).to receive(:now).and_return(Time.at(0))
    end

    let(:message) do
      {
        'process_number' => 1,
        'message' => {
          'status' => :passed,
          'progress' => 0.5
        }
      }
    end

    it 'uses the custom update interval to not update if not enough time has passed' do
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(4)) # Less than 5 seconds
      output = renderer.update(message)
      expect(output).not_to include("Process 1 - 1:50.0%")
    end

    it 'uses the custom update interval to update if enough time has passed' do
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(6)) # More than 5 seconds
      output = renderer.update(message)
      expect(output).to include("Process 1 - =\e[31m50%\e[0m==")
    end

    it 'uses the custom progress line format' do
      renderer.update(message) # Populate @progress
      allow(Time).to receive(:now).and_return(Time.at(6))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 })) # Ensure no status output
      expect(output).to match(/\[\d{2}:\d{2}:\d{2}\] Process 1 - =\e\[31m50%\e\[0m==/)
    end

    it 'uses the custom test status line format' do
      message['message']['status'] = :passed
      output = renderer.update(message)
      expect(output).to include("\e[32m✔ A \e[0m")
    end

    it 'uses the custom status symbols for failed status' do
      message['message']['status'] = :failed
      output = renderer.update(message)
      expect(output).to include("\e[31m✖ A \e[0m")
    end

    it 'uses the custom status symbols for pending status' do
      message['message']['status'] = :pending
      output = renderer.update(message)
      expect(output).to match(/\e\[33m. A \e\[0m/) # Expect a single character
    end

    it 'randomly selects all characters from a multi-character status symbol string' do
      custom_config = {
        'status_symbols' => {
          'passed' => "ABC"
        }
      }
      status_renderer = ParallelMatrixFormatter::Rendering::UpdateRenderer::StatusRenderer.new(custom_config)

      symbols_found = Set.new
      100.times do
        symbols_found << status_renderer.send(:get_status_symbol, :passed)
      end
      expect(symbols_found).to include("A", "B", "C")
    end

    it 'does not select unexpected characters for multi-character status symbols' do
      custom_config = {
        'status_symbols' => {
          'passed' => "ABC"
        }
      }
      status_renderer = ParallelMatrixFormatter::Rendering::UpdateRenderer::StatusRenderer.new(custom_config)

      symbols_found = Set.new
      100.times do
        symbols_found << status_renderer.send(:get_status_symbol, :passed)
      end
      expect(symbols_found.size).to be <= 3 # Ensure we don't get unexpected characters
    end
  end

  describe 'progress line formatting with katakana symbols' do
    let(:config) do
      {
        'update_interval_seconds' => 1,
        'progress_line_format' => "\n{time} {progress_info} {test_status_line}",
        'progress_column' => {
          'parsed' => { 'align' => '^', 'width' => 1000, 'value' => '{v}%', 'color' => 'red' },
          'pad_symbol' => 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝｦｧｨｩｪｫｬｭｮｯｰ｢｣､',
          'pad_color' => 'green'
        },
        'digits' => {
          'symbols' => 'ﾛｲｸﾖﾑﾗﾚﾇﾒﾜ'
        }
      }
    end

    subject(:renderer) { described_class.new(1, config) }

    before do
      allow(Time).to receive(:now).and_return(Time.at(0))
    end

    it 'formats progress with correct width of 10 characters' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 }))
      # Extract progress info from output (space after time until space before {test_status_line})
      progress_match = output.match(/\n\S+:\S+:\S+ (.+?) \{test_status_line\}/)
      expect(progress_match).not_to be_nil
      progress_info = progress_match[1]

      # Progress info should be exactly 10 characters wide (excluding ANSI codes)
      progress_without_ansi = progress_info.gsub(/\e\[[0-9;]*m/, '')
      expect(progress_without_ansi.length).to eq(1000)
    end

    it 'centers the percentage value within the 10-character column' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 }))

      # Extract progress info and remove ANSI codes
      progress_match = output.match(/\n\S+:\S+:\S+ (.+?) \{test_status_line\}/)
      progress_info = progress_match[1].gsub(/\e\[[0-9;]*m/, '')

      # Should be centered: 3 pad chars + "ﾗﾛ%" + 4 pad chars = 10 total (using custom digits)
      # For 10 width with 3-char value: left_pad = 3, right_pad = 4
      expect(progress_info).to match(/^.{498}ﾗﾛ%.{499}$/)
    end

    it 'uses katakana symbols for padding' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.12 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.12 }))

      # Extract progress info and remove ANSI codes
      progress_match = output.match(/\n\S+:\S+:\S+ (.+?) \{test_status_line\}/)
      progress_info = progress_match[1].gsub(/\e\[[0-9;]*m/, '')

      # Remove the percentage to get only padding characters (using custom digits)
      padding_chars = progress_info.gsub(/ｲｸ%/, '')
      katakana_chars = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝｦｧｨｩｪｫｬｭｮｯｰ｢｣､'.split('')

      # All padding characters should be from the katakana set
      expect(padding_chars.chars - katakana_chars).to be_empty
    end

    it 'applies green color to padding symbols' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 }))
      # Should contain green color codes for padding
      expect(output).to match(/\e\[32m[ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝｦｧｨｩｪｫｬｭｮｯｰ｢｣､]+\e\[0m/)
    end

    it 'applies red color to percentage value' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 }))
      # Should contain red color codes for percentage (using custom digits)
      expect(output).to match(/\e\[31mﾗﾛ%\e\[0m/)
    end

    it 'uses custom digits for percentage values' do
      message = { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
      renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(2))
      output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 }))
      # Should use custom digits: 5 -> ﾗ, 0 -> ﾛ, so 50% -> ﾗﾛ%
      expect(output).to include('ﾗﾛ%')
    end
  end
end
