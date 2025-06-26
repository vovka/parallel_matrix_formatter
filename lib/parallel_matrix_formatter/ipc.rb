# frozen_string_literal: true

require_relative 'unix_socket_server'
require_relative 'unix_socket_client'
require_relative 'file_based_ipc'

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
        IPC::UnixSocketServer.new(server_path)
      else
        IPC::FileBasedIPC.new(server_path)
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
        IPC::UnixSocketClient.new(server_path)
      else
        IPC::FileBasedIPC.new(server_path)
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