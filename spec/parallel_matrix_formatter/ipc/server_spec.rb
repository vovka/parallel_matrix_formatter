# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/ipc/server'

RSpec.describe ParallelMatrixFormatter::Ipc::Server do
  let(:socket_path) { described_class::SOCKET_PATH }
  let(:mock_server) { instance_double(UNIXServer) }
  let(:mock_client_socket) { instance_double(UNIXSocket, gets: nil, close: nil) }

  before do
    allow(File).to receive(:exist?).with(socket_path).and_return(false)
    allow(File).to receive(:delete).with(socket_path)
    allow(UNIXServer).to receive(:new).with(socket_path).and_return(mock_server)
    allow(mock_server).to receive(:accept).and_return(mock_client_socket)
    allow(mock_server).to receive(:close)
    # Stub Thread.new to execute the block immediately and synchronously
    allow(Thread).to receive(:new) { |&block| block.call }
  end

  describe '#initialize' do
    it 'deletes the socket file if it exists' do
      allow(File).to receive(:exist?).with(socket_path).and_return(true)
      expect(File).to receive(:delete).with(socket_path)
      described_class.new
    end

    it 'creates a new UNIXServer' do
      expect(UNIXServer).to receive(:new).with(socket_path)
      described_class.new
    end
  end

  describe '#start' do
    subject(:server) { described_class.new }

    before do
      # Stub the loop to run only once for testing purposes
      allow(server).to receive(:loop).and_yield
    end

    it 'accepts a client connection' do
      server.start
      expect(mock_server).to have_received(:accept)
    end

    context 'when a message is received' do
      let(:message_data) { { 'process_number' => 1, 'message' => { 'status' => 'passed' } } }
      let(:json_message) { message_data.to_json + "\n" }

      before do
        allow(mock_client_socket).to receive(:gets).and_return(json_message, nil) # Return message then nil to stop loop
      end

      it 'yields the parsed message to the block' do
        expect { |b| server.start(&b) }.to yield_with_args(message_data)
      end

      it 'closes the client socket' do
        server.start
        expect(mock_client_socket).to have_received(:close)
      end
    end

    context 'when an invalid JSON message is received' do
      let(:invalid_json_message) { "not json\n" }

      before do
        allow(mock_client_socket).to receive(:gets).and_return(invalid_json_message, nil)
      end

      it 'yields an error message to the block' do
        expect { |b| server.start(&b) }.to yield_with_args(hash_including(error: "Invalid JSON format"))
      end

      it 'closes the client socket' do
        server.start
        expect(mock_client_socket).to have_received(:close)
      end
    end

    context 'when client socket raises IOError' do
      before do
        allow(mock_client_socket).to receive(:gets).and_raise(IOError, "Broken pipe")
      end

      it 'closes the client socket' do
        server.start
        expect(mock_client_socket).to have_received(:close)
      end
    end
  end

  describe '#close' do
    it 'closes the server socket' do
      server = described_class.new
      server.close
      expect(mock_server).to have_received(:close)
    end

    it 'deletes the socket file' do
      # Ensure the file exists so delete is called during close
      allow(File).to receive(:exist?).with(socket_path).and_return(true)
      # Stub File.delete during initialization to prevent it from being called
      # and interfering with the expectation for the close method.
      allow(File).to receive(:delete).with(socket_path)

      server = described_class.new
      # Now, expect delete to be called when close is invoked
      expect(File).to receive(:delete).with(socket_path).once
      server.close
    end

    it 'does not raise an error if server is nil' do
      server = described_class.new
      # Directly set @server to nil to simulate failed initialization
      server.instance_variable_set(:@server, nil)
      expect { server.close }.not_to raise_error
    end
  end
end
