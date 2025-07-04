# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/formatter'

RSpec.describe ParallelMatrixFormatter::Formatter do
  let(:output) { StringIO.new }
  let(:config) { ParallelMatrixFormatter::Config.new }
  subject(:formatter) { described_class.new(output, ENV['TEST_ENV_NUMBER'], config) }
  let(:ipc_client) { instance_double(ParallelMatrixFormatter::Ipc::Client, notify: nil, close: nil) }
  let(:orchestrator) { instance_double(ParallelMatrixFormatter::Orchestrator, start: nil, puts: nil, close: nil) }
  let(:update_renderer) { instance_double(ParallelMatrixFormatter::Rendering::UpdateRenderer) }
  let(:output_suppressor) { instance_double(ParallelMatrixFormatter::Output::Suppressor, notify: nil, suppress: nil) }
  let(:start_notification) { double('start_notification', count: 10) }

  before do
    stub_const('ParallelSplitTest', double(processes: 4))
    allow(ParallelMatrixFormatter::Rendering::UpdateRenderer).to receive(:new).with(any_args).and_return(update_renderer)
    allow(ParallelMatrixFormatter::Orchestrator).to receive(:build).and_return(orchestrator)
    allow(ParallelMatrixFormatter::Ipc::Client).to receive(:new).and_return(ipc_client)
    allow(ParallelMatrixFormatter::Output::Suppressor).to receive(:new).and_return(output_suppressor)
    ENV['TEST_ENV_NUMBER'] = '2'
  end

  describe '#initialize' do
    it 'initializes with the correct test environment number' do
      formatter
      expect(ParallelMatrixFormatter::Rendering::UpdateRenderer).to have_received(:new).with(2, config.update_renderer)
    end

    it 'builds the orchestrator with the correct arguments' do
      formatter
      expect(ParallelMatrixFormatter::Orchestrator).to have_received(:build).with(4, 2, output, update_renderer)
    end

    it 'suppresses output immediately to prevent race conditions' do
      formatter
      expect(output_suppressor).to have_received(:suppress)
    end

    it 'does not create IPC client during initialization' do
      formatter
      expect(ParallelMatrixFormatter::Ipc::Client).not_to have_received(:new)
    end
  end

  describe '#start' do
    before { formatter.start(start_notification) }

    it 'starts the orchestrator' do
      expect(orchestrator).to have_received(:start)
    end

    it 'sets the total examples count' do
      expect(formatter.instance_variable_get(:@total_examples)).to eq(10)
    end

    it 'creates IPC client after orchestrator is started' do
      expect(ParallelMatrixFormatter::Ipc::Client).to have_received(:new).with(retries: 30, delay: 0.1)
    end
  end

  describe 'example notifications' do
    before do
      formatter.start(start_notification)
      formatter.example_started(double)
    end

    context 'when an example passes' do
      it 'sends a passed notification via IPC' do
        formatter.example_passed(double)
        expect(ipc_client).to have_received(:notify).with(2, { status: :passed, progress: 0.1 })
      end
    end

    context 'when an example fails' do
      it 'sends a failed notification via IPC' do
        formatter.example_failed(double)
        expect(ipc_client).to have_received(:notify).with(2, { status: :failed, progress: 0.1 })
      end
    end

    context 'when an example is pending' do
      it 'sends a pending notification via IPC' do
        formatter.example_pending(double)
        expect(ipc_client).to have_received(:notify).with(2, { status: :pending, progress: 0.1 })
      end
    end
  end

  describe 'dump methods' do
    it '#dump_summary sends message to orchestrator' do
      formatter.dump_summary(double)
      expect(orchestrator).to have_received(:puts).with("\ndump_summary")
    end

    it '#dump_failures sends message to orchestrator' do
      formatter.dump_failures(double)
      expect(orchestrator).to have_received(:puts).with("\ndump_failures")
    end

    it '#dump_pending sends message to orchestrator' do
      formatter.dump_pending(double)
      expect(orchestrator).to have_received(:puts).with("\ndump_pending")
    end

    it '#dump_profile sends message to orchestrator' do
      formatter.dump_profile(double)
      expect(orchestrator).to have_received(:puts).with("\ndump_profile")
    end
  end

  describe '#close' do
    it 'closes the orchestrator' do
      formatter.close(double)
      expect(orchestrator).to have_received(:close)
    end
  end
end
