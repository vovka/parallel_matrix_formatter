# frozen_string_literal: true

require 'socket'
require 'json'
require 'fileutils'
require 'tmpdir'

module ParallelMatrixFormatter
  module IPC
    class IPCError < StandardError; end

    # UnixSocketServer provides high-performance IPC using Unix domain sockets
    class UnixSocketServer
      def initialize(socket_path = nil)
        @socket_path = socket_path || default_socket_path
        @server = nil
        @clients = []
        @message_queue = Queue.new
        @running = false
      end

      def start
        cleanup_socket
        @server = UNIXServer.new(@socket_path)
        @running = true
        Thread.new { accept_connections }
        Thread.new { process_messages }
        @socket_path
      rescue Errno::EADDRINUSE, Errno::EACCES => e
        raise IPCError, "Failed to start Unix socket server: #{e.message}"
      end

      def stop
        @running = false
        @clients.each(&:close)
        @server&.close
        cleanup_socket
      end

      def each_message
        return enum_for(:each_message) unless block_given?
        loop do
          message = @message_queue.pop
          break if message == :stop
          yield message
        end
      end

      def broadcast(message)
        json_message = JSON.generate(message)
        @clients.each do |client|
          client.puts(json_message)
        rescue IOError, Errno::EPIPE
          @clients.delete(client)
          client.close rescue nil
        end
      end

      private

      def default_socket_path
        File.join(Dir.tmpdir, "parallel_matrix_formatter_#{Process.pid}.sock")
      end
      def cleanup_socket
        FileUtils.rm_f(@socket_path)
      end

      def accept_connections
        while @running && @server
          begin
            client = @server.accept
            @clients << client
            Thread.new { handle_client(client) }
          rescue IOError, Errno::EBADF
            break
          end
        end
      end

      def handle_client(client)
        while @running && !client.closed?
          begin
            line = client.gets
            break unless line
            message = JSON.parse(line.chomp)
            @message_queue << message
          rescue JSON::ParserError => e
            @message_queue << { type: 'error', error: "JSON parse error: #{e.message}" }
          rescue IOError, Errno::EPIPE
            break
          end
        end
      ensure
        @clients.delete(client)
        client.close rescue nil
      end

      def process_messages; end # Handled by orchestrator calling each_message
    end
  end
end