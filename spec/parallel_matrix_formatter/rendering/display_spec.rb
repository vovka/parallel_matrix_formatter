# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::Display do
  subject(:display) { described_class.new(config, 2) }

  before { stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '1')) }

  let(:progress_update) { { 'always' => false, 'interval_seconds' => 0, 'percent_threshold' => 0 } }
  let(:config) do
    { 'digits' => '',
      'progress_update' => progress_update,
      'progress_line' => { 'format' => '[{columns}]', 'column' => { 'width' => 3, 'pad_symbols' => '.' } },
      'example_status' => { 'format' => '{symbol}', 'symbols' => { 'passed' => 'p' }, 'colors' => {} } }
  end

  describe '#example' do
    it 'returns the status symbol' do
      expect(display.example(1, 'passed', 0.5)).to eq('p')
    end

    context 'when the policy says a progress line is due' do
      let(:progress_update) { super().merge('always' => true) }

      it 'precedes the symbol with the progress line' do
        expect(display.example(1, 'passed', 0.5)).to eq('[50%0%.]p')
      end

      it 'shows a column for every process before all of them have reported' do
        expect(display.example(2, 'passed', 0.5)).to eq('[0%.50%]p')
      end

      it 'shows the latest progress of every process' do
        display.example(1, 'passed', 0.5)
        expect(display.example(2, 'passed', 1.0)).to eq('[50%100%]p')
      end
    end
  end

  describe '#summary' do
    let(:summaries) do
      [{ 'examples' => 4, 'failures' => 0, 'pending' => 0, 'duration' => 1.0, 'failed_examples' => [] }]
    end

    it 'renders the summary of the processes' do
      expect(display.summary(summaries, [])).to include('4 examples, 0 failures')
    end

    it 'warns about missing processes' do
      expect(display.summary(summaries, [2])).to include('WARNING')
    end
  end
end
