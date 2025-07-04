# frozen_string_literal: true

module ParallelMatrixFormatter
  module Output
    # The NullIO class is a black hole for output. It provides a no-op implementation
    # for common IO methods like `write`, `puts`, `print`, and `flush`.
    # This is useful for suppressing output when it's not desired, for example,
    # during test execution or in background processes.
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
end
