# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::Colors do
  before { stub_const('ENV', ENV.to_h.except('NO_COLOR')) }

  describe '.wrap' do
    it 'wraps the text in the ANSI code of a named color' do
      expect(described_class.wrap('hi', :red)).to eq("\e[31mhi\e[0m")
    end

    it 'accepts the color name as a string' do
      expect(described_class.wrap('hi', 'green')).to eq("\e[32mhi\e[0m")
    end

    it 'accepts the semantic color names of RSpec' do
      expect(described_class.wrap('hi', :failure)).to eq("\e[31mhi\e[0m")
    end

    it 'returns the plain text when the color is nil' do
      expect(described_class.wrap('hi', nil)).to eq('hi')
    end

    it 'returns an empty string for empty text' do
      expect(described_class.wrap('', :red)).to eq('')
    end

    it 'converts non-string text' do
      expect(described_class.wrap(42, nil)).to eq('42')
    end

    context 'when NO_COLOR is set' do
      before { stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '1')) }

      it 'returns the plain text' do
        expect(described_class.wrap('hi', :red)).to eq('hi')
      end
    end

    context 'when NO_COLOR is empty' do
      before { stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '')) }

      it 'still colors the text' do
        expect(described_class.wrap('hi', :red)).to eq("\e[31mhi\e[0m")
      end
    end
  end
end
