# frozen_string_literal: true

require 'json'
require 'socket'

module ParallelMatrixFormatter
  module Ipc
    # Sends messages to the orchestrator's server.
    class Client
      # Process 1 may still be loading spec files when the others start.
      CONNECT_TIMEOUT = 120

      def self.connect(path, timeout: CONNECT_TIMEOUT)
        deadline = Time.now + timeout
        begin
          new(UNIXSocket.new(path))
        rescue Errno::ENOENT, Errno::ECONNREFUSED
          raise Error, "no orchestrator listening at #{path} after #{timeout}s" if Time.now > deadline

          sleep 0.1
          retry
        end
      end

      def initialize(socket)
        @socket = socket
      end

      def notify(message)
        @socket.puts(JSON.generate(message))
      end

      def close
        @socket.close
      end
    end
  end
end
