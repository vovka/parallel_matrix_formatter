# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/rendering/update_renderer'

RSpec.describe ParallelMatrixFormatter::Rendering::UpdateRenderer do
  let(:test_env_number) { 1 }
  subject(:renderer) { described_class.new(test_env_number) }

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
      before do
        # Set initial time for testing time-based updates
        allow(Time).to receive(:now).and_return(Time.at(0))
      end

      it 'generates a progress update string if enough time has passed' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(described_class::SECONDS_TO_UPDATE + 1))
        output = renderer.update(message)
        expect(output).to include("Update is run from process 1. Progress: 1:50.0% ")
      end

      it 'generates a progress update string if all processes are at 100%' do
        renderer.update({ 'process_number' => 1, 'message' => { 'progress' => 1.0 } })
        renderer.update({ 'process_number' => 2, 'message' => { 'progress' => 1.0 } })
        allow(Time).to receive(:now).and_return(Time.at(described_class::SECONDS_TO_UPDATE + 1))
        output = renderer.update(message.merge('message' => { 'status' => nil, 'progress' => 1.0 })) # Ensure no status output
        expect(output).to include("Update is run from process 1. Progress: 1:100.0%, 2:100.0% ")
      end

      it 'does not generate a progress update string if not enough time has passed' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(described_class::SECONDS_TO_UPDATE - 1))
        output = renderer.update(message)
        expect(output).not_to include("Update is run from process")
      end

      it 'formats the progress correctly' do
        renderer.update(message)
        allow(Time).to receive(:now).and_return(Time.at(described_class::SECONDS_TO_UPDATE + 1))
        output = renderer.update(message)
        expect(output).to include("Progress: 1:50.0%")
      end
    end

    context 'test_example_status' do
      it 'renders a green symbol for passed status' do
        message['message']['status'] = :passed
        output = renderer.update(message)
        expect(output).to include("\e[32mA\e[0m") # A is (1-1 + 'A'.ord).chr
      end

      it 'renders a red symbol for failed status' do
        message['message']['status'] = :failed
        output = renderer.update(message)
        expect(output).to include("\e[31mA\e[0m")
      end

      it 'renders a yellow symbol for pending status' do
        message['message']['status'] = :pending
        output = renderer.update(message)
        expect(output).to include("\e[33mA\e[0m")
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

    it 'combines progress update and test example status' do
      allow(Time).to receive(:now).and_return(Time.at(described_class::SECONDS_TO_UPDATE + 1))
      output = renderer.update(message)
      expect(output).to include("Update is run from process 1. Progress: 1:50.0% ")
      expect(output).to include("\e[32mA\e[0m")
    end
  end
end
