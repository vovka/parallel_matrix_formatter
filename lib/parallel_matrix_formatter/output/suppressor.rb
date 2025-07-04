# frozen_string_literal: true

require_relative './null_io'

module ParallelMatrixFormatter
  module Output
    # The Suppressor class manages the suppression and restoration of standard output ($stdout).
    # It is used to prevent unwanted output from appearing in the console during certain operations,
    # such as test execution. It also handles RSpec warning suppression and provides a notification
    # mechanism for Rails deprecation warnings.
    class Suppressor
      @@suppressed = false

      def initialize(config)
        @config = config
      end

      def suppress
        return if @@suppressed

        return unless @config["suppress"]

        @original_stdout = $stdout
        $stdout = Output::NullIO.new
        # TODO: this is a specific case for RSpec, consider making it more generic,
        # maybe move to a more generic suppressor or make it configurable. Also,
        # need to ensure that RSpec is defined and loaded.
        RSpec::Support.warning_notifier = -> w { }

        @@suppressed = true
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
