# frozen_string_literal: true

require 'timeout'

RSpec.describe ParallelMatrixFormatter::Ipc::Server do
  subject(:server) { described_class.new(path) }

  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'test.sock') }
  let(:client) { UNIXSocket.new(path) }

  after do
    server.close
    FileUtils.remove_entry(dir)
  end

  def messages(count)
    received = []
    Timeout.timeout(5) do
      server.each_message do |message|
        received << message
        break if received.size == count
      end
    end
    received
  end

  describe '#each_message' do
    before { server }

    it 'yields the JSON message a client sent' do
      client.puts('{"type":"example","process":2}')
      expect(messages(1)).to eq([{ 'type' => 'example', 'process' => 2 }])
    end

    it 'yields messages in arrival order' do
      client.puts('{"process":1,"n":1}', '{"process":1,"n":2}')
      expect(messages(2).map { |message| message['n'] }).to eq([1, 2])
    end

    it 'yields nil whenever no message arrives within the poll interval' do
      ticks = []
      Timeout.timeout(5) do
        server.each_message(poll_interval: 0.05) do |message|
          ticks << message
          break if ticks.size == 2
        end
      end
      expect(ticks).to eq([nil, nil])
    end

    it 'queues a disconnected message with the process number when the client closes' do
      client.puts('{"type":"example","process":3}')
      client.close
      expect(messages(2).last).to eq('type' => 'disconnected', 'process' => 3)
    end
  end

  describe '#idle?' do
    before { server }

    it 'is true before any client connects' do
      expect(server.idle?).to be(true)
    end

    it 'is false while a client is connected or waiting to be accepted' do
      client
      expect(server.idle?).to be(false)
    end

    it 'is false while the messages of a client that has gone are unread' do
      client.puts('{"type":"example","process":3}')
      client.close
      expect(server.idle?).to be(false)
    end

    it 'becomes true once every client has disconnected and its messages are read' do
      client.puts('{"type":"example","process":3}')
      client.close
      messages(2)
      expect { Timeout.timeout(5) { sleep 0.01 until server.idle? } }.not_to raise_error
    end
  end

  describe '#close' do
    it 'removes the socket file' do
      server.close
      expect(File.exist?(path)).to be(false)
    end

    it 'ends each_message' do
      server.close
      expect { |probe| Timeout.timeout(5) { server.each_message(&probe) } }.not_to yield_control
    end
  end

  describe '.new' do
    it 'replaces a stale socket file' do
      File.write(path, '')
      expect(server).to be_a(described_class)
    end
  end
end
