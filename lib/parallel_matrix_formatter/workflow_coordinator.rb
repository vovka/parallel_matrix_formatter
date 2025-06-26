# frozen_string_literal: true

module ParallelMatrixFormatter
  # WorkflowCoordinator handles the orchestrator's main processing workflow.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Coordinate message processing workflow
  # - Manage display update decisions
  # - Handle process completion checks
  # - Orchestrate interactions between components
  #
  class WorkflowCoordinator
    def initialize(message_handler, display_manager, process_manager, output_manager)
      @message_handler = message_handler
      @display_manager = display_manager
      @process_manager = process_manager
      @output_manager = output_manager
    end

    # Process a message and handle resulting workflow
    # @param message [Hash] The message to process
    # @return [Boolean] True if all processes are complete
    def process_message(message)
      test_result = @message_handler.handle_message(message)
      
      # Handle specific message types that require display updates
      case @message_handler.normalize_message_keys(message)['type']
      when 'register', 'complete'
        update_base_display
      when 'progress'
        # Render live test result if provided
        render_live_test_result(test_result) if test_result
        
        # Check if we should update display (for base line)
        update_base_display if @display_manager.should_update_display?
      end
      
      # Check if all processes are complete
      @process_manager.all_processes_complete?
    end

    # Update the base display
    def update_base_display
      base_line, rendered = @display_manager.update_base_display
      return unless base_line

      # Print base line and stay on same line for test dots
      @output_manager.print "#{base_line} "
      @output_manager.flush
      @display_manager.set_line_rendered if rendered
    end

    # Render a live test result
    # @param test_result [Hash] The test result to render
    def render_live_test_result(test_result)
      test_dot = @display_manager.render_live_test_result(test_result)
      return unless test_dot

      @output_manager.print test_dot
      @output_manager.flush
    end

    # Finalize current display line
    def finalize_current_line
      @output_manager.puts if @display_manager.finalize_current_line
    end

    # Print final summary
    # @param renderer [Object] The renderer to use for generating summaries
    def print_final_summary(renderer)
      # Print failure summary
      failures = @process_manager.get_failures
      if failures.any?
        failure_summary = renderer.render_failure_summary(failures)
        @output_manager.puts failure_summary
      end

      # Get summary statistics and render final summary
      summary = @process_manager.generate_final_summary
      final_summary = renderer.render_final_summary(
        summary[:total_tests],
        summary[:failed_tests],
        summary[:pending_tests],
        summary[:total_duration],
        summary[:process_durations],
        summary[:process_count]
      )
      @output_manager.puts final_summary
    end
  end
end