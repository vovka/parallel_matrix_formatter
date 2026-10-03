# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::ExampleStatus do
  subject(:status) { described_class.new(config) }

  before { stub_const('ENV', ENV.to_h.reject { |key, _| key == 'NO_COLOR' }) }

  let(:config) do
    { 'format' => '{symbol}',
      'symbols' => { 'passed' => 'p', 'failed' => 'f', 'pending' => 'z' },
      'colors' => { 'passed' => 'green', 'failed' => 'red', 'pending' => 'yellow' } }
  end

  describe '#render' do
    it 'uses the symbol of the status in its color' do
      expect(status.render(1, 'passed')).to eq("\e[32mp\e[0m")
    end

    it 'uses the color of a failure' do
      expect(status.render(1, 'failed')).to eq("\e[31mf\e[0m")
    end

    it 'uses the color of a pending example' do
      expect(status.render(1, 'pending')).to eq("\e[33mz\e[0m")
    end

    it 'picks one character of the configured symbols' do
      config['symbols']['passed'] = 'abc'
      expect(%w[a b c]).to include(status.render(1, 'passed')[/[abc]/])
    end

    context 'when the format has a process letter' do
      let(:config) { super().merge('format' => '{process_letter}{symbol}') }

      it 'names process 1 A' do
        expect(status.render(1, 'passed')).to eq("\e[32mAp\e[0m")
      end

      it 'names process 3 C' do
        expect(status.render(3, 'passed')).to eq("\e[32mCp\e[0m")
      end
    end

    context 'when no color is configured for the status' do
      before { config['colors'].delete('passed') }

      it 'renders the plain symbol' do
        expect(status.render(1, 'passed')).to eq('p')
      end
    end
  end
end
