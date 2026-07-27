# What the suite-level fixture cache did, printed once the whole suite has run.
#
# This is AC4's report, and it is a `teardown-` file rather than the setup.R +
# `withr::defer(teardown_env())` shape testthat now prefers for one reason: that
# shape needs withr, and withr is not a dependency of this package. Adding one
# to print a table is not a trade worth making. Teardown files are still run by
# `test_dir()`; they are merely no longer the recommended place for cleanup, and
# nothing here cleans anything up.
#
# A `builds` above 1 is the finding to act on: two cache entries produced the
# same result, so the suite paid for one fit twice. Either the key separated
# requests that were the same run, or two call sites are asking for one fixture
# in two spellings.

report <- fixture_cache_report()

if (nrow(report) > 0L) {
  cat(sprintf(
    "\nfixture cache: %d signatures, %d builds, %d requests\n",
    nrow(report), sum(report$builds), sum(report$requests)
  ))
  cat(sprintf("%7s %9s  %s\n", "builds", "requests", "signature"))
  for (i in seq_len(nrow(report))) {
    cat(sprintf(
      "%7d %9d  %s\n",
      report$builds[[i]], report$requests[[i]],
      substr(report$signature[[i]], 1L, 96L)
    ))
  }
  rebuilt <- report[report$builds > 1L, , drop = FALSE]
  if (nrow(rebuilt) > 0L) {
    cat(sprintf(
      "WARNING: %d fixture(s) built more than once -- the same fit was paid for twice\n",
      nrow(rebuilt)
    ))
  }
}
