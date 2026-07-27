# Nothing the suite started may outlive it.
#
# M14 T4 / AC4. Every daemon-using test pairs its pool with
# `on.exit(mirai::daemons(0), add = TRUE)`, so in a green run this finds
# nothing -- which is the point. It is a backstop against the runs that are not
# green: `test-parallel-classify.R`'s busy-pool test asserts an elapsed bound,
# and testthat 3e aborts the block when that assertion fails, so the
# `stop_mirai()` after it never runs and the pool is torn down with a live task
# still outstanding. A leaked pool is not a cosmetic problem here; a daemon
# carrying state from one test into the next is exactly what the parallel
# identity tests exist to rule out.
#
# The `zz` in the name is load-bearing: testthat sources teardown files in
# alphabetical order, and this one errors when it finds something. Erroring
# ahead of `teardown-fixture-cache.R` would suppress that report, so this sorts
# last deliberately.
#
# Two honest limits, stated so a green suite is not over-read. The failure
# arrives as a bare error after testthat's summary rather than as a reported
# test failure -- teardown files have no reporter. And it cannot fire at all in
# the case M14 exists for: a test file that hangs never reaches teardown. This
# catches what a finished-but-messy run leaves behind, not what a wedged one
# does.

if (requireNamespace("mirai", quietly = TRUE)) {
  connections <- mirai::status()$connections
  if (!is.null(connections) && connections > 0L) {
    mirai::daemons(0)
    stop(
      "the suite finished with ", connections,
      " mirai daemon connection(s) still up: a test left its pool behind, ",
      "and the pool has now been torn down so later runs are not affected. ",
      "Find the test that did not pair its pool with ",
      "on.exit(mirai::daemons(0), add = TRUE), or whose assertion failed ",
      "before its own cleanup ran.",
      call. = FALSE
    )
  }
}
