# frozen_string_literal: true

module ParallelMatrixFormatter
  # Handles IPC notifications for the Formatter
  class FormatterNotifier
    def initialize(test_env_number)
      @test_env_number = test_env_number
      @ipc = nil
    end

    def initialize_ipc
      @ipc = ParallelMatrixFormatter::Ipc::Client.new(retries: 30, delay: 0.1)
    end

    def notify_status(status, progress)
      return unless @ipc
      
      @ipc.notify(@test_env_number, { status: status, progress: progress })
    end

    def notify_summary(summary_data)
      return unless @ipc
      
      @ipc.notify(@test_env_number, { type: :summary, data: summary_data })
    end

    def available?
      !@ipc.nil?
    end
  end
end