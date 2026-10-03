# frozen_string_literal: true

require 'timeout'

# Runs code that changes process-wide state (file descriptors, ENV) in a forked
# child and returns everything the child wrote to stdout and stderr.
module ChildProcess
  def capture_from_child(&block)
    reader, writer = IO.pipe
    pid = fork { run_child(reader, writer, &block) }
    writer.close
    Timeout.timeout(10) { reader.read }.tap { Process.wait(pid) }
  end

  private

  def run_child(reader, writer)
    reader.close
    STDOUT.reopen(writer)
    STDERR.reopen(writer)
    yield
  rescue StandardError => e
    writer.write("#{e.class}: #{e.message}")
  ensure
    exit!(0)
  end
end
