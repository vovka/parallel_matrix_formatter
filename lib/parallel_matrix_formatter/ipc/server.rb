# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'socket'

module ParallelMatrixFormatter
  module Ipc
    # Accepts connections from every test process and queues their messages.
    # When a client disconnects, a synthetic `disconnected` message carrying its
    # process number is queued, so a crashed process is noticed too.
    class Server
      def initialize(path)
        FileUtils.rm_f(path)
        @path = path
        @socket = UNIXServer.new(path)
        @messages = Queue.new
        @acceptor = Thread.new { accept_clients }
      end

      # Yields messages in arrival order until the server is closed. With a
      # poll interval it also yields nil whenever that long passes without a
      # message, so the caller can check on the processes it is waiting for.
      def each_message(poll_interval: nil)
        loop do
          message = @messages.pop(timeout: poll_interval)
          break if message.nil? && @messages.closed?

          yield message
        end
      end

      def close
        @socket.close
        @messages.close
        FileUtils.rm_f(@path)
      end

      private

      def accept_clients
        loop { Thread.new(@socket.accept) { |client| read(client) } }
      rescue IOError, Errno::EBADF
        nil # the socket was closed
      end

      def read(client)
        process = nil
        while (line = client.gets)
          message = JSON.parse(line)
          process = message['process']
          enqueue(message)
        end
        enqueue('type' => 'disconnected', 'process' => process) if process
      ensure
        client.close
      end

      def enqueue(message)
        @messages << message
      rescue ClosedQueueError
        nil # nobody is listening any more
      end
    end
  end
end
