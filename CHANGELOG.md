# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Added
- `ParallelMatrixFormatter::Formatter`, an RSpec formatter for suites run with `parallel_split_test`;
  it also works with a single `rspec` process.
- One shared Matrix-style display: a progress line (time plus one percentage column per process, padded with
  random katakana "rain") and one colored status symbol per finished example.
- Orchestrator in process 1 that collects the results of all processes over a UNIX socket and, once every process
  has reported or disconnected, prints a consolidated RSpec-style summary: all failures with messages and
  backtraces, totals, wall-clock and summed process time, and `rspec ./path:line` rerun commands.
- Yellow warning naming any process that disconnected without sending a summary (for example after a crash).
- YAML configuration with defaults in `config/parallel_matrix_formatter.yml`: `suppress_output`, `digits`,
  `progress_update` (`always`, `interval_seconds`, `percent_threshold`), `progress_line` and `example_status`
  (formats, symbols, colors, column width and alignment).
- Project overrides in `config/parallel_matrix_formatter.yml` or `parallel_matrix_formatter.yml`, or in the file
  named by `PARALLEL_MATRIX_FORMATTER_CONFIG`; missing keys fall back to the defaults (deep merge).
- Output suppression (`suppress_output: true` by default): STDOUT and STDERR of every process are reopened to
  `/dev/null`, and the formatter keeps a private copy of the original stdout for the display.
- `parallel_matrix_formatter/silence` file to silence application boot output
  (`RUBYOPT="-rparallel_matrix_formatter/silence"`).
- `NO_COLOR` environment variable support.
- `demo/matrix_demo.rb` to preview the display without a test suite.
- GitHub Actions workflow running specs and RuboCop on Ruby 3.1 to 4.0.
