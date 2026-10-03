# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Support for [`parallel_tests`](https://github.com/grosser/parallel_tests) (`parallel_rspec`) next to
  `parallel_split_test`. The formatter detects the runner and takes the number of processes and the identity of
  the run from it; the README lists the `parallel_rspec` options that are not supported.

### Fixed
- The stderr of every process is written to a log file in the temporary directory instead of `/dev/null`; the
  summary lists the logs when a process is missing, an error happened outside of the examples or a log is not
  empty.
- The closing `Summary:` of `parallel_split_test` is no longer empty: every process writes its totals line to the
  stream RSpec gave its formatter, which `parallel_split_test` records.
- Process 1 no longer waits forever for a process that died before its first example: every process announces
  itself as soon as it connects. Without a pid file (`parallel_split_test`) process 1 stops waiting for a process
  that has not connected within the new `connect_timeout_seconds` setting (default 120, the timeout the processes
  already used to connect) and reports it as missing.
- Under `parallel_tests` the summary could leave out a fast process: it had already left the pid file while its
  messages were still unread. The orchestrator now also waits until every connection has been read to the end.
- Without a runner (plain `rspec`) the socket is named after the process's own pid instead of its parent's, so
  two `rspec` runs started from the same shell no longer remove each other's socket.
- `--format ParallelMatrixFormatter::Formatter` works without requiring the gem first; the formatter file now
  loads everything it needs.

### Changed
- README: documents other formatters writing to stdout, the `--out` handling of `parallel_split_test` and the
  default colors.
- The orchestrator waits for the processes that actually connected instead of trusting the announced number of
  processes. Under `parallel_tests` it also waits for every process listed in the run's pid file, so it neither
  hangs when `parallel_tests` starts fewer processes than announced nor finishes before a slow process reports.
- The socket is named after the run (the pid file under `parallel_tests`, the parent pid under `parallel_split_test`);
  `Ipc.socket_path`, `Ipc::Server.new` and `Ipc::Client.connect` take the path explicitly.

## [0.1.0] - 2026-10-03

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
- GitHub Actions workflow running specs and RuboCop on Ruby 3.2 to 4.0.
