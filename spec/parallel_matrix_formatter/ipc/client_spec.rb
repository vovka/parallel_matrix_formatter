# frozen_string_literal: true

require 'timeout'

RSpec.describe ParallelMatrixFormatter::Ipc::Client do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'test.sock') }

  after { FileUtils.remove_entry(dir) }

  describe '.connect' do
    it 'raises an Error when nothing listens' do
      expect { described_class.connect(path, timeout: 0.2) }
        .to raise_error(ParallelMatrixFormatter::Error, /no orchestrator listening at #{Regexp.escape(path)}/)
    end

    context 'when a server listens' do
      let(:server) { UNIXServer.new(path) }
      let(:client) { described_class.connect(path, timeout: 1) }

      after do
        client.close
        server.close
      end

      it 'returns a client' do
        server
        expect(client).to be_a(described_class)
      end

      it 'sends notifications as one JSON line each' do
        server
        client.notify(type: 'example', process: 2)
        line = Timeout.timeout(5) { server.accept.gets }
        expect(JSON.parse(line)).to eq('type' => 'example', 'process' => 2)
      end
    end
  end

  describe 'a round trip to the server' do
    let(:server) { ParallelMatrixFormatter::Ipc::Server.new(path) }
    let(:messages) { [] }

    before do
      server
      client = described_class.connect(path, timeout: 1)
      client.notify(type: 'example', process: 2, status: 'passed')
      client.close
      Timeout.timeout(5) do
        server.each_message do |message|
          messages << message
          break if message['type'] == 'disconnected'
        end
      end
    end

    after { server.close }

    it 'delivers the message to the server' do
      expect(messages.first).to eq('type' => 'example', 'process' => 2, 'status' => 'passed')
    end

    it 'reports the disconnect of the process' do
      expect(messages.last).to eq('type' => 'disconnected', 'process' => 2)
    end
  end
end
