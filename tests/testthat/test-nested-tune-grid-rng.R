# IP2 -- reproducible results. M02 ships no parallelism, so there is no backend
# to exercise the "regardless of workers" half of IP2. What is checkable
# serially is that a fold's result depends on its position and its seeds and on
# nothing else: not on the order folds run in, not on the RNG state or
# generator kind that happens to be active when a fold starts. Those are the
# conditions a fresh worker process presents, simulated in one session (RR01
# Q8). Every test that could pass vacuously under a deterministic engine uses
# ranger instead, whose fits draw from R's RNG.

test_that("the same seed produces the same result", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(3)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(77)
  first <- nested_tune_grid(wf, folds, grid = stoch_grid(), metrics = ms)
  set.seed(77)
  second <- nested_tune_grid(wf, folds, grid = stoch_grid(), metrics = ms)

  expect_identical(first$.metrics, second$.metrics)
  expect_identical(first$.selected, second$.selected)
  expect_identical(first$.tuning_seed, second$.tuning_seed)
})

test_that("a different seed produces different numbers", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(3)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(77)
  first <- nested_tune_grid(wf, folds, grid = stoch_grid(), metrics = ms)
  set.seed(78)
  other <- nested_tune_grid(wf, folds, grid = stoch_grid(), metrics = ms)

  # Without this the same-seed test above would pass for a driver that ignored
  # the seed entirely.
  expect_false(identical(first$.tuning_seed, other$.tuning_seed))
  expect_false(identical(first$.metrics, other$.metrics))
})

test_that("fold results do not depend on the order folds are run in", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(4)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(88)
  res <- nested_tune_grid(wf, folds, grid = stoch_grid(), metrics = ms)

  # Drive the same per-fold worker directly, last fold first. A scheduler is
  # free to do exactly this; the results must not notice.
  reversed <- rev(seq_len(nrow(res)))
  out <- lapply(reversed, function(i) {
    nested_fold_fit(
      split = folds$splits[[i]],
      inner = folds$inner_resamples[[i]],
      seeds = c(res$.tuning_seed[[i]], res$.outer_fit_seed[[i]]),
      object = wf,
      grid = stoch_grid(),
      metrics = ms
    )
  })
  names(out) <- as.character(reversed)

  for (i in seq_len(nrow(res))) {
    expect_identical(out[[as.character(i)]]$metrics, res$.metrics[[i]])
    expect_identical(out[[as.character(i)]]$selected, res$.selected[[i]])
  }
})

test_that("fold results do not depend on the ambient RNG state or kind", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(5)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )
  seeds <- c(101L, 202L)
  entry_kind <- RNGkind()
  on.exit(RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]), add = TRUE)

  run_one <- function() {
    nested_fold_fit(
      split = folds$splits[[1]],
      inner = folds$inner_resamples[[1]],
      seeds = seeds,
      object = wf,
      grid = stoch_grid(),
      metrics = ms
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

test_that("the caller's RNG state and kind survive the call untouched", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
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
  invisible(nested_tune_grid(wf, folds, grid = det_grid(), metrics = ms))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Net-zero stated the way a user would notice it: what they draw next is
  # what they would have drawn had the call not been there.
  set.seed(404)
  with_call <- {
    invisible(nested_tune_grid(wf, folds, grid = det_grid(), metrics = ms))
    runif(3)
  }
  set.seed(404)
  without_call <- runif(3)

  expect_identical(with_call, without_call)
})

# Two properties, not one. Before M03 a failing fold aborted the call, so a
# single test covered both the failure and the error exit. Now a fold failure
# is recorded and the call returns, which leaves the error path needing its
# own vehicle -- and the on.exit() restore has to hold on both.

test_that("the RNG state is restored when folds fail but the run completes", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  set.seed(7)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  # A grid naming a parameter the workflow does not tune: the seeds are drawn,
  # then every fold fails inside tune and the failures are recorded.
  res <- suppressWarnings(
    nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2))
  )
  expect_identical(attr(res, "folds_completed"), 0L)

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("the RNG state is restored when the call itself errors", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  set.seed(7)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  # The worker is stubbed to throw, so the error escapes the loop rather than
  # being recorded -- which is the only remaining way out of the call after the
  # seeds have been drawn, and the case on.exit() exists for.
  testthat::local_mocked_bindings(
    nested_fold_fit = function(...) stop("engineered worker failure")
  )

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  expect_error(
    nested_tune_grid(wf, folds, grid = det_grid(), metrics = reg_metrics()),
    "engineered worker failure"
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("a session with no RNG state is left with a valid one", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

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
    nested_tune_grid(wf, folds, grid = det_grid())
  )
  # Nothing to restore, so the state the call created stays -- removing it
  # would leave the session worse off than it was found.
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})
