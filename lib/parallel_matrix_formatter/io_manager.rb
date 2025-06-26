# frozen_string_literal: true

module ParallelMatrixFormatter
  # IOManager handles the preservation and restoration of IO streams for the
  # parallel matrix formatter. It centralizes IO stream management and provides
  # access to original streams for orchestrator communication.
  #
  class IOManager
    # Class-level storage for original IO streams (before any suppression)
    @@original_stdout = nil
    @@original_stderr = nil
    @@original_verbose = nil
    @@io_preserved = false

    # Preserve original IO streams for orchestrator use
    def self.preserve_original_io
      return if @@io_preserved
      
      @@original_stdout = $stdout
      @@original_stderr = $stderr
      @@original_verbose = $VERBOSE
      @@io_preserved = true
    end

    # Get original stdout for orchestrator use
    def self.original_stdout
      preserve_original_io unless @@io_preserved
      @@original_stdout
    end

    # Get original stderr for orchestrator use  
    def self.original_stderr
      preserve_original_io unless @@io_preserved
      @@original_stderr
    end

    # Get original verbose setting
    def self.original_verbose
      preserve_original_io unless @@io_preserved
      @@original_verbose
    end

    # Check if IO has been preserved
    def self.io_preserved?
      @@io_preserved
    end

    # Reset IO preservation state (useful for testing)
    def self.reset
      @@original_stdout = nil
      @@original_stderr = nil
      @@original_verbose = nil
      @@io_preserved = false
    end
  end

  # NullIO class for redirecting output to nowhere
  class NullIO
    def write(*args); end
    def puts(*args); end
    def print(*args); end
    def printf(*args); end
    def flush; end
    def sync=(*args); end
    def close; end

    def closed?
      false
    end

    def tty?
      false
    end
  end
end