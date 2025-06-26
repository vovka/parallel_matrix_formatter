# frozen_string_literal: true

module ParallelMatrixFormatter
  module UpdateStrategies
    class BaseStrategy
      def initialize(config)
        @config = config
      end

      def should_update?(_current_progress, _last_update_time, _last_progress)
        raise NotImplementedError, 'Subclasses must implement should_update?'
      end

      def reset
        # Override in subclasses if needed
      end
    end

    class TimeBasedStrategy < BaseStrategy
      def initialize(config)
        super
        @interval = @config['update']['interval_seconds'] || 1
        @last_update_time = nil
      end

      def should_update?(_current_progress, _last_update_time, _last_progress)
        return true if @last_update_time.nil?

        current_time = Time.now.to_f
        current_time - @last_update_time >= @interval
      end

      def reset
        @last_update_time = Time.now.to_f
      end
    end

    class PercentageBasedStrategy < BaseStrategy
      def initialize(config)
        super
        @thresholds = @config['update']['percent_thresholds'] || [5]
        @last_threshold_reached = {}
      end

      def should_update?(current_progress, _last_update_time, last_progress)
        return true if last_progress.nil?

        progress_diff = current_progress - last_progress

        @thresholds.any? do |threshold|
          progress_diff >= threshold
        end
      end

      def reset
        @last_threshold_reached.clear
      end
    end

    class CombinedStrategy < BaseStrategy
      def initialize(config)
        super
        @time_strategy = TimeBasedStrategy.new(config)
        @percentage_strategy = PercentageBasedStrategy.new(config)
      end

      def should_update?(current_progress, last_update_time, last_progress)
        @time_strategy.should_update?(current_progress, last_update_time, last_progress) ||
          @percentage_strategy.should_update?(current_progress, last_update_time, last_progress)
      end

      def reset
        @time_strategy.reset
        @percentage_strategy.reset
      end
    end

    class Registry
      @strategies = {}

      def self.register(name, strategy_class)
        @strategies[name.to_sym] = strategy_class
      end

      def self.get(name)
        @strategies[name.to_sym]
      end

      def self.create(name, config)
        strategy_class = get(name)
        raise ArgumentError, "Unknown update strategy: #{name}" unless strategy_class

        strategy_class.new(config)
      end

      def self.available_strategies
        @strategies.keys
      end
    end

    # Register built-in strategies
    Registry.register(:time_based, TimeBasedStrategy)
    Registry.register(:percentage_based, PercentageBasedStrategy)
    Registry.register(:combined, CombinedStrategy)

    def self.create_strategy(config)
      # Determine which strategy to use based on config
      has_interval = config['update']['interval_seconds']
      has_thresholds = config['update']['percent_thresholds'] && !config['update']['percent_thresholds'].empty?

      strategy_name = if has_interval && has_thresholds
                        :combined
                      elsif has_thresholds
                        :percentage_based
                      else
                        :time_based
                      end

      Registry.create(strategy_name, config)
    end
  end
end
