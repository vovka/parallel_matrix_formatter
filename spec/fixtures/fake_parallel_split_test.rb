# frozen_string_literal: true

# Makes the formatter believe it runs under parallel_split_test with two processes.
module ParallelSplitTest
  def self.processes
    2
  end
end
