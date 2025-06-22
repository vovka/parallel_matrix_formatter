# frozen_string_literal: true

require 'socket'
require 'json'
require 'fileutils'
require 'tmpdir'

module ParallelMatrixFormatter
  module IPC
    class IPCError < StandardError; end

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

        # Start accepting connections
        Thread.new { accept_connections }
        # Start message processing
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
          begin
            client.close
          rescue StandardError
            nil
          end
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
            # Log parsing error but continue
            @message_queue << { type: 'error', error: "JSON parse error: #{e.message}" }
          rescue IOError, Errno::EPIPE
            break
          end
        end
      ensure
        @clients.delete(client)
        begin
          client.close
        rescue StandardError
          nil
        end
      end

      def process_messages
        # This is handled by the orchestrator calling each_message
      end
    end

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

    class FileBasedIPC
      def initialize(base_path = nil)
        @base_path = base_path || File.join(Dir.tmpdir, "parallel_matrix_formatter_#{Process.pid}")
        @inbox_path = File.join(@base_path, 'inbox')
        @outbox_path = File.join(@base_path, 'outbox')
        @running = false
        @message_files = []
      end

      def start
        FileUtils.mkdir_p(@inbox_path)
        FileUtils.mkdir_p(@outbox_path)
        @running = true
        @base_path
      end

      def stop
        @running = false
        FileUtils.rm_rf(@base_path)
      end

      def send_message(message)
        filename = "#{Time.now.to_f}_#{Process.pid}_#{rand(1000)}.json"
        filepath = File.join(@inbox_path, filename)

        File.write(filepath, JSON.generate(message))
        true
      rescue StandardError => e
        raise IPCError, "Failed to write message file: #{e.message}"
      end

      def each_message(&block)
        return enum_for(:each_message) unless block_given?

        while @running
          process_inbox_messages(&block)
          sleep 0.1 # Polling interval
        end
      end

      private

      def process_inbox_messages
        return unless File.exist?(@inbox_path)

        Dir.glob(File.join(@inbox_path, '*.json')).sort.each do |file|
          next unless File.exist?(file)

          begin
            content = File.read(file)
            message = JSON.parse(content)
            File.unlink(file)
            yield message
          rescue JSON::ParserError => e
            File.unlink(file) # Remove corrupted file
            yield({ type: 'error', error: "JSON parse error: #{e.message}" })
          rescue StandardError
            # Retry on next iteration
            break
          end
        end
      end
    end

    def self.create_server(prefer_unix_socket: true)
      if prefer_unix_socket && unix_socket_supported?
        UnixSocketServer.new
      else
        FileBasedIPC.new
      end
    end

    def self.create_client(server_path, prefer_unix_socket: true)
      if prefer_unix_socket && unix_socket_supported? && server_path.end_with?('.sock')
        UnixSocketClient.new(server_path)
      else
        FileBasedIPC.new(server_path)
      end
    end

    def self.unix_socket_supported?
      # Check if Unix sockets are supported (not on Windows in general)
      !Gem.win_platform? && defined?(UNIXSocket)
    end
  end
end
