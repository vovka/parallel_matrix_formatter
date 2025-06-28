# frozen_string_literal: true

require_relative 'lib/parallel_matrix_formatter/version'

Gem::Specification.new do |spec|
  spec.name = 'parallel_matrix_formatter'
  spec.version = ParallelMatrixFormatter::VERSION
  spec.authors = ['Vovka']
  spec.email = ['vovka@example.com']

  spec.summary = 'Matrix Digital Rain Parallel RSpec Formatter'
  spec.description = 'A custom RSpec formatter for parallel_split_tests that displays real-time Matrix digital rain progress per process'
  spec.homepage = 'https://github.com/vovka/parallel_matrix_formatter'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'rainbow', '~> 3.0'
  spec.add_dependency 'rspec-core', '~> 3.0'
  # spec.add_dependency 'drb'

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
end
