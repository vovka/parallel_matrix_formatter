# frozen_string_literal: true

require 'tempfile'
require 'timeout'

RSpec.describe ParallelMatrixFormatter::Orchestrator do
  subject(:orchestrator) { described_class.new(runner, output, display) }

  let(:dir) { Dir.mktmpdir }
  let(:runner) { ParallelMatrixFormatter::Runner.new(process_count: 2, run_id: 'test') }
  let(:output) { StringIO.new }
  let(:display) do
    instance_double(ParallelMatrixFormatter::Rendering::Display, example: '*', summary: "SUMMARY\n")
  end

  let(:socket_path) { File.join(dir, 'test.sock') }

  before { allow(ParallelMatrixFormatter::Ipc).to receive(:socket_path).and_return(socket_path) }

  after { FileUtils.remove_entry(dir) }

  # Connects like a test process does, sends the messages and disconnects.
  def send_messages(*messages)
    client = ParallelMatrixFormatter::Ipc::Client.connect(socket_path, timeout: 1)
    messages.each { |message| client.notify(message) }
    client.close
  end

  def example(process, status = 'passed', progress = 0.5)
    { type: 'example', process: process, status: status, progress: progress }
  end

  def summary(process, **pids)
    { type: 'summary', process: process, examples: 1, failures: 0, pending: 0, duration: 0.1, failed_examples: [] }
      .merge(pids)
  end

  def close_orchestrator(target = orchestrator)
    Timeout.timeout(5) { target.close }
  end

  describe '.for' do
    let(:config) { {} }

    it 'returns a NullOrchestrator for every process but the first' do
      expect(described_class.for(2, runner, output, config)).to be_a(ParallelMatrixFormatter::NullOrchestrator)
    end

    context 'when the process is the first' do
      subject(:created) { described_class.for(1, runner, output, config) }

      let(:runner) { ParallelMatrixFormatter::Runner.new(process_count: 1, run_id: 'test') }

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
        expect(File.exist?(socket_path)).to be(false)
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

    context 'when a process numbered above the process count connects' do
      before do
        orchestrator
        send_messages(example(3))
        send_messages(summary(1), summary(2))
        close_orchestrator
      end

      it 'waits for it and reports it as missing' do
        expect(display).to have_received(:summary).with(anything, [3])
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

  describe '#close with a pid file' do
    let(:pid_file) { Tempfile.new('pidfile') }
    let(:runner) { ParallelMatrixFormatter::Runner.new(process_count: 4, run_id: 'test', pid_file: pid_file.path) }
    let(:live_pids) { '[101,102]' }

    before { write_pid_file(live_pids) }

    after { pid_file.close! }

    def write_pid_file(contents)
      File.write(pid_file.path, contents)
    end

    context 'when fewer processes exist than the runner counted' do
      before do
        orchestrator
        send_messages(summary(1, pid: 101), summary(2, pid: 102))
        close_orchestrator
      end

      it 'does not wait for the processes that never started' do
        expect(display).to have_received(:summary).with(array_including(hash_including('process' => 2)), [])
      end
    end

    context 'when a live process has not been heard from' do
      let(:live_pids) { '[101,999]' }

      before do
        orchestrator
        send_messages(summary(1, pid: 101))
      end

      after do
        write_pid_file('[101]')
        close_orchestrator
      end

      it 'keeps waiting for it' do
        expect { Timeout.timeout(0.5) { orchestrator.close } }.to raise_error(Timeout::Error)
      end
    end

    context 'when the pid file cannot be read' do
      let(:live_pids) { '' }

      before do
        orchestrator
        send_messages(summary(1, pid: 101))
      end

      after do
        write_pid_file('[101]')
        close_orchestrator
      end

      it 'keeps waiting' do
        expect { Timeout.timeout(0.5) { orchestrator.close } }.to raise_error(Timeout::Error)
      end
    end

    context 'when the live process is the parent of a reporting process' do
      let(:live_pids) { '[500]' }

      before do
        orchestrator
        send_messages(summary(1, pid: 101, ppid: 500))
        close_orchestrator
      end

      it 'counts it as heard from' do
        expect(display).to have_received(:summary).with([hash_including('process' => 1)], [])
      end
    end
  end
end
