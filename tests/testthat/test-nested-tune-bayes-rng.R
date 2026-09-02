# IP2 for the Bayesian path (M45 AC4). The eight properties
# test-nested-tune-grid-rng.R holds the grid path to, asserted on
# nested_tune_bayes(), plus the one rule that is this path's own: the
# Gaussian-process seed is the fold's tuning seed, and the control carrying it
# is built inside that seed's scope. Every test that could pass vacuously under
# a deterministic engine uses ranger, whose fits draw from R's RNG; the
# proposals themselves draw too, through tune's own `set.seed(control$seed +
# i)` calls, which is what the seed rule fixes.

bayes_tuner <- function() tuner_bayes(2, 3, tune::exp_improve())

test_that("the same seed produces the same result", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

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
  first <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )
  set.seed(77)
  second <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )

  expect_identical(first$.metrics, second$.metrics)
  expect_identical(first$.selected, second$.selected)
  expect_identical(first$.inner_metrics, second$.inner_metrics)
  expect_identical(first$.tuning_seed, second$.tuning_seed)
})

test_that("a different seed produces different numbers", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

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
  first <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )
  set.seed(78)
  other <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )

  # Without this the same-seed test above would pass for a driver that ignored
  # the seed entirely.
  expect_false(identical(first$.tuning_seed, other$.tuning_seed))
  expect_false(identical(first$.metrics, other$.metrics))
})

test_that("fold results do not depend on the order folds are run in", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

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
  res <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )

  # Drive the same per-fold worker directly, last fold first. A scheduler is
  # free to do exactly this; the results must not notice.
  reversed <- rev(seq_len(nrow(res)))
  out <- lapply(reversed, function(i) {
    nested_fold_fit(
      split = folds$splits[[i]],
      inner = folds$inner_resamples[[i]],
      seeds = c(res$.tuning_seed[[i]], res$.outer_fit_seed[[i]]),
      object = wf,
      tuner = bayes_tuner(),
      metrics = ms,
      param_info = p
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
  skip_if_no_bayes_fixture(stochastic = TRUE)

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

  run_one <- function() {
    nested_fold_fit(
      split = folds$splits[[1]],
      inner = folds$inner_resamples[[1]],
      seeds = seeds,
      object = wf,
      tuner = bayes_tuner(),
      metrics = ms,
      param_info = p
    )
  }

  set.seed(1)
  from_default <- run_one()

  # A fresh parallel worker would not be on the caller's generator. Pinning the
  # kind inside the fold is what makes these agree.
  RNGkind("L'Ecuyer-CMRG")
  set.seed(9999)
  from_lecuyer <- run_one()

  RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]])
  set.seed(31337)
  invisible(runif(17))
  from_midstream <- run_one()

  expect_identical(from_lecuyer, from_default)
  expect_identical(from_midstream, from_default)
})

test_that("the Gaussian-process seed is the fold's tuning seed, set inside its scope", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  p <- bayes_param_info(wf)

  set.seed(6)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )
  seeds <- c(4321L, 8765L)

  # The control's construction is observed where it happens, through the
  # package's own seam: what seed it was handed, and what the generator's state
  # was at that moment.
  seen <- new.env(parent = emptyenv())
  real <- tuner_control
  local_mocked_bindings(
    tuner_control = function(tuner, control, event_level, seed) {
      seen$seed <- seed
      seen$state <- get(".Random.seed", envir = globalenv())
      real(tuner, control = control, event_level = event_level, seed = seed)
    }
  )

  fold <- nested_fold_fit(
    split = folds$splits[[1]],
    inner = folds$inner_resamples[[1]],
    seeds = seeds,
    object = wf,
    tuner = bayes_tuner(),
    metrics = reg_metrics(),
    param_info = p
  )
  expect_true(fold$completed)

  # The seed handed to control_bayes() is the fold's tuning seed ...
  expect_identical(seen$seed, seeds[[1L]])

  # ... and the control was built with the generator exactly where
  # `set_fold_seed()` on that seed leaves it: nothing was drawn in between, so
  # the control sits inside the seed's scope rather than after some of it.
  set_fold_seed(seeds[[1L]])
  expect_identical(seen$state, get(".Random.seed", envir = globalenv()))
})

test_that("the caller's RNG state and kind survive the call untouched", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  p <- bayes_param_info(wf)
  ms <- reg_metrics()

  set.seed(6)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(404)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  invisible(nested_tune_bayes(
    wf,
    folds,
    iter = 1,
    initial = 3,
    param_info = p,
    metrics = ms
  ))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Net-zero stated the way a user would notice it: what they draw next is
  # what they would have drawn had the call not been there.
  set.seed(404)
  with_call <- {
    invisible(nested_tune_bayes(
      wf,
      folds,
      iter = 1,
      initial = 3,
      param_info = p,
      metrics = ms
    ))
    runif(3)
  }
  set.seed(404)
  without_call <- runif(3)

  expect_identical(with_call, without_call)
})

test_that("the RNG state is restored when folds fail but the run completes", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  p <- bayes_param_info(wf)

  set.seed(7)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  # Both folds engineered to fail: the seeds are drawn, every fold fails inside
  # tune, and the failures are recorded rather than raised.
  folds <- break_fold(break_fold(folds, 1L, "inner tuning"), 2L, "inner tuning")

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  res <- suppressWarnings(
    nested_tune_bayes(
      wf,
      folds,
      iter = 1,
      initial = 3,
      param_info = p,
      metrics = reg_metrics()
    )
  )
  expect_identical(attr(res, "folds_completed"), 0L)
  expect_false(any(res$.completed))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("the RNG state is restored when the call itself errors", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)

  set.seed(7)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

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
    nested_tune_bayes(
      wf,
      folds,
      iter = 1,
      initial = 3,
      metrics = reg_metrics()
    ),
    "engineered worker failure"
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("a session with no RNG state is left with a valid one", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  p <- bayes_param_info(wf)

  set.seed(8)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  saved <- .Random.seed
  on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)
  rm(".Random.seed", envir = globalenv())

  expect_no_error(
    nested_tune_bayes(wf, folds, iter = 1, initial = 3, param_info = p)
  )
  # Nothing to restore, so the state the call created stays -- removing it
  # would leave the session worse off than it was found.
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})
