# frozen_string_literal: true

require 'timeout'

RSpec.describe ParallelMatrixFormatter::Orchestrator do
  subject(:orchestrator) { described_class.new(2, output, display) }

  let(:dir) { Dir.mktmpdir }
  let(:output) { StringIO.new }
  let(:display) do
    instance_double(ParallelMatrixFormatter::Rendering::Display, example: '*', summary: "SUMMARY\n")
  end

  before do
    allow(ParallelMatrixFormatter::Ipc).to receive(:socket_path).and_return(File.join(dir, 'test.sock'))
  end

  after { FileUtils.remove_entry(dir) }

  # Connects like a test process does, sends the messages and disconnects.
  def send_messages(*messages)
    client = ParallelMatrixFormatter::Ipc::Client.connect(timeout: 1)
    messages.each { |message| client.notify(message) }
    client.close
  end

  def example(process, status = 'passed', progress = 0.5)
    { type: 'example', process: process, status: status, progress: progress }
  end

  def summary(process)
    { type: 'summary', process: process, examples: 1, failures: 0, pending: 0, duration: 0.1, failed_examples: [] }
  end

  def close_orchestrator(target = orchestrator)
    Timeout.timeout(5) { target.close }
  end

  describe '.for' do
    let(:config) { {} }

    it 'returns a NullOrchestrator for every process but the first' do
      expect(described_class.for(2, 2, output, config)).to be_a(ParallelMatrixFormatter::NullOrchestrator)
    end

    context 'when the process is the first' do
      subject(:created) { described_class.for(1, 1, output, config) }

      before { allow(ParallelMatrixFormatter::Rendering::Display).to receive(:new).and_return(display) }

      after do
        send_messages(summary(1))
        close_orchestrator(created)
      end

      it 'returns an Orchestrator' do
        expect(created).to be_a(described_class)
      end

      it 'builds its display from the configuration and the number of processes' do
        created
        expect(ParallelMatrixFormatter::Rendering::Display).to have_received(:new).with(config, 1)
      end
    end
  end

  describe '#close' do
    context 'when every process has sent a summary' do
      before do
        orchestrator
        send_messages(example(1, 'failed'), summary(1))
        send_messages(summary(2))
        close_orchestrator
      end

      it 'prints the symbol of every example, then the summary' do
        expect(output.string).to eq("*SUMMARY\n")
      end

      it 'passes the example message to the display' do
        expect(display).to have_received(:example).with(1, 'failed', 0.5)
      end

      it 'has no missing processes' do
        expect(display).to have_received(:summary).with(array_including(hash_including('process' => 2)), [])
      end

      it 'removes the socket' do
        expect(File.exist?(ParallelMatrixFormatter::Ipc.socket_path)).to be(false)
      end
    end

    context 'when a process disconnects without a summary' do
      before do
        orchestrator
        send_messages(summary(1))
        send_messages(example(2))
        close_orchestrator
      end

      it 'prints the summary of the others' do
        expect(display).to have_received(:summary).with([hash_including('process' => 1)], [2])
      end
    end

    context 'when a process is still running' do
      after do
        send_messages(summary(2))
        close_orchestrator
      end

      it 'keeps waiting for it' do
        orchestrator
        send_messages(summary(1))
        expect { Timeout.timeout(0.5) { orchestrator.close } }.to raise_error(Timeout::Error)
      end
    end
  end
end
