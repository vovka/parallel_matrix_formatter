# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'tmpdir'

RSpec.describe ParallelMatrixFormatter::Config do
  let(:defaults) { YAML.safe_load(File.read(described_class::DEFAULTS_PATH)) }

  def write_yaml(content)
    file = Tempfile.new(['config', '.yml'])
    file.write(content)
    file.close
    file
  end

  describe '.load' do
    subject(:config) { described_class.load(file.path) }

    let(:file) { write_yaml("digits: '0123456789'\nprogress_update:\n  always: true\n") }

    after { file.unlink }

    it 'overrides a top-level default' do
      expect(config['digits']).to eq('0123456789')
    end

    it 'overrides a nested default' do
      expect(config['progress_update']['always']).to be(true)
    end

    it 'keeps the sibling keys of an overridden nested default' do
      expect(config['progress_update']['interval_seconds']).to eq(60)
    end

    it 'keeps the defaults of untouched sections' do
      expect(config['example_status']).to eq(defaults['example_status'])
    end

    context 'when the project file is empty' do
      let(:file) { write_yaml('') }

      it 'returns the defaults' do
        expect(config).to eq(defaults)
      end
    end

    context 'when there is no project file' do
      it 'returns the defaults' do
        expect(described_class.load(nil)).to eq(defaults)
      end
    end
  end

  describe '.project_path' do
    context 'when PARALLEL_MATRIX_FORMATTER_CONFIG is set' do
      before { stub_const('ENV', ENV.to_h.merge('PARALLEL_MATRIX_FORMATTER_CONFIG' => '/some/config.yml')) }

      it 'returns that path' do
        expect(described_class.project_path).to eq('/some/config.yml')
      end
    end

    context 'when PARALLEL_MATRIX_FORMATTER_CONFIG is not set' do
      before { stub_const('ENV', ENV.to_h.reject { |key, _| key == 'PARALLEL_MATRIX_FORMATTER_CONFIG' }) }

      it 'returns nil without a project file in the working directory' do
        Dir.mktmpdir { |dir| Dir.chdir(dir) { expect(described_class.project_path).to be_nil } }
      end

      it 'finds config/parallel_matrix_formatter.yml' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            FileUtils.mkdir('config')
            File.write('config/parallel_matrix_formatter.yml', '')
            expect(described_class.project_path).to eq('config/parallel_matrix_formatter.yml')
          end
        end
      end
    end
  end

  describe '.deep_merge' do
    subject(:merged) { described_class.deep_merge({ 'a' => { 'b' => 1, 'c' => 2 }, 'd' => 3 }, overrides) }

    let(:overrides) { { 'a' => { 'b' => 9 }, 'e' => 5 } }

    it 'merges nested hashes' do
      expect(merged['a']).to eq('b' => 9, 'c' => 2)
    end

    it 'keeps keys only the base has' do
      expect(merged['d']).to eq(3)
    end

    it 'adds keys only the overrides have' do
      expect(merged['e']).to eq(5)
    end

    context 'when an override replaces a hash with a scalar' do
      let(:overrides) { { 'a' => 1 } }

      it 'uses the scalar' do
        expect(merged['a']).to eq(1)
      end
    end
  end
end
