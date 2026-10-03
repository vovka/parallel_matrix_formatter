# frozen_string_literal: true

# The formatter as released on RubyGems. `rake spec` renders the suite with it
# instead of the code under test, so a bug under test cannot garble or hide the
# report of its own specs. Both define ParallelMatrixFormatter, so the release
# is loaded aside and renamed to ReleasedMatrixFormatter.
module ReleasedFormatter
  VERSION = '0.1.0'
  INSTALL_DIR = File.expand_path("../../tmp/released_formatter/#{VERSION}", __dir__)
  ENTRY = File.join(INSTALL_DIR, 'gems', "parallel_matrix_formatter-#{VERSION}", 'lib', 'parallel_matrix_formatter.rb')

  module_function

  def install_command
    ['gem', 'install', 'parallel_matrix_formatter', '--version', VERSION, '--install-dir', INSTALL_DIR,
     '--ignore-dependencies', '--no-document']
  end

  def load
    under_test = Object.send(:remove_const, :ParallelMatrixFormatter) if defined?(ParallelMatrixFormatter)
    require ENTRY
    Object.const_set(:ReleasedMatrixFormatter, Object.send(:remove_const, :ParallelMatrixFormatter))
    Object.const_set(:ParallelMatrixFormatter, under_test) if under_test
  end
end
