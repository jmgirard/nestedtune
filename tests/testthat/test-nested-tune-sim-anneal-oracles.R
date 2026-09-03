# Oracle records for nested_tune_sim_anneal() (DESIGN Conventions: oracles are
# recorded in the test file that asserts them). The numbering is this file's
# own.
#
# O1 -- type "live" (reference implementation). Source: the tidymodels and
#   finetune pipeline itself, recomputed at test time by
#   reference_nested_anneal_loop() in helper-orchestration.R, written from
#   the documented seed contract -- `set.seed(s)`, one
#   `sample.int(.Machine$integer.max, 2 * n)`, fold i annealing under element
#   2i-1 with the kind pinned and `control_sim_anneal(verbose_iter = FALSE,
#   allow_par = FALSE)`, fitting under element 2i -- and never from the
#   driver's output. Pinned by "per-fold metrics, selections and inner tables
#   match a hand-rolled annealing reference loop" on the deterministic and
#   the metric-separating fixtures. Satisfies AC1.
#
# O2 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. `tune_sim_anneal()` scores its
#   `initial` candidates as a space-filling design drawn under the fold's
#   seed and scored with `tune_grid()` (tune's `check_initial()` and
#   `create_initial_set()`, tune 2.1.0, read 2026-09-02), which is what
#   `nested_tune_grid()` does with an integer `grid` of the same size under
#   the same seed -- so the `.iter == 0` rows must carry the grid path's
#   parameter values and means. Pinned by "the initial candidates are the
#   grid path's under the same seed". Satisfies AC2.
#
# O3 -- type "invariant" (mode independence), pinned in
#   test-parallel-identity.R as BC13: the same seed gives an identical result
#   serially and at two daemon counts. Recorded here for the audit.
#
# O1 and O2 are the >=2 independent oracle types GP2 asks of the package's own
# contribution -- the call, the seed, the record, the loop -- at the initial
# stage. The iteration stage has O1 and O3 only: the perturbations are
# finetune's own search inside D-002's boundary, and no independent oracle
# for them exists here.

test_that("nested_tune_sim_anneal() carries the Bayesian sibling's formals less objective, with initial at 1 (AC1)", {
  expect_identical(
    names(formals(nested_tune_sim_anneal)),
    c(
      "object",
      "resamples",
      "...",
      "iter",
      "param_info",
      "metrics",
      "initial",
      "event_level",
      "eval_time"
    )
  )
  expect_identical(formals(nested_tune_sim_anneal)$iter, 10)
  expect_identical(formals(nested_tune_sim_anneal)$initial, 1)
  expect_identical(
    formals(nested_tune_sim_anneal)[c(
      "object",
      "resamples",
      "iter",
      "param_info",
      "metrics",
      "event_level",
      "eval_time"
    )],
    formals(nested_tune_bayes)[c(
      "object",
      "resamples",
      "iter",
      "param_info",
      "metrics",
      "event_level",
      "eval_time"
    )]
  )
})

expect_matches_reference <- function(res, ref) {
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
      tune::collect_metrics(ref[[i]]$tuned)
    )
    expect_s3_class(ref[[i]]$tuned, "iteration_results")
  }
  invisible(res)
}

# `.iter` on the fold record (AC1): 0 on the initial candidates, whose labels
# finetune prefixes `initial_`, and the iteration number on the rest.
expect_iter_column <- function(tbl, initial) {
  expect_true(".iter" %in% names(tbl))
  expect_identical(
    which(names(tbl) == ".iter"),
    which(names(tbl) == ".config") + 1L
  )
  expect_type(tbl$.iter, "integer")
  first <- startsWith(tbl$.config, "initial_")
  expect_identical(tbl$.iter[first], rep(0L, sum(first)))
  expect_true(all(tbl$.iter[!first] > 0L))
  expect_identical(length(unique(tbl$.config[first])), initial)
}

test_that("per-fold metrics, selections and inner tables match a hand-rolled annealing reference loop (AC1, deterministic)", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ms <- reg_metrics()

  res <- anneal_results()
  ref <- reference_nested_anneal_loop(
    wf,
    folds,
    iter = 2,
    initial = 3,
    metrics = ms,
    seed = 20,
    metric_name = "rmse",
    control = anneal_control()
  )
  expect_matches_reference(res, ref)
  expect_identical(attr(res, "procedure")$tuner, "tune_sim_anneal")
  expect_identical(attr(res, "procedure")$iter, 2)
  expect_identical(attr(res, "procedure")$initial, 3)
  expect_null(attr(res, "grid"))

  for (i in seq_len(nrow(res))) {
    expect_iter_column(res$.inner_metrics[[i]], initial = 3L)
  }
  # The search ran: some fold scored an iteration. Without this the reference
  # could agree with a driver that never iterated.
  expect_true(any(vapply(
    res$.inner_metrics,
    function(m) any(m$.iter > 0L),
    logical(1)
  )))
})

