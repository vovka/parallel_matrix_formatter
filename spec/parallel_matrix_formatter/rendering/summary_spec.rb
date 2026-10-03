# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::Summary do
  subject(:output) { described_class.new.render(summaries, missing_processes) }

  before { stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '1')) }

  let(:missing_processes) { [] }
  let(:failure) do
    { 'description' => 'adds up', 'location' => './spec/a_spec.rb:7',
      'message_lines' => ['Failure/Error: expect(1).to eq(2)'], 'backtrace' => ['# ./spec/a_spec.rb:7'] }
  end
  let(:summaries) do
    [{ 'process' => 1, 'examples' => 3, 'failures' => 1, 'pending' => 0, 'duration' => 1.5,
       'failed_examples' => [failure] },
     { 'process' => 2, 'examples' => 2, 'failures' => 0, 'pending' => 1, 'duration' => 0.5,
       'failed_examples' => [] }]
  end

  describe '#render' do
    it 'starts with a blank line' do
      expect(output).to start_with("\n")
    end

    it 'sums the examples, failures and pending examples of every process' do
      expect(output).to include('5 examples, 1 failure, 1 pending')
    end

    it 'sums the durations of the processes' do
      expect(output).to include('(2 seconds across processes)')
    end

    it 'lists the failures with their number and description' do
      expect(output).to include('Failures:', '  1) adds up')
    end

    it 'indents the failure details under the description' do
      expect(output).to include("     Failure/Error: expect(1).to eq(2)\n     # ./spec/a_spec.rb:7")
    end

    it 'lists the commands to rerun the failures' do
      expect(output).to include('rspec ./spec/a_spec.rb:7 # adds up')
    end

    it 'does not warn when every process reported' do
      expect(output).not_to include('WARNING')
    end

    context 'when there are several failures' do
      let(:summaries) { [{ **super().first, 'failed_examples' => [failure, failure] }] }

      it 'numbers them in order' do
        expect(output).to include('  2) adds up')
      end
    end

    context 'when nothing failed or is pending' do
      let(:summaries) do
        [{ 'examples' => 1, 'failures' => 0, 'pending' => 0, 'duration' => 0.1, 'failed_examples' => [] }]
      end

      it 'prints the totals' do
        expect(output).to include('1 example, 0 failures')
      end

      it 'omits the pending count' do
        expect(output).not_to include('pending')
      end

      it 'has no failures section' do
        expect(output).not_to include('Failures:')
      end

      it 'has no rerun commands' do
        expect(output).not_to include('Failed examples:')
      end
    end

    context 'when examples are pending but none failed' do
      let(:summaries) do
        [{ 'examples' => 2, 'failures' => 0, 'pending' => 2, 'duration' => 0.1, 'failed_examples' => [] }]
      end

      it 'prints the totals with the pending count' do
        expect(output).to include('2 examples, 0 failures, 2 pending')
      end

      it 'colors the totals yellow' do
        stub_const('ENV', ENV.to_h.except('NO_COLOR'))
        expect(output).to include("\e[33m2 examples, 0 failures, 2 pending\e[0m")
      end
    end

    context 'when a process never sent a summary' do
      let(:missing_processes) { [2, 3] }

      it 'warns about the missing processes' do
        expect(output).to include('WARNING: no summary received from process 2, 3')
      end
    end
  end
end
