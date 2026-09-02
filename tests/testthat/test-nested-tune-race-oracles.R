# Oracle records for the two racing exports (DESIGN Conventions: oracles are
# recorded in the test file that asserts them). The numbering is this file's
# own.
#
# O1 -- type "live" (reference implementation). Source: the tidymodels and
#   finetune pipeline itself, recomputed at test time by
#   reference_nested_race_loop() in helper-orchestration.R, written from the
#   documented seed contract -- `set.seed(s)`, one
#   `sample.int(.Machine$integer.max, 2 * n)`, fold i racing under element
#   2i-1 with the kind pinned and `control_race(burn_in = 2, allow_par =
#   FALSE)`, fitting under element 2i -- and never from the driver's output.
#   Pinned by "per-fold metrics, selections and inner tables match a
#   hand-rolled racing reference loop" on the deterministic and the
#   metric-separating fixtures, for each racer. Satisfies AC1.
#
# O2 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. A candidate a race scored on
#   every inner resample was scored on exactly the resamples `tune_grid()`
#   scores it on, so its `mean` must equal the grid orchestrator's for the
#   same candidate under the same seed and the same explicit grid; the race
#   shuffles the resample order, and the means agreed to the last bit on
#   every fold of the fixture under two seeds (measured 2026-09-02, finetune
#   1.3.0). Pinned by "a candidate raced to the end carries the grid path's
#   mean". Satisfies AC2.
#
# O3 -- type "live", on the record's derivation (D-043, IP4): a fold's
#   `.inner_metrics` is `collect_metrics(<the race>, all_configs = TRUE)`,
#   eliminated candidates included, and `.selected` is `select_best()` on the
#   race; on the stochastic fixture a race eliminates at least one candidate,
#   so a table with a candidate at `n` below the resample count is shown, and
#   the selection is a candidate raced to the end. Pinned by "the fold record
#   is every candidate the race scored, and the selection a survivor".
#   Satisfies AC3.
#
# O4 -- type "invariant" (mode independence), pinned in
#   test-parallel-identity.R as BC12: the same seed gives an identical result
#   serially and at two daemon counts. Recorded here for the audit.
#
# O1 and O2 are the >=2 independent oracle types GP2 asks of the package's own
# contribution -- the call, the seed, the record, the loop. The elimination
# itself is finetune's, inside D-002's boundary, and no independent oracle for
# it exists here.

test_that("the racing exports carry nested_tune_grid()'s formals, defaults and order (AC1)", {
  expect_identical(
    formals(nested_tune_race_anova),
    formals(nested_tune_grid)
  )
  expect_identical(
    formals(nested_tune_race_win_loss),
    formals(nested_tune_grid)
  )
  expect_identical(
    names(formals(nested_tune_grid)),
    c(
      "object",
      "resamples",
      "...",
      "param_info",
      "grid",
      "metrics",
      "event_level",
      "eval_time"
    )
  )
})

expect_matches_reference <- function(res, ref, metric_name) {
  expect_true(all(res$.completed))
  # The seeds the driver reports must be the ones the documented contract
  # derives -- checked before the metrics, because a driver that both
  # misassigns and misreports could otherwise agree with a loop fed its own
  # numbers.
  expect_identical(res$.tuning_seed, ref_field(ref, "tuning_seed"))
  expect_identical(res$.outer_fit_seed, ref_field(ref, "outer_fit_seed"))
  for (i in seq_len(nrow(res))) {
    expect_identical(res$.metrics[[i]], ref[[i]]$metrics)
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
    expect_identical(
      res$.inner_metrics[[i]],
      tune::collect_metrics(ref[[i]]$tuned, all_configs = TRUE)
    )
  }
  invisible(res)
}

test_that("per-fold metrics, selections and inner tables match a hand-rolled racing reference loop (AC1, deterministic)", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ms <- reg_metrics()

  for (fn in RACERS) {
    res <- race_results(fn)
    ref <- reference_nested_race_loop(
      fn,
      wf,
      folds,
      grid = det_grid(),
      metrics = ms,
      seed = 20,
      metric_name = "rmse",
      control = race_control()
    )
    expect_matches_reference(res, ref, "rmse")
    expect_identical(attr(res, "procedure")$tuner, fn)
  }
})

test_that("the racing reference loop also matches on the metric-separating fixture (AC1)", {
  skip_if_no_race_fixture()

  d <- sep_data()
  wf <- sep_workflow(d)
  folds <- sep_nested(d)
  ms <- sep_metrics()
  ctrl <- race_control()

  for (fn in RACERS) {
    set.seed(23)
    res <- race_call_by_name(fn, wf, folds, grid = sep_grid(), metrics = ms, control = ctrl)
    ref <- reference_nested_race_loop(
      fn,
      wf,
      folds,
      grid = sep_grid(),
      metrics = ms,
      seed = 23,
      metric_name = "mae",
      control = ctrl
    )
    expect_matches_reference(res, ref, "mae")
    # The metric set reached the race: the outer metrics are the set's.
    expect_setequal(res$.metrics[[1L]]$.metric, c("mae", "rmse"))
  }
})

