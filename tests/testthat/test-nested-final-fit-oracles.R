# Oracle records for nested_final_fit() (DESIGN Conventions: oracles are
# recorded in the test file that asserts them).
#
# O3 -- type "live" (reference implementation). Source: the tidymodels pipeline
#   itself, recomputed at test time by reference_final_fit() in
#   helper-orchestration.R, which is written from the documented seed contract
#   (D-011, D-016) and never from the returned object -- it derives its own
#   seeds, builds its own inner rset under the first of them, and spells out the
#   inner specification rather than reading the design's. Pinned by "the final
#   fit matches a hand-rolled reference pipeline". Satisfies AC2/AC9.
#
# O4 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. With a single-candidate grid
#   there is nothing to select, so the tuning stage cannot influence the result
#   and the final fit must equal a direct fit of the workflow finalized on that
#   one candidate. Pinned by "a single-candidate grid degenerates to a direct
#   fit". Satisfies AC2. Deterministic engine, so the equality is exact rather
#   than seed-contingent (D-013).
#
# O5 -- type "live" (independent reference implementation), the third strand
#   RR02 recommended. Source: tune's own fit_best(), tidymodels' separately
#   written "select, finalize, and fit on everything" path -- code neither this
#   package nor this test author wrote. Pinned by "the final fit matches
#   tune::fit_best() on the same tuning run". Needs save_workflow = TRUE on the
#   test's own tune_grid() call, which is why reference_final_fit() sets it.
#
# O3 and O4 are the >=2 independent oracle types GP2 requires; O5 reduces the
# exposure the first two share by routing the finalize-and-fit tail through
# upstream code.

test_that("the final fit matches a hand-rolled reference pipeline", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(99)
  final <- nested_final_fit(wf, res)

  ref <- reference_final_fit(
    wf,
    d,
    attr(res, "procedure")$grid,
    attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse"
  )

  # The seed layout itself, derived independently from the documented contract.
  expect_identical(c(final$tuning_seed, final$fit_seed), ref$seeds)
  expect_identical(final$selected, ref$selected)

  # The resamples the tuning run actually saw, which is what pins D-016's
  # ordering. Asserting only on the selection and the predictions does not:
  # verified by inversion -- moving the rset construction outside the tuning
  # seed's scope leaves both of those unchanged whenever the selection happens
  # to be stable across the two fold sets, and it was for this fixture. The
  # folds themselves differ immediately.
  expect_identical(
    lapply(final$tuning$splits, function(s) s$in_id),
    lapply(ref$tuned$splits, function(s) s$in_id)
  )

  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(ref$workflow, new_data = d)
  )
})

test_that("a single-candidate grid degenerates to a direct fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  one <- data.frame(num_comp = 2L)
  res <- final_results(d, grid = one)

  set.seed(5)
  final <- nested_final_fit(wf, res)

  # Nothing to select, so the tuning stage cannot have influenced anything: the
  # result must be the workflow finalized on that candidate and fitted on all
  # the data. The engine is deterministic, so no seed enters the comparison.
  direct <- parsnip::fit(tune::finalize_workflow(wf, one), data = d)

  expect_identical(final$selected$num_comp, one$num_comp)
  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(direct, new_data = d)
  )
})

test_that("the final fit matches tune::fit_best() on the same tuning run", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(99)
  final <- nested_final_fit(wf, res)

  ref <- reference_final_fit(
    wf,
    d,
    attr(res, "procedure")$grid,
    attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse"
  )

  # The tail routed through upstream's own implementation rather than ours:
  # fit_best() selects, finalizes, and fits on the full training set itself.
  set.seed(
    ref$seeds[[2L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  best_fit <- tune::fit_best(ref$tuned, metric = "rmse")

  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(best_fit, new_data = d)
  )
})
