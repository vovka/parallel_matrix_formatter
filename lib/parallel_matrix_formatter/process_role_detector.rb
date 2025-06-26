# frozen_string_literal: true

module ParallelMatrixFormatter
  # ProcessRoleDetector determines whether the current process should act as orchestrator.
  # This class was extracted from Formatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Determine orchestrator vs worker process role
  # - Handle atomic lock file creation for process coordination
  # - Check for existing orchestrator processes
  # - Clean up stale lock files from dead processes
  #
  class ProcessRoleDetector
    # Check if this is the main process that should act as orchestrator
    # @param config [Hash] Configuration object with IPC and environment settings
    # @return [Boolean] True if this process should be the orchestrator
    def self.orchestrator_process?(config)
      # If explicitly set as orchestrator, always return true
      return true if config['environment']['force_orchestrator']
      
      # If server is already running, we're not the orchestrator
      return false if config['environment']['server_path']
      
      # Use configured lock file path for orchestrator determination
      lock_file = config['ipc']['orchestrator_lock_file']
      
      begin
        # Try to create lock file atomically
        File.open(lock_file, File::CREAT | File::EXCL | File::WRONLY) do |f|
          f.write(Process.pid.to_s)
          f.flush
          return true  # We successfully created the lock, so we're the orchestrator
        end
      rescue Errno::EEXIST
        # Lock file already exists, check if the process is still running
        begin
          existing_pid = File.read(lock_file).to_i
          # Check if process is still running
          Process.kill(0, existing_pid)
          return false  # Process is still running, we're not the orchestrator
        rescue Errno::ESRCH, Errno::EPERM
          # Process is not running, remove stale lock and try again
          File.delete(lock_file) rescue nil
          retry
        rescue
          return false  # Can't determine, assume we're not the orchestrator
        end
      rescue
        # If we can't create the lock file, assume we're not the orchestrator
        return false
      end
    end

    # Clean up orchestrator lock file
    # @param config [Hash] Configuration object with IPC settings
    def self.cleanup_lock_file(config)
      lock_file = config['ipc']['orchestrator_lock_file']
      File.delete(lock_file) if File.exist?(lock_file)
    rescue
      # Ignore cleanup errors
    end
  end
end