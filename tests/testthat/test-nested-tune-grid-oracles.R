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
#
# O3 -- type "live" (reference implementation), for the evaluated-candidate
#   record rather than for the estimate (M21). Source: tune::tune_grid() itself,
#   re-run by hand on a fold's own inner resamples under that fold's
#   `.tuning_seed` with the generator kind pinned, exactly as the roxygen's
#   by-hand reproduction recipe prescribes. Pinned by "an integer grid records
#   the candidates that fold actually expanded". A tune_results carries no
#   record of its own expansion -- attributes are `parameters`, `metrics`,
#   `outcomes`, `rset_info` and nothing else (measured at M21's plan gate,
#   tune 2.1.0) -- so re-running is the only route to an independent answer.
#
# O4 -- type "invariant", the companion to O3 on the branch O3 cannot reach: a
#   data-frame grid must come back as itself, since nothing expands. Pinned in
#   test-nested-tune-grid-results.R ("each fold records the candidates its inner
#   tuning actually scored"). O3 and O4 are the two independent types covering
#   the record.
#
# OBSERVED, NOT ASSERTED (M21). On tune 2.1.0, integer-grid expansion is
# stochastic for a continuous parameter, so folds tuning under their own seeds
# search different candidate sets. Measured on the fixture the O3 test below
# builds -- cont_workflow(), grid = 5, seeds 11 and 20 -- the three outer folds
# expanded thresholds:
#
#   fold 1: 0.00059 0.24510 0.50336 0.74564 0.98373
#   fold 2: 0.03347 0.25516 0.49639 0.75686 0.99656
#   fold 3: 0.00259 0.23142 0.48026 0.74269 0.99798
#
# This is why the record is a column and not one attribute: no single value
# describes what this run searched. It is recorded rather than asserted because
# it is a property of tune's expansion, which IP2 declines to guarantee across
# tune versions -- asserting it would turn a correct package red on an upstream
# change. The O3 test below asserts the part that IS this package's contract:
# each fold's record matches what that fold ran.

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
    expect_identical(res$.metrics[[i]], ref[[i]]$metrics)
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
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
    expect_identical(res$.metrics[[i]], ref[[i]]$metrics)
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
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
      expect_identical(
        fold_res$.estimate[fold_res$.metric == m],
        fold_ref$.estimate[fold_ref$.metric == m]
      )
    }
  }
})

test_that("an integer grid records the candidates that fold actually expanded", {
  skip_if_no_engines()

  # O3. The record cannot be checked against the `grid` argument here -- that is
  # the number 5 -- so the oracle is tune itself, re-run by hand on the fold's
  # own inner resamples under the fold's own seed, the same reproduction recipe
  # the roxygen hands users.
  d <- make_reg_data()
  wf <- cont_workflow(d)
  ms <- reg_metrics()

  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(20)
  res <- nested_tune_grid(wf, folds, grid = 5, metrics = ms)
  expect_true(all(res$.completed))

  for (i in seq_len(nrow(res))) {
    set.seed(
      res$.tuning_seed[[i]],
      kind = "Mersenne-Twister", normal.kind = "Inversion",
      sample.kind = "Rejection"
    )
    tuned <- tune::tune_grid(
      wf,
      resamples = folds$inner_resamples[[i]],
      grid = 5,
      metrics = ms,
      control = tune::control_grid(allow_par = FALSE)
    )
    reference <- sort(unique(tune::collect_metrics(tuned)$threshold))
    expect_identical(sort(res$.grid[[i]]$threshold), reference)
  }
})

test_that("a grid size larger than the reachable candidates records what ran", {
  skip_if_no_engines()

  # IP4's "a truncated grid", which is the case the `grid` attribute cannot
  # describe at all: num_comp reaches at most one candidate per predictor, so a
  # request for 20 is met by however many exist and the request stands
  # unchanged beside it.
  d <- make_reg_data()

  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(20)
  res <- nested_tune_grid(det_workflow(d), folds, grid = 20L, metrics = reg_metrics())

  expect_identical(attr(res, "grid"), 20L)
  for (g in res$.grid) {
    expect_true(nrow(g) < 20L)
    expect_identical(nrow(g), 4L)
  }
})
