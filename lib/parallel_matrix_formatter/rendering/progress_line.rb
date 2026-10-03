# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Renders the line showing the progress of every process, e.g.
    # "\n17:04:13 ｷｺｼ89%ﾚﾐｴ､ｷｦｻ92%ｸｪｨｹ ".
    class ProgressLine
      def initialize(config, digits)
        @format = config['format']
        @digits = digits
        @column = ProgressColumn.new(config['column'], digits)
      end

      # @param progress [Hash{Integer => Float}] latest progress of every process
      def render(progress)
        columns = progress.sort.map { |_process, value| @column.render(value) }.join
        @format.gsub('{time}', time).gsub('{columns}', columns)
      end

      private

      def time
        Digits.replace(Time.now.strftime('%H:%M:%S'), @digits)
      end
    end
  end
end
