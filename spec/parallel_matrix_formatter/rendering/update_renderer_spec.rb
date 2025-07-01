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

    context 'progress_update' do
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

    context 'test_example_status' do
      it 'renders a green symbol for passed status' do
        message['message']['status'] = :passed
        output = renderer.update(message)
        expect(output).to include("\e[32m✅A\e[0m") # A is (1-1 + 'A'.ord).chr
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

    it 'includes progress update in the combined output' do
      allow(Time).to receive(:now).and_return(Time.at((config['update_interval_seconds'] || 3) + 1))
      output = renderer.update(message)
      expect(output).to include("\nUpdate is run from process 1. Progress: \e[31m=\e[31m50%\e[0m==\e[0m ")
    end

    it 'includes test example status in the combined output' do
      allow(Time).to receive(:now).and_return(Time.at((config['update_interval_seconds'] || 3) + 1))
      output = renderer.update(message)
      expect(output).to include("\e[32m✅A\e[0m")
    end
  end

  context 'with custom configuration' do
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

    before do
      # Re-initialize renderer to pick up new config
      @renderer = described_class.new(test_env_number, config)
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
      @renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(4)) # Less than 5 seconds
      output = @renderer.update(message)
      expect(output).not_to include("Process 1 - 1:50.0%")
    end

    it 'uses the custom update interval to update if enough time has passed' do
      @renderer.update(message)
      allow(Time).to receive(:now).and_return(Time.at(6)) # More than 5 seconds
      output = @renderer.update(message)
      expect(output).to include("Process 1 - =\e[31m50%\e[0m==")
    end

    it 'uses the custom progress line format' do
      @renderer.update(message) # Populate @progress
      allow(Time).to receive(:now).and_return(Time.at(6))
      output = @renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 0.5 })) # Ensure no status output
      expect(output).to match(/\[\d{2}:\d{2}:\d{2}\] Process 1 - =\e\[31m50%\e\[0m==/)
    end

    it 'uses the custom test status line format' do
      message['message']['status'] = :passed
      output = @renderer.update(message)
      expect(output).to include("\e[32m✔ A \e[0m")
    end

    it 'uses the custom status symbols for failed status' do
      message['message']['status'] = :failed
      output = @renderer.update(message)
      expect(output).to include("\e[31m✖ A \e[0m")
    end

    it 'uses the custom status symbols for pending status' do
      message['message']['status'] = :pending
      output = @renderer.update(message)
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
end
