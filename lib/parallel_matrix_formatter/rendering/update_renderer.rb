# This class orchestrates the rendering of real-time updates during test execution.
# It combines progress information and individual test example statuses into a coherent output,
# leveraging `ProgressUpdater` and `StatusRenderer` for specialized rendering tasks.
module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      def initialize(test_env_number, config)
        @test_env_number = test_env_number
        @progress = {}
        @config = config
        @progress_updater = ProgressUpdater.new(@test_env_number, @progress, @config)
        @status_renderer = StatusRenderer.new(@config)
      end

      def update(message)
        if message && message['process_number'] && message['message']
          @progress[message['process_number']] = message['message']['progress']
        end

        str = ""
        str += @progress_updater.update
        str += @status_renderer.render(message)
        str
      end
    end
  end
end
