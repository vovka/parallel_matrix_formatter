# frozen_string_literal: true
require 'socket'
require 'json'

module ParallelMatrixFormatter
  module Ipc
    # The Client class is responsible for establishing a connection to the IPC server
    # (via a UNIX socket) and sending messages to it. It handles connection retries
    # and provides a `notify` method to send structured data to the server.
    class Client
      SOCKET_PATH = "/tmp/parallel_matrix_formatter.sock"

      def initialize(retries: 10, delay: 1)
        attempts = 0
        begin
          @socket = UNIXSocket.new(SOCKET_PATH)
        rescue Errno::ENOENT => e
          attempts += 1
          if attempts < retries
            sleep delay
            retry
          else
            raise e
          end
        end
      end

      def notify(process_number, message)
        @socket.puts({ process_number: process_number, message: message }.to_json)
      end

      def close
        @socket.close if @socket
      end
    end
  end
end
