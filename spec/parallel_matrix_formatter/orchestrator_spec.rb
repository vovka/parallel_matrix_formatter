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
      context 'when using a multi-process orchestrator' do
        let(:multi_process_orchestrator) { described_class.new(2, 1, output, renderer) }
        it 'closes the IPC server after all processes complete' do
          (1..multi_process_orchestrator.total_processes).each do |i|
            multi_process_orchestrator.send(:track_process_completion, i, 1.0)
          end
          multi_process_orchestrator.close
          expect(ipc_server).to have_received(:close)
        end
      end
      context 'when using a single-process orchestrator' do
        let(:single_process_orchestrator) { described_class.new(1, 1, output, renderer) }
        it 'closes the IPC server without additional process tracking' do
          single_process_orchestrator.close
          expect(ipc_server).to have_received(:close)
        end
      end
    end

    describe 'completion tracking and buffering' do
      it 'buffers dump messages until all processes complete in multi-process mode' do
        orchestrator.puts("\ndump_summary")
        expect(output.string).to eq("")

        # Complete process 1
        orchestrator.send(:track_process_completion, 1, 1.0)
        orchestrator.send(:process_buffered_messages_if_complete)
        expect(output.string).to eq("")

        # Complete process 2 - now summary should be printed
        orchestrator.send(:track_process_completion, 2, 1.0)
        orchestrator.send(:process_buffered_messages_if_complete)
        expect(output.string).to eq("\ndump_summary\n")
      end

      it 'prints dump messages immediately in single process mode' do
        single_process_orchestrator = described_class.new(1, 1, output, renderer)
        allow(ParallelMatrixFormatter::Ipc::Server).to receive(:new).and_return(ipc_server)

        single_process_orchestrator.puts("\ndump_summary")
        expect(output.string).to eq("\ndump_summary\n")
      end

      it 'processes messages when completion is tracked via start method' do
        messages = []
        # Mock the IPC start method to simulate message reception
        allow(ipc_server).to receive(:start) do |&block|
          messages << { 'process_number' => 1, 'message' => { 'progress' => 0.5 } }
          messages << { 'process_number' => 2, 'message' => { 'progress' => 0.8 } }
          messages << { 'process_number' => 1, 'message' => { 'progress' => 1.0 } }
          messages << { 'process_number' => 2, 'message' => { 'progress' => 1.0 } }
          messages.each { |msg| block.call(msg) }
        end

        # Mock Thread.new to execute synchronously
        allow(Thread).to receive(:new) { |&block| block.call }

        # Start the orchestrator
        orchestrator.start

        # Buffer a dump message
        orchestrator.puts("\ndump_summary")

        # The message should be in the output because all processes completed
        expect(output.string).to include("dump_summary")
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

    describe 'summary message handling' do
      let(:multi_process_orchestrator) { described_class.new(2, 1, output, renderer) }
      let(:summary_message_1) do
        {
          'process_number' => 1,
          'message' => {
            'type' => 'summary',
            'data' => {
              'total_examples' => 5,
              'failed_examples' => [
                {
                  'description' => 'fails test 1',
                  'location' => 'spec/test_spec.rb:10',
                  'message' => 'Expected true to be false',
                  'formatted_backtrace' => 'spec/test_spec.rb:10:in `block`'
                }
              ],
              'pending_count' => 1,
              'duration' => 1.5,
              'process_number' => 1
            }
          }
        }
      end
      let(:summary_message_2) do
        {
          'process_number' => 2,
          'message' => {
            'type' => 'summary',
            'data' => {
              'total_examples' => 3,
              'failed_examples' => [
                {
                  'description' => 'fails test 2',
                  'location' => 'spec/test2_spec.rb:20',
                  'message' => 'Expected 1 to equal 2',
                  'formatted_backtrace' => 'spec/test2_spec.rb:20:in `block`'
                }
              ],
              'pending_count' => 0,
              'duration' => 2.0,
              'process_number' => 2
            }
          }
        }
      end

      before do
        allow(Thread).to receive(:new) { |&block| block.call }
        allow(ipc_server).to receive(:start) do |&block|
          block.call(summary_message_1)
          block.call(summary_message_2)
        end
        allow(output).to receive(:puts)
        allow(output).to receive(:print)
        allow(output).to receive(:flush)
      end

      it 'collects and renders consolidated summary when all processes report' do
        multi_process_orchestrator.start
        
        expect(output).to have_received(:puts).with("\n")
        expect(output).to have_received(:puts).with("Failures:")
        expect(output).to have_received(:puts).with(no_args).at_least(1).times
        expect(output).to have_received(:puts).with("  1) fails test 1")
        expect(output).to have_received(:puts).with("     spec/test_spec.rb:10")
        expect(output).to have_received(:puts).with("     Expected true to be false")
        expect(output).to have_received(:puts).with("  2) fails test 2")
        expect(output).to have_received(:puts).with("     spec/test2_spec.rb:20")
        expect(output).to have_received(:puts).with("     Expected 1 to equal 2")
        expect(output).to have_received(:puts).with("8 examples, 2 failures, 1 pending")
        expect(output).to have_received(:puts).with(/Finished in .* seconds/)
      end
      
      it 'handles missing summaries gracefully' do
        # Create a new orchestrator with short timeout
        timeout_orchestrator = described_class.new(2, 1, output, renderer)
        timeout_orchestrator.instance_variable_set(:@summary_timeout, 0.1) # Very short timeout for testing
        
        # Mock the process completion to simulate all processes done
        timeout_orchestrator.instance_variable_set(:@process_completion, {1 => true, 2 => true})
        
        # Only provide summary from process 1
        timeout_orchestrator.instance_variable_set(:@process_summaries, {1 => summary_message_1['message']['data']})
        
        allow(output).to receive(:puts)
        
        timeout_orchestrator.send(:wait_for_summaries)
        
        expect(output).to have_received(:puts).with(/Warning: Did not receive summaries from process/)
      end
    end
  end
end