test_that("a candidate raced to the end carries the grid path's mean (AC2)", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  g <- det_grid()
  ms <- reg_metrics()

  # The grid path under the same seed and the same explicit grid, the
  # suite's shared run.
  set.seed(20)
  grid <- memoised(nested_tune_grid(wf, folds, grid = g, metrics = ms))
  expect_true(all(grid$.completed))

  for (fn in RACERS) {
    res <- race_results(fn)
    expect_identical(res$.tuning_seed, grid$.tuning_seed)

    for (i in seq_len(nrow(res))) {
      raced <- res$.inner_metrics[[i]]
      full <- raced[raced$n == 3L, ]
      # At least one candidate in every fold was scored on all 3 inner
      # resamples; without this the identity below could hold vacuously.
      expect_gt(nrow(full), 0L)
      by_grid <- grid$.inner_metrics[[i]]
      for (r in seq_len(nrow(full))) {
        match <- by_grid$num_comp == full$num_comp[[r]] &
          by_grid$.metric == full$.metric[[r]]
        expect_identical(sum(match), 1L)
        expect_identical(full$mean[[r]], by_grid$mean[[which(match)]])
        expect_identical(by_grid$n[[which(match)]], 3L)
      }
    }
  }
})

test_that("the fold record is every candidate the race scored, and the selection a survivor (AC3)", {
  skip_if_no_race_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  folds <- det_nested(d)
  ms <- reg_metrics()
  ctrl <- race_control()

  for (fn in RACERS) {
    set.seed(24)
    res <- race_call_by_name(fn, wf, folds, grid = stoch_grid(), metrics = ms, control = ctrl)
    ref <- reference_nested_race_loop(
      fn,
      wf,
      folds,
      grid = stoch_grid(),
      metrics = ms,
      seed = 24,
      metric_name = "rmse",
      control = ctrl
    )
    expect_matches_reference(res, ref, "rmse")

    eliminated <- 0L
    for (i in seq_len(nrow(res))) {
      raced <- ref[[i]]$tuned
      expect_s3_class(raced, "tune_race")
      # The record: every candidate scored, not finetune's survivors alone.
      expect_identical(
        res$.inner_metrics[[i]],
        tune::collect_metrics(raced, all_configs = TRUE)
      )
      expect_identical(res$.selected[[i]], tune::select_best(raced, metric = "rmse"))

      tbl <- res$.inner_metrics[[i]]
      n_max <- nrow(folds$inner_resamples[[i]])
      eliminated <- eliminated + sum(tbl$n < n_max)
      # The selection is a candidate raced to the end.
      sel <- tbl[tbl$.config == res$.selected[[i]]$.config, ]
      expect_gt(nrow(sel), 0L)
      expect_true(all(sel$n == n_max))
    }
    # Some candidate was eliminated somewhere: the record holds a row with
    # `n` below the resample count, which the survivors-only default would
    # have dropped.
    expect_gt(eliminated, 0L)
  }
})

test_that("the help page's by-hand recipe reproduces a fold's inner table and selection (AC4)", {
  skip_if_no_race_fixture()

  # Written from the Reproducibility section of ?nested_tune_race, line for
  # line: the fold's tuning seed with the kind pinned, the recorded control,
  # the race on the fold's inner rset, then `select_best()`.
  d <- make_reg_data()
  object <- det_workflow(d)
  resamples <- det_nested(d)
  metrics <- reg_metrics()

  for (fn in RACERS) {
    res <- race_results(fn)
    racer <- getExportedValue("finetune", fn)
    grid <- attr(res, "procedure")$grid
    param_info <- attr(res, "procedure")$param_info
    eval_time <- attr(res, "procedure")$eval_time
    i <- 2L

    set.seed(
      res$.tuning_seed[[i]],
      kind = "Mersenne-Twister",
      normal.kind = "Inversion",
      sample.kind = "Rejection"
    )
    control <- attr(res, "procedure")$control
    raced <- racer(
      object,
      resamples$inner_resamples[[i]],
      grid = grid,
      param_info = param_info,
      metrics = metrics,
      eval_time = eval_time,
      control = control
    )
    expect_identical(
      res$.inner_metrics[[i]],
      tune::collect_metrics(raced, all_configs = TRUE)
    )
    expect_identical(
      res$.selected[[i]],
      tune::select_best(raced, metric = "rmse")
    )
  }
})
