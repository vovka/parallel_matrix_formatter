# frozen_string_literal: true

module ParallelMatrixFormatter
  class OutputSuppressor
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

    include Singleton

    def self.suppress
      return if @suppressed

      unless Config.instance.suppress == false
        instance.suppress
        @suppressed = true
      end
      instance
    end

    def suppress
      @original_stdout = $stdout
      $stdout = NullIO.new
      RSpec::Support.warning_notifier = -> w { }
    end

    def restore
      $stdout = @original_stdout if @original_stdout
    end

    def notify(output = nil)
      output ||= @original_stdout
      if output && defined?(Rails) && Rails.respond_to?(:application) && Rails.application.config.active_support.deprecation != :silence
        output.print "\n\n\n For better exeperience, set config.active_support.deprecation = :silence in the config/environments/test.rb \n\n\n"
      else
        # output.print "\n\n\n Everything is suppressed, no output will be shown.\n\n\n"
      end
    end
  end
end
