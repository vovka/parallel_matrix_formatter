# frozen_string_literal: true

require_relative 'lib/parallel_matrix_formatter/version'

Gem::Specification.new do |spec|
  spec.name = 'parallel_matrix_formatter'
  spec.version = ParallelMatrixFormatter::VERSION
  spec.authors = ['Volodymyr Shcherbyna']
  spec.email = ['scherbina.v@gmail.com']

  spec.summary = 'Matrix digital rain RSpec formatter for parallel_split_test'
  spec.description = 'An RSpec formatter that renders the progress of every parallel_split_test process ' \
                     'as one Matrix-style digital rain and prints a single consolidated summary.'
  spec.homepage = 'https://github.com/vovka/parallel_matrix_formatter'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'config/*.yml', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.add_dependency 'rspec-core', '~> 3.0'
end
