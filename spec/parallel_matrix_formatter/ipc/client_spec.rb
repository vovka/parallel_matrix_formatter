# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/ipc/client'

RSpec.describe ParallelMatrixFormatter::Ipc::Client do
  let(:mock_socket) { instance_double(UNIXSocket, puts: nil, close: nil) }

  before do
    allow(UNIXSocket).to receive(:new).and_return(mock_socket)
  end

  describe '#initialize' do
    context 'when socket connection is successful' do
      it 'creates a new UNIXSocket' do
        client = described_class.new
        expect(UNIXSocket).to have_received(:new).with(described_class::SOCKET_PATH)
      end
    end

    context 'when socket connection fails initially but succeeds on retry' do
      before do
        allow(UNIXSocket).to receive(:new).and_raise(Errno::ENOENT).once.and_return(mock_socket)
      end

      it 'successfully connects after retries' do
        client = described_class.new(retries: 1, delay: 0.01)
        expect(client).to be_an_instance_of(described_class)
      end
    end

    context 'when socket connection fails after all retries' do
      before do
        allow(UNIXSocket).to receive(:new).and_raise(Errno::ENOENT)
      end

      it 'raises Errno::ENOENT' do
        expect { described_class.new(retries: 1, delay: 0.01) }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe '#notify' do
    let(:client) { described_class.new }
    let(:process_number) { 1 }
    let(:message) { { status: :passed, progress: 0.5 } }
    let(:expected_json) { { process_number: process_number, message: message }.to_json }

    it 'sends a JSON-encoded message to the socket' do
      client.notify(process_number, message)
      expect(mock_socket).to have_received(:puts).with(expected_json)
    end
  end

  describe '#close' do
    let(:client) { described_class.new }

    it 'closes the socket' do
      client.close
      expect(mock_socket).to have_received(:close)
    end

    it 'does not raise an error if socket is nil' do
      allow(UNIXSocket).to receive(:new).and_return(nil) # Simulate failed initialization
      client = described_class.new(retries: 0) rescue nil # Suppress initialization error
      expect { client.close }.not_to raise_error
    end
  end
end
