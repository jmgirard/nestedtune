# What the fixture cache did, printed once the process that holds it has run
# its files.
#
# This is AC4's report (M12), and it is a `teardown-` file rather than the
# setup.R + `withr::defer(teardown_env())` shape testthat now prefers for one
# reason: that shape needs withr, and withr is not a dependency of this
# package. Teardown files are still run by `test_dir()`; they are merely no
# longer the recommended place for cleanup, and nothing here cleans anything
# up.
#
# The cache is per worker process (helper-orchestration.R). Under parallel
# test files (M52) testthat sources this file once in each worker as it shuts
# the worker down, so each report covers one worker's files; and nothing a
# worker writes to its stdout or stderr reaches the parent's, so under
# parallel files the report reaches no log at all, on either stream (M57:
# a two-file fixture with a teardown writing one line to each stream, run
# under `TESTTHAT_PARALLEL=TRUE` with both of the parent's streams redirected
# to files, left neither line in either file; serial, both arrived). It is a
# serial-run report: `TESTTHAT_PARALLEL=FALSE`, which is how
# `benchmarks/profile-tests.R` runs, prints one report for the whole suite.
# `stderr()` because it is unbuffered and is where the hang trace writes.
#
# A `builds` above 1 is the finding to act on: two cache entries produced the
# same result, so the process paid for one fit twice. Either the key separated
# requests that were the same run, or two call sites are asking for one fixture
# in two spellings.

print_fixture_cache_report(fixture_cache_report(), file = stderr())
