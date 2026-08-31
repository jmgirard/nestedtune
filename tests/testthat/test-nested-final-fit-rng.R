# IP2 for the final-fit path (AC3, AC12).
#
# The path draws twice: once to build the inner rset and tune, once to fit.
# What is checkable is that everything downstream of the two seeds depends on
# them and on nothing ambient, and that the caller's stream is exactly where it
# was when the call returns -- including when the call errors. Tests that could
# pass vacuously under a deterministic engine use ranger.

test_that("the same seed produces the same final fit", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(77)
  first <- nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms)
  set.seed(77)
  second <- nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms)

  expect_identical(first$tuning_seed, second$tuning_seed)
  expect_identical(first$selected, second$selected)
  expect_identical(
    predict(extract_workflow(first), new_data = d),
    predict(extract_workflow(second), new_data = d)
  )
  expect_identical(
    tune::collect_metrics(first$tuning),
    tune::collect_metrics(second$tuning)
  )
})

test_that("a different seed produces a different final fit", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(77)
  first <- nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms)
  set.seed(78)
  other <- nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms)

  # Without this the same-seed test above would pass for a function that
  # ignored the seed entirely.
  expect_false(identical(first$tuning_seed, other$tuning_seed))
  expect_false(identical(
    predict(extract_workflow(first), new_data = d),
    predict(extract_workflow(other), new_data = d)
  ))
})

test_that("the fit does not depend on the ambient RNG state or kind", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  # Driven at the worker, with the two seeds supplied, because from a
  # user-visible seed this property cannot hold: the entry draw reads the
  # caller's stream, and that draw is itself kind-dependent -- set.seed(77)
  # then sample.int() gives different integers under Mersenne-Twister and
  # under L'Ecuyer-CMRG. What the kind pin buys is everything downstream of
  # the seeds, which is what this asserts. (M05's recorded deviation from
  # RR02's BC6; the same idiom test-nested-tune-grid-rng.R uses.)
  seeds <- c(101L, 202L)
  inside <- attr(folds, "inside")
  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )

  run_one <- function() {
    final_fit_worker(inside, d, environment(), seeds, wf, stoch_grid(), ms)
  }

  set.seed(1)
  from_default <- run_one()

  RNGkind("L'Ecuyer-CMRG")
  set.seed(9999)
  from_lecuyer <- run_one()

  RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]])
  set.seed(31337)
  invisible(runif(17))
  from_midstream <- run_one()

  expect_identical(from_lecuyer$selected, from_default$selected)
  expect_identical(from_midstream$selected, from_default$selected)
  expect_identical(
    predict(extract_workflow(from_lecuyer), new_data = d),
    predict(extract_workflow(from_default), new_data = d)
  )
  expect_identical(
    predict(extract_workflow(from_midstream), new_data = d),
    predict(extract_workflow(from_default), new_data = d)
  )
})

test_that("the caller's RNG state and kind survive the call untouched", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  set.seed(404)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  invisible(nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Net-zero stated the way a user would notice it.
  set.seed(404)
  with_call <- {
    invisible(nested_final_fit(wf, folds, grid = stoch_grid(), metrics = ms))
    runif(3)
  }
  set.seed(404)
  without_call <- runif(3)

  expect_identical(with_call, without_call)
})

test_that("the RNG state is restored when the call errors after the snapshot", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)

  # The failure has to land inside the guarded region to test anything: the
  # argument checks all fire before the snapshot, so an error from one of them
  # would leave the caller's state untouched no matter what on.exit() did
  # (AC12). This design re-evaluates its inner specification after the tuning
  # seed has already been set, so a specification that cannot be re-evaluated
  # fails exactly there -- past the snapshot, past a set.seed().
  folds <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  expect_error(
    nested_final_fit(wf, folds, grid = stoch_grid(), metrics = reg_metrics()),
    "could not be"
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("the kind is restored on the error path from a non-default kind", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)

  folds <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })

  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )

  # The failure path sets the kind before it errors, so a caller who had
  # chosen another generator would be left on ours without the restore.
  RNGkind("L'Ecuyer-CMRG")
  set.seed(606)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  expect_error(nested_final_fit(wf, folds, grid = stoch_grid()), "could not be")

  expect_identical(RNGkind(), before_kind)
  expect_identical(.Random.seed, before_seed)
})

test_that("a session with no RNG state is left with a valid one", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- stoch_workflow(d)

  saved <- .Random.seed
  on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)
  rm(".Random.seed", envir = globalenv())

  expect_no_error(nested_final_fit(wf, folds, grid = stoch_grid()))
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})
