# Oracle records for nested_tune_grid() (DESIGN Conventions: oracles are
# recorded in the test file that asserts them).
#
# O1 -- type "live" (reference implementation). Source: the tidymodels pipeline
#   itself, recomputed at test time by reference_nested_loop() in
#   helper-orchestration.R, which is written from the documented seed contract
#   rather than from the driver. Pinned by "per-fold metrics and selections
#   match a hand-rolled reference loop" (deterministic and stochastic variants).
#   Satisfies AC2/AC16.
#
# O2 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. With a single-candidate grid
#   there is nothing to select, so nested CV must degenerate to ordinary CV and
#   per-fold metrics must equal tune::fit_resamples() on the same outer rset.
#   Pinned by "a single-candidate grid degenerates to fit_resamples()".
#   Satisfies AC3/AC17. Deterministic engine only, per RR01 B2: matching
#   fit_resamples() with a stochastic engine would require replicating tune's
#   internal substream derivation.
#
# O1 and O2 are the >=2 independent oracle types GP2 requires for the nested
# estimate.

test_that("per-fold metrics and selections match a hand-rolled reference loop", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  ms <- reg_metrics()
  grid <- det_grid()

  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(20)
  res <- nested_tune_grid(wf, folds, grid = grid, metrics = ms)

  ref <- reference_nested_loop(wf, folds, grid, ms, seed = 20,
                               metric_name = "rmse")

  # The seeds the driver reports must be the ones the documented contract
  # derives -- checked before the metrics, because a driver that both
  # misassigns and misreports could otherwise agree with a loop fed its own
  # numbers (AC16).
  expect_identical(res$.tuning_seed, ref_field(ref, "tuning_seed"))
  expect_identical(res$.outer_fit_seed, ref_field(ref, "outer_fit_seed"))

  for (i in seq_len(nrow(res))) {
    expect_equal(res$.metrics[[i]], ref[[i]]$metrics)
    expect_equal(res$.selected[[i]], ref[[i]]$selected)
  }
})

test_that("the reference loop also matches with a stochastic engine", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  ms <- reg_metrics()
  grid <- stoch_grid()

  set.seed(12)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(21)
  res <- nested_tune_grid(wf, folds, grid = grid, metrics = ms)

  ref <- reference_nested_loop(wf, folds, grid, ms, seed = 21,
                               metric_name = "rmse")

  expect_identical(res$.tuning_seed, ref_field(ref, "tuning_seed"))
  expect_identical(res$.outer_fit_seed, ref_field(ref, "outer_fit_seed"))

  for (i in seq_len(nrow(res))) {
    expect_equal(res$.metrics[[i]], ref[[i]]$metrics)
    expect_equal(res$.selected[[i]], ref[[i]]$selected)
  }
})

test_that("a single-candidate grid degenerates to fit_resamples()", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  ms <- reg_metrics()
  grid <- data.frame(num_comp = 2L)

  set.seed(13)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
  # The same call under the same seed nested_resamples() makes internally, so
  # the outer splits are identical without reading them off the nested object.
  set.seed(13)
  outer <- rsample::vfold_cv(d, v = 3)

  set.seed(30)
  res <- nested_tune_grid(wf, folds, grid = grid, metrics = ms)

  plain <- tune::fit_resamples(
    tune::finalize_workflow(wf, grid),
    resamples = outer,
    metrics = ms,
    control = tune::control_resamples(allow_par = FALSE)
  )
  plain_metrics <- tune::collect_metrics(plain, summarize = FALSE)

  expect_identical(res$id, outer$id)
  for (i in seq_len(nrow(res))) {
    fold_ref <- plain_metrics[plain_metrics$id == outer$id[[i]], ]
    fold_res <- res$.metrics[[i]]
    for (m in fold_ref$.metric) {
      expect_equal(
        fold_res$.estimate[fold_res$.metric == m],
        fold_ref$.estimate[fold_ref$.metric == m]
      )
    }
  }
})
