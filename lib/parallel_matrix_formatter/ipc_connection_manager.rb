# frozen_string_literal: true

require_relative 'ipc'

module ParallelMatrixFormatter
  # IpcConnectionManager handles IPC connection establishment and management.
  # This class was extracted from ProcessFormatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Establish IPC connection using centralized configuration
  # - Handle connection retry logic with configurable timeouts
  # - Discover server path through multiple configured sources
  # - Manage connection state and cleanup
  #
  class IpcConnectionManager
    def initialize(config)
      @config = config
      @ipc_client = nil
      @connected = false
    end

    # Connect to the orchestrator using centralized IPC configuration
    # @return [Boolean] True if connection was successful
    def connect_to_orchestrator
      ipc_config = @config['ipc']
      max_attempts = ipc_config['retry_attempts']
      retry_delay = ipc_config['retry_delay']
      connection_timeout = ipc_config['connection_timeout']
      
      attempts = 0
      start_time = Time.now
      
      while attempts < max_attempts && (Time.now - start_time) < connection_timeout
        # Get server path from configuration first
        server_path = @config['environment']['server_path']
        
        # Fallback to reading from configured server path file only if explicitly configured
        if !server_path && ipc_config['server_path_file']
          server_path = File.read(ipc_config['server_path_file']).strip if File.exist?(ipc_config['server_path_file'])
        end
        
        # Use default server path from IPC config if still not found
        server_path ||= ipc_config['server_path']
        
        break unless server_path  # No server configured
        
        begin
          @ipc_client = IPC.create_client(
            server_path,
            prefer_unix_socket: ipc_config['prefer_unix_socket']
          )
          @ipc_client.connect
          @connected = true
          return true
        rescue IPC::IPCError
          # Server not ready yet, wait and retry
          attempts += 1
          sleep(retry_delay) if attempts < max_attempts
        end
      end

      # Failed to connect after all attempts
      @connected = false
      false
    end

    # Check if connected to orchestrator
    # @return [Boolean] True if connected
    def connected?
      @connected
    end

    # Send a message through the IPC connection
    # @param message [Hash] Message to send
    # @return [Boolean] True if message was sent successfully
    def send_message(message)
      return false unless @connected

      begin
        @ipc_client.send_message(message)
        true
      rescue IPC::IPCError
        # Connection lost, mark as disconnected
        @connected = false
        false
      end
    end

    # Close the IPC connection
    def close
      @ipc_client&.close
      @connected = false
    end
  end
end