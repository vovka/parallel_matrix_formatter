# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/orchestrator'

RSpec.describe ParallelMatrixFormatter::Orchestrator do
  let(:total_processes) { 2 }
  let(:output) { StringIO.new }
  let(:renderer) { instance_double(ParallelMatrixFormatter::Rendering::UpdateRenderer, update: 'rendered_update') }

  describe '.build' do
    context 'when test_env_number is 1' do
      it 'returns an instance of Orchestrator' do
        orchestrator = described_class.build(total_processes, 1, output, renderer)
        expect(orchestrator).to be_an_instance_of(described_class)
      end
    end

    context 'when test_env_number is not 1' do
      it 'returns an instance of BlankOrchestrator' do
        orchestrator = described_class.build(total_processes, 2, output, renderer)
        expect(orchestrator).to be_an_instance_of(described_class::BlankOrchestrator)
      end
    end
  end

  context 'with a real Orchestrator instance' do
    subject(:orchestrator) { described_class.new(total_processes, 1, output, renderer) }
    let(:ipc_server) { instance_double(ParallelMatrixFormatter::Ipc::Server, start: nil, close: nil) }

    before do
      allow(ParallelMatrixFormatter::Ipc::Server).to receive(:new).and_return(ipc_server)
    end

    describe '#initialize' do
      it 'initializes an IPC server' do
        orchestrator
        expect(ParallelMatrixFormatter::Ipc::Server).to have_received(:new)
      end
    end

    describe '#puts' do
      it 'sends the message to the output stream' do
        orchestrator.puts('hello from orchestrator')
        expect(output.string).to eq("hello from orchestrator\n")
      end
    end

    describe '#close' do
      it 'closes the IPC server' do
        orchestrator.close
        expect(ipc_server).to have_received(:close)
      end
    end

    describe '#start' do
      let(:message) { { status: :passed, progress: 0.5 } }
      let(:rendered_output) { 'matrix_display_string' }

      before do
        # Stub Thread.new to execute the block immediately and synchronously
        allow(Thread).to receive(:new) { |&block| block.call }
        # Stub the ipc_server to yield a message when start is called
        allow(ipc_server).to receive(:start).and_yield(message)
        allow(renderer).to receive(:update).with(message).and_return(rendered_output)
        # Spy on the output to verify calls
        allow(output).to receive(:print).with(rendered_output)
        allow(output).to receive(:flush)
      end

      it 'starts the IPC server' do
        orchestrator.start
        expect(ipc_server).to have_received(:start)
      end

      it 'updates the renderer with the message from the IPC server' do
        orchestrator.start
        expect(renderer).to have_received(:update).with(message)
      end

      it 'prints the rendered output' do
        orchestrator.start
        expect(output).to have_received(:print).with(rendered_output)
      end

      it 'flushes the output' do
        orchestrator.start
        expect(output).to have_received(:flush)
      end

      context 'when the renderer raises an error' do
        let(:error) { StandardError.new('Rendering failed') }

        before do
          allow(renderer).to receive(:update).and_raise(error)
          allow(output).to receive(:puts) # Capture error logging
        end

        it 'logs the error message to the output' do
          orchestrator.start
          expect(output).to have_received(:puts).with(/Unexpected error in IPC server: Rendering failed/)
        end

        it 'still flushes the output' do
          orchestrator.start
          expect(output).to have_received(:flush)
        end
      end
    end
  end
end
