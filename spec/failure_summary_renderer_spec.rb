# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter/failure_summary_renderer'

RSpec.describe ParallelMatrixFormatter::FailureSummaryRenderer do
  let(:config) do
    {
      'colors' => {
        'time' => 'green',
        'percent' => 'red',
        'rain' => 'green',
        'pass_dot' => 'green',
        'fail_dot' => 'red',
        'pending_dot' => 'white'
      }
    }
  end

  let(:renderer) { described_class.new(config) }

  describe '#render_failure_summary' do
    it 'returns empty string for no failures' do
      result = renderer.render_failure_summary([])
      expect(result).to eq('')
    end

    it 'renders failure details' do
      failures = [
        {
          description: 'example fails',
          location: './spec/example_spec.rb:10',
          message: 'Expected true but got false'
        }
      ]
      
      result = renderer.render_failure_summary(failures)
      expect(result).to include('FAILED EXAMPLES')
      expect(result).to include('1. example fails')
      expect(result).to include('Location: ./spec/example_spec.rb:10')
      expect(result).to include('Expected true but got false')
    end
  end

  describe '#render_final_summary' do
    it 'renders test statistics' do
      result = renderer.render_final_summary(100, 5, 2, 45.5, [20.1, 25.4], 2)

      expect(result).to include('100 examples')
      expect(result).to include('5 failures')
      expect(result).to include('2 pending')
      expect(result).to include('Processes: 2')
    end
  end
end