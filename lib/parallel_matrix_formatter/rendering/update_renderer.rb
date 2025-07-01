require_relative 'update_renderer/format_helper'
require_relative 'update_renderer/progress_updater'
require_relative 'update_renderer/status_renderer'

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