test_that("the annealing reference loop also matches on the metric-separating fixture (AC1)", {
  skip_if_no_anneal_fixture()

  d <- sep_data()
  wf <- sep_workflow(d)
  folds <- sep_nested(d)
  ms <- sep_metrics()
  ctrl <- anneal_control()

  set.seed(23)
  res <- nested_tune_sim_anneal(
    wf,
    folds,
    iter = 2,
    initial = 2,
    metrics = ms,
    control = ctrl
  )
  ref <- reference_nested_anneal_loop(
    wf,
    folds,
    iter = 2,
    initial = 2,
    metrics = ms,
    seed = 23,
    metric_name = "mae",
    control = ctrl
  )
  expect_matches_reference(res, ref)
  # The metric set reached the search: the outer metrics are the set's, and
  # selection was under its first metric.
  expect_setequal(res$.metrics[[1L]]$.metric, c("mae", "rmse"))
  for (i in seq_len(nrow(res))) {
    expect_iter_column(res$.inner_metrics[[i]], initial = 2L)
  }
})

test_that("the initial candidates are the grid path's under the same seed (AC2)", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ms <- reg_metrics()

  # The grid path handed an integer grid of the initial count, under the same
  # entry seed: tune draws the same space-filling design inside each fold's
  # seed scope.
  set.seed(20)
  grid <- memoised(nested_tune_grid(wf, folds, grid = 3, metrics = ms))
  expect_true(all(grid$.completed))

  res <- anneal_results()
  expect_identical(res$.tuning_seed, grid$.tuning_seed)

  for (i in seq_len(nrow(res))) {
    initial <- res$.inner_metrics[[i]]
    initial <- initial[initial$.iter == 0L, ]
    by_grid <- grid$.inner_metrics[[i]]
    # The same candidates, and every grid candidate among them.
    expect_setequal(unique(initial$num_comp), unique(by_grid$num_comp))
    expect_identical(nrow(initial), nrow(by_grid))
    for (r in seq_len(nrow(initial))) {
      match <- by_grid$num_comp == initial$num_comp[[r]] &
        by_grid$.metric == initial$.metric[[r]]
      expect_identical(sum(match), 1L)
      expect_identical(initial$mean[[r]], by_grid$mean[[which(match)]])
    }
  }
})

test_that("a fold that scored nothing carries .iter on its zero-row table (AC1)", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(20)
  res <- suppressWarnings(memoised(nested_tune_sim_anneal(
    wf,
    nested,
    iter = 2,
    initial = 3,
    metrics = reg_metrics(),
    control = anneal_control()
  )))

  expect_false(res$.completed[[2L]])
  expect_true(res$.completed[[1L]])
  none <- res$.inner_metrics[[2L]]
  done <- res$.inner_metrics[[1L]]
  expect_identical(nrow(none), 0L)
  expect_true(".iter" %in% names(none))
  expect_identical(names(none), names(done))
  expect_identical(
    vapply(none, function(col) class(col)[[1L]], character(1)),
    vapply(done, function(col) class(col)[[1L]], character(1))
  )
})

test_that("the help page's by-hand recipe reproduces a fold's inner table and selection (AC4)", {
  skip_if_no_anneal_fixture()

  # Written from the Reproducibility section of ?nested_tune_sim_anneal, line
  # for line: the fold's tuning seed with the kind pinned, the recorded
  # control, the search on the fold's inner rset, then `select_best()`.
  d <- make_reg_data()
  object <- det_workflow(d)
  resamples <- det_nested(d)
  metrics <- reg_metrics()

  res <- anneal_results()
  procedure <- attr(res, "procedure")
  i <- 2L

  set.seed(
    res$.tuning_seed[[i]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  control <- procedure$control
  tuned <- finetune::tune_sim_anneal(
    object,
    resamples$inner_resamples[[i]],
    iter = procedure$iter,
    initial = procedure$initial,
    param_info = procedure$param_info,
    metrics = metrics,
    eval_time = procedure$eval_time,
    control = control
  )
  expect_identical(res$.inner_metrics[[i]], tune::collect_metrics(tuned))
  expect_identical(
    res$.selected[[i]],
    tune::select_best(tuned, metric = "rmse")
  )
})
