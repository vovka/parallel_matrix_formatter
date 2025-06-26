# frozen_string_literal: true

require 'socket'
require 'json'

module ParallelMatrixFormatter
  module IPC
    class IPCError < StandardError; end

    # UnixSocketClient provides client-side Unix domain socket communication
    #
    # This client connects to UnixSocketServer instances and provides reliable
    # message delivery with automatic JSON serialization.
    #
    # Configuration Usage:
    # - socket_path: Path to Unix socket file (provided by centralized config)
    class UnixSocketClient
      def initialize(socket_path)
        @socket_path = socket_path
        @socket = nil
      end

      def connect
        @socket = UNIXSocket.new(@socket_path)
        true
      rescue Errno::ENOENT, Errno::ECONNREFUSED => e
        raise IPCError, "Failed to connect to Unix socket: #{e.message}"
      end

      def send_message(message)
        return false unless @socket

        json_message = JSON.generate(message)
        @socket.puts(json_message)
        true
      rescue IOError, Errno::EPIPE => e
        raise IPCError, "Failed to send message: #{e.message}"
      end

      def close
        @socket&.close
        @socket = nil
      end
    end
  end
end