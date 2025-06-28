# frozen_string_literal: true

require_relative './null_io'

module ParallelMatrixFormatter
  module Output
    class Suppressor
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
        $stdout = Output::NullIO.new
        # TODO: this is a specific case for RSpec, consider making it more generic,
        # maybe move to a more generic suppressor or make it configurable. Also,
        # need to ensure that RSpec is defined and loaded.
        RSpec::Support.warning_notifier = -> w { }
      end

      def restore
        $stdout = @original_stdout if @original_stdout
      end

      def notify(output = nil)
        output ||= @original_stdout
        # TODO: this is a specific case for Rails, consider making it more generic,
        # maybe move to a more generic suppressor or make it configurable. Also,
        # need to ensure that Rails is defined and loaded.
        if output && defined?(Rails) && Rails.respond_to?(:application) && Rails.application.config.active_support.deprecation != :silence
          output.print "\n\n\n For better exeperience, set config.active_support.deprecation = :silence in the config/environments/test.rb \n\n\n"
        else
          # output.print "\n\n\n Everything is suppressed, no output will be shown.\n\n\n"
        end
      end
    end
  end
end