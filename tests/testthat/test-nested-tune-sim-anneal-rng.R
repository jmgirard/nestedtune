# IP2 for the annealing path (M51 AC4). The properties
# test-nested-tune-grid-rng.R holds the grid path to, asserted on
# nested_tune_sim_anneal(). Every test that could pass vacuously under a
# deterministic engine uses ranger, whose fits draw from R's RNG; the search
# itself draws too -- the initial design and every perturbation come from the
# stream the fold's tuning seed started -- which is why even the deterministic
# fixture's record depends on the seed.

anneal_tuner <- function() tuner_anneal(iter = 2, initial = 3)

anneal_run <- function(wf, folds, p, ms, ctrl = anneal_control()) {
  nested_tune_sim_anneal(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms,
    control = ctrl
  )
}

test_that("the same seed produces the same result", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  p <- bayes_stoch_param_info(wf)
  ms <- reg_metrics()

  set.seed(3)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(77)
  first <- anneal_run(wf, folds, p, ms)
  set.seed(77)
  second <- anneal_run(wf, folds, p, ms)

  expect_identical(first$.metrics, second$.metrics)
  expect_identical(first$.selected, second$.selected)
  expect_identical(first$.inner_metrics, second$.inner_metrics)
  expect_identical(first$.tuning_seed, second$.tuning_seed)
  expect_identical(first, second)
})

test_that("a different seed produces different inner tables", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  p <- bayes_stoch_param_info(wf)
  ms <- reg_metrics()

  set.seed(3)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(77)
  first <- anneal_run(wf, folds, p, ms)
  set.seed(78)
  other <- anneal_run(wf, folds, p, ms)

  # Without this the same-seed test above would pass for a driver that
  # ignored the seed entirely.
  expect_false(identical(first$.tuning_seed, other$.tuning_seed))
  expect_false(identical(first$.inner_metrics, other$.inner_metrics))
  expect_false(identical(first$.metrics, other$.metrics))
})

test_that("fold results do not depend on the order folds are run in", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  p <- bayes_stoch_param_info(wf)
  ms <- reg_metrics()

  set.seed(4)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(88)
  res <- anneal_run(wf, folds, p, ms)
  control <- attr(res, "procedure")$control

  # Drive the same per-fold worker directly, last fold first. A scheduler is
  # free to do exactly this; the results must not notice.
  reversed <- rev(seq_len(nrow(res)))
  out <- lapply(reversed, function(i) {
    nested_fold_fit(
      split = folds$splits[[i]],
      inner = folds$inner_resamples[[i]],
      seeds = c(res$.tuning_seed[[i]], res$.outer_fit_seed[[i]]),
      object = wf,
      tuner = anneal_tuner(),
      metrics = ms,
      param_info = p,
      control = control
    )
  })
  names(out) <- as.character(reversed)

  for (i in seq_len(nrow(res))) {
    expect_identical(out[[as.character(i)]]$metrics, res$.metrics[[i]])
    expect_identical(out[[as.character(i)]]$selected, res$.selected[[i]])
    expect_identical(
      out[[as.character(i)]]$inner_metrics,
      res$.inner_metrics[[i]]
    )
  }
})

test_that("fold results do not depend on the ambient RNG state or kind", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  p <- bayes_stoch_param_info(wf)
  ms <- reg_metrics()

  set.seed(5)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )
  seeds <- c(101L, 202L)
  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )
  control <- effective_control("tune_sim_anneal", anneal_control(), "first")

  run_one <- function() {
    nested_fold_fit(
      split = folds$splits[[1]],
      inner = folds$inner_resamples[[1]],
      seeds = seeds,
      object = wf,
      tuner = anneal_tuner(),
      metrics = ms,
      param_info = p,
      control = control
    )
  }

  RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]])
  set.seed(1)
  from_default <- run_one()

  # A fresh parallel worker would not be on the caller's generator. Pinning
  # the kind inside the fold is what makes these agree.
  RNGkind("L'Ecuyer-CMRG")
  set.seed(9999)
  from_lecuyer <- run_one()

  RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]])
  set.seed(31337)
  invisible(runif(17))
  from_midstream <- run_one()

  expect_true(from_default$completed)
  expect_identical(from_lecuyer, from_default)
  expect_identical(from_midstream, from_default)
})

test_that("the caller's RNG state and kind survive the call untouched", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ms <- reg_metrics()
  ctrl <- anneal_control()

  set.seed(404)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  invisible(nested_tune_sim_anneal(
    wf,
    folds,
    iter = 2,
    initial = 3,
    metrics = ms,
    control = ctrl
  ))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Net-zero stated the way a user would notice it: what they draw next is
  # what they would have drawn had the call not been there.
  set.seed(404)
  with_call <- {
    invisible(nested_tune_sim_anneal(
      wf,
      folds,
      iter = 2,
      initial = 3,
      metrics = ms,
      control = ctrl
    ))
    runif(3)
  }
  set.seed(404)
  without_call <- runif(3)
  expect_identical(with_call, without_call)
})

test_that("the RNG state is restored when folds fail but the run completes", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  ctrl <- anneal_control()

  # Both folds engineered to fail: the seeds are drawn, every fold fails
  # inside the search, and the failures are recorded rather than raised.
  set.seed(7)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )
  folds <- break_fold(break_fold(folds, 1L, "inner tuning"), 2L, "inner tuning")

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  res <- suppressWarnings(nested_tune_sim_anneal(
    wf,
    folds,
    iter = 2,
    initial = 3,
    metrics = reg_metrics(),
    control = ctrl
  ))
  expect_identical(attr(res, "folds_completed"), 0L)
  expect_false(any(res$.completed))
  # A fold that scored nothing carries the zero-row table under a completed
  # fold's columns, `.iter` among them: annealing iterates.
  expect_identical(nrow(res$.inner_metrics[[1L]]), 0L)
  expect_true(".iter" %in% names(res$.inner_metrics[[1L]]))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("the RNG state is restored when the call itself errors", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ctrl <- anneal_control()

  # The worker is stubbed to throw, so the error escapes the loop rather than
  # being recorded -- the only remaining way out of the call after the seeds
  # have been drawn, and the case on.exit() exists for.
  testthat::local_mocked_bindings(
    nested_fold_fit = function(...) stop("engineered worker failure")
  )

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  expect_error(
    nested_tune_sim_anneal(wf, folds, iter = 2, initial = 3, control = ctrl),
    "engineered worker failure"
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("a session with no RNG state is left with a valid one", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  ctrl <- anneal_control()

  saved <- .Random.seed
  on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)

  rm(".Random.seed", envir = globalenv())
  expect_no_error(
    nested_tune_sim_anneal(wf, folds, iter = 2, initial = 3, control = ctrl)
  )
  # Nothing to restore, so the state the call created stays -- removing it
  # would leave the session worse off than it was found.
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})
