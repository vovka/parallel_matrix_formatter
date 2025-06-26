# frozen_string_literal: true

require 'socket'
require 'json'
require 'fileutils'
require 'tmpdir'

module ParallelMatrixFormatter
  # IPC (Inter-Process Communication) module provides standardized communication
  # mechanisms between the orchestrator and worker processes during parallel test execution.
  #
  # This module implements two IPC strategies:
  # 1. UnixSocketServer/Client: High-performance Unix domain sockets (preferred on Unix-like systems)
  # 2. FileBasedIPC: Cross-platform file-based messaging (fallback for Windows or when sockets unavailable)
  #
  # Configuration Integration:
  # =========================
  # All IPC configuration is now centralized in the config object via ConfigLoader:
  # - Server paths, temp directories, and connection parameters from config['ipc']
  # - No direct ENV access or hard-coded paths (except for fallback scenarios)
  # - Mode selection (unix_socket vs file_based) determined by config preferences
  # - Connection timeouts, retry logic controlled by config settings
  #
  # Usage:
  # ======
  # Server (Orchestrator):
  #   server = IPC.create_server(prefer_unix_socket: true, server_path: "/path/to/socket")
  #   server_path = server.start
  #   server.each_message { |msg| handle_message(msg) }
  #   server.stop
  #
  # Client (Worker Process):
  #   client = IPC.create_client(server_path, prefer_unix_socket: true)
  #   client.connect
  #   client.send_message({type: 'progress', data: {...}})
  #   client.close
  #
  module IPC
    class IPCError < StandardError; end

    # UnixSocketServer provides high-performance IPC using Unix domain sockets
    # 
    # This implementation is preferred on Unix-like systems for its performance
    # and reliability. It supports multiple concurrent client connections and
    # provides message queuing for reliable delivery.
    #
    # Configuration Usage:
    # - server_path: Path to Unix socket file (must end with .sock for detection)
    # - All paths provided by centralized config to avoid hard-coded values
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

    # FileBasedIPC provides cross-platform IPC using file system messaging
    #
    # This implementation serves as a fallback when Unix sockets are not available
    # (e.g., on Windows) or when explicitly configured. It uses JSON files in
    # dedicated directories for message passing between processes.
    #
    # Configuration Usage:
    # - base_path: Base directory for inbox/outbox folders (provided by centralized config)
    # - All paths configured centrally to avoid scattered file system access
    #
    # Directory Structure:
    # - base_path/inbox/: Messages TO this process
    # - base_path/outbox/: Messages FROM this process  
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

    # Factory method to create appropriate IPC server based on configuration and platform support
    #
    # This method implements the centralized IPC configuration strategy by selecting
    # the optimal IPC implementation based on:
    # - Platform capabilities (Unix socket support)
    # - Configuration preferences (prefer_unix_socket setting)
    # - Provided server path (socket vs directory path)
    #
    # @param prefer_unix_socket [Boolean] Whether to prefer Unix sockets when available
    # @param server_path [String, nil] Server path (socket file or base directory)
    # @return [UnixSocketServer, FileBasedIPC] Appropriate server implementation
    def self.create_server(prefer_unix_socket: true, server_path: nil)
      if prefer_unix_socket && unix_socket_supported?
        UnixSocketServer.new(server_path)
      else
        FileBasedIPC.new(server_path)
      end
    end

    # Factory method to create appropriate IPC client based on server path and preferences
    #
    # This method automatically detects the server type based on:
    # - Server path extension (.sock indicates Unix socket)
    # - Platform support for Unix sockets
    # - Configuration preferences
    #
    # @param server_path [String] Path to server socket or base directory
    # @param prefer_unix_socket [Boolean] Whether to prefer Unix sockets when available
    # @return [UnixSocketClient, FileBasedIPC] Appropriate client implementation
    def self.create_client(server_path, prefer_unix_socket: true)
      if prefer_unix_socket && unix_socket_supported? && server_path.end_with?('.sock')
        UnixSocketClient.new(server_path)
      else
        FileBasedIPC.new(server_path)
      end
    end

    # Check if Unix sockets are supported on this platform
    #
    # Unix sockets provide superior performance and reliability compared to file-based IPC,
    # but are not available on all platforms (notably Windows).
    #
    # @return [Boolean] True if Unix sockets are supported and available
    def self.unix_socket_supported?
      # Check if Unix sockets are supported (not on Windows in general)
      !Gem.win_platform? && defined?(UNIXSocket)
    end
  end
end
