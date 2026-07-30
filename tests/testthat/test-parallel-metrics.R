# The `metrics` argument reaches folds running on a worker (M20).
#
# Oracle note (DESIGN "Oracle records"): this file records none. It asserts
# argument delivery, not a numeric result -- the values it compares are whatever
# the same pipeline produces serially, and nothing here anchors what they should
# be. test-nested-tune-grid-oracles.R holds the contract-derived oracle.
#
# WHAT THIS FILE EXISTS FOR. `R/parallel.R` hands `metrics` to mirai through
# `mirai_map(.args = ...)`, and until M20 no test reached that delivery site.
# Every parallel test passes `reg_metrics()`, which IS tune's regression
# default (`metric_set(rmse, rsq)`), so replacing the argument with `NULL` at
# the `.args` call produced a byte-identical run and the whole suite stayed
# green. `grid` and `object` are not in that position: a wrong `grid` on the
# parallel side diverges from the serial reference and test-parallel-identity.R
# catches it. `metrics` is the one argument whose loss is invisible there.
#
# The instrument is M18's sep_* fixture (helper-orchestration.R), built so the
# caller's metric set and tune's default disagree about both the metric NAMES
# and the SELECTED candidate in all three outer folds. Losing `metrics` on the
# way to a worker therefore changes what comes back.
#
# WHAT THE SERIAL COMPARISON BELOW IS AND IS NOT. It pins argument plumbing. It
# is NOT a mode-independence (IP2) assertion, and must not be read as one: the
# sep_* path is step_pca() + linear_reg(), which draws nothing, and
# test-parallel-identity.R:11-13 records that identity comparisons on an
# RNG-free workflow pass vacuously. IP2 is asserted in that file, on ranger.
#
# TWO RNG FACTS THAT LOOK LIKE A TRAP AND ARE NOT. mirai starts every daemon on
# its own L'Ecuyer-CMRG stream (M07), and the sep_* fixture's all-three-folds
# separation collapses to 0 of 3 folds under exactly that kind (M18 review).
# They do not meet: sep_data() and sep_nested() pin the full generator triple
# host-side and hand the daemons a finished data frame and design, and
# set_fold_seed() pins all three components again inside the worker. The
# separation is a property of the host-built fixture, not of where a fold runs.
#
# WHY NOTHING HERE IS memoised(). fixture_key() hashes the call, its arguments
# and the RNG state -- and nothing about daemon state (helper-orchestration.R).
# A memoised parallel run is therefore served the serially-built value, dispatches
# nothing, and passes under the very mutation this file exists to catch. The
# last_dispatch() assertions are what make that failure loud rather than silent.

test_that("the metric set the caller gave reaches folds running on a worker", {
  skip_if_no_daemons()
  skip_if_no_engines()

  d <- sep_data()
  wf <- sep_workflow(d)
  nested <- sep_nested(d)
  metrics <- sep_metrics()
  on.exit(mirai::daemons(0), add = TRUE)

  # Built here rather than through memoised(), for the reason in the header.
  mirai::daemons(0)
  set.seed(20)
  serial <- nested_tune_grid(wf, nested, grid = sep_grid(), metrics = metrics)
  expect_identical(last_dispatch(), "serial")

  start_daemons(2)
  set.seed(20)
  parallel <- without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = sep_grid(), metrics = metrics)
  )

  # The run took the branch under test. Without this the assertions below are
  # satisfied by a serial run, and the file asserts nothing about `.args`.
  expect_identical(last_dispatch(), "parallel")

  # The names last_fit() scored on the outer assessment set. Under a lost
  # `metrics` these are tune's default pair instead, in every fold.
  expect_identical(nrow(parallel), 3L)
  for (i in seq_len(nrow(parallel))) {
    expect_identical(sort(parallel$.metrics[[i]]$.metric), c("mae", "rmse"))
  }

  # The parameters inner tuning chose. sep_* separates on selection too, so this
  # fails independently of the names above -- a `metrics` that reached
  # last_fit() but not tune_grid() would pass the loop above and fail here.
  expect_identical(parallel$.selected, serial$.selected)
  expect_identical(parallel$.metrics, serial$.metrics)
})
