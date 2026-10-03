# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::ProgressColumn do
  subject(:column) { described_class.new(config, digits) }

  before { stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '1')) }

  let(:config) { { 'width' => 8, 'align' => 'center', 'pad_symbols' => '.' } }
  let(:digits) { '' }

  describe '#render' do
    it 'shows the rounded percentage' do
      expect(column.render(0.894)).to include('89%')
    end

    it 'pads to the configured width' do
      expect(column.render(0.5).length).to eq(8)
    end

    it 'centers the percentage' do
      expect(column.render(0.5)).to eq('..50%...')
    end

    context 'when aligned left' do
      let(:config) { super().merge('align' => 'left') }

      it 'pads on the right' do
        expect(column.render(0.5)).to eq('50%.....')
      end
    end

    context 'when aligned right' do
      let(:config) { super().merge('align' => 'right') }

      it 'pads on the left' do
        expect(column.render(0.5)).to eq('.....50%')
      end
    end

    context 'when the percentage is wider than the column' do
      let(:config) { super().merge('width' => 2) }

      it 'is not truncated' do
        expect(column.render(1.0)).to eq('100%')
      end
    end

    context 'when there are no pad symbols' do
      let(:config) { super().merge('pad_symbols' => '') }

      it 'pads with spaces' do
        expect(column.render(0.5)).to eq('  50%   ')
      end
    end

    context 'when digits are replaced' do
      let(:digits) { 'abcdefghij' }

      it 'shows the replacement digits' do
        expect(column.render(0.89)).to include('ij%')
      end
    end

    context 'when colors are configured' do
      before { stub_const('ENV', ENV.to_h.reject { |key, _| key == 'NO_COLOR' }) }

      let(:config) { super().merge('color' => 'red', 'pad_color' => 'green') }

      it 'colors the percentage and the padding separately' do
        expect(column.render(0.5)).to eq("\e[32m..\e[0m\e[31m50%\e[0m\e[32m...\e[0m")
      end
    end
  end
end
