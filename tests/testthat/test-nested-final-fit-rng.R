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
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(77)
  first <- nested_final_fit(wf, res)
  set.seed(77)
  second <- nested_final_fit(wf, res)

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
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(77)
  first <- nested_final_fit(wf, res)
  set.seed(78)
  other <- nested_final_fit(wf, res)

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
  wf <- stoch_workflow(d)
  ms <- reg_metrics()
  res <- stoch_final_results(d)

  # Driven at the worker, with the two seeds supplied, because from a
  # user-visible seed this property cannot hold: the entry draw reads the
  # caller's stream, and that draw is itself kind-dependent -- set.seed(77)
  # then sample.int() gives different integers under Mersenne-Twister and
  # under L'Ecuyer-CMRG. What the kind pin buys is everything downstream of
  # the seeds, which is what this asserts. (M05's recorded deviation from
  # RR02's BC6; the same idiom test-nested-tune-grid-rng.R uses.)
  seeds <- c(101L, 202L)
  inside <- attr(res, "inside")
  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )

  run_one <- function() {
    final_fit_worker(
      inside,
      d,
      environment(),
      seeds,
      wf,
      tuner_grid(stoch_grid()),
      ms
    )
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
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(404)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  invisible(nested_final_fit(wf, res))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Net-zero stated the way a user would notice it.
  set.seed(404)
  with_call <- {
    invisible(nested_final_fit(wf, res))
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
  # fails exactly there -- past the snapshot, past a set.seed(). The loop
  # accepts such a design; only the final fit re-evaluates the stored call, so
  # the results object it errors on is built here rather than at the loop.
  gone <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })
  res_gone <- memoised(nested_tune_grid(
    wf,
    gone,
    grid = stoch_grid(),
    metrics = reg_metrics()
  ))

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  expect_error(
    nested_final_fit(wf, res_gone),
    "could not be"
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("the kind is restored on the error path from a non-default kind", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)

  gone <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })
  res_gone <- memoised(nested_tune_grid(
    wf,
    gone,
    grid = stoch_grid(),
    metrics = reg_metrics()
  ))

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

  expect_error(nested_final_fit(wf, res_gone), "could not be")

  expect_identical(RNGkind(), before_kind)
  expect_identical(.Random.seed, before_seed)
})

test_that("a session with no RNG state is left with a valid one", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  saved <- .Random.seed
  on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)
  rm(".Random.seed", envir = globalenv())

  expect_no_error(nested_final_fit(wf, res))
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})


# The Bayesian path (M46 AC4) --------------------------------------------------
#
# The same properties, on a result whose re-run is `tune_bayes()`: the
# proposals draw through tune's own `set.seed(control$seed + i)`, seeded from
# the tuning seed, and ranger's fits draw from the stream, so none of these
# passes vacuously.

test_that("the same seed produces the same Bayesian final fit, a different seed a different one", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- bayes_stoch_final_results(d)

  # Called directly, as the grid strand is: the fixture cache keys on the RNG
  # state, and a net-zero call leaves the second `set.seed(77)` at the first's
  # key, so a memoised pair would compare one object with itself (M46 review).
  set.seed(77)
  first <- nested_final_fit(wf, res)
  set.seed(77)
  second <- nested_final_fit(wf, res)
  set.seed(78)
  other <- memoised(nested_final_fit(wf, res))

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

  expect_false(identical(first$tuning_seed, other$tuning_seed))
  expect_false(identical(
    predict(extract_workflow(first), new_data = d),
    predict(extract_workflow(other), new_data = d)
  ))
})

test_that("the Bayesian fit does not depend on the ambient RNG state or kind", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- bayes_stoch_final_results(d)
  proc <- attr(res, "procedure")

  # Driven at the worker with the two seeds supplied, for the reason the grid
  # test above gives: the entry draw is itself kind-dependent.
  seeds <- c(101L, 202L)
  inside <- attr(res, "inside")
  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )

  run_one <- function() {
    final_fit_worker(
      inside,
      d,
      environment(),
      seeds,
      wf,
      procedure_tuner(proc),
      attr(res, "metrics"),
      param_info = proc$param_info
    )
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
    tune::collect_metrics(from_lecuyer$tuning),
    tune::collect_metrics(from_default$tuning)
  )
  expect_identical(
    predict(extract_workflow(from_lecuyer), new_data = d),
    predict(extract_workflow(from_default), new_data = d)
  )
  expect_identical(
    predict(extract_workflow(from_midstream), new_data = d),
    predict(extract_workflow(from_default), new_data = d)
  )
})

test_that("the caller's RNG state and kind survive a Bayesian final fit", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- bayes_stoch_final_results(d)

  set.seed(404)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  invisible(nested_final_fit(wf, res))

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  # Direct calls: a memoised second call at the same state is a cache hit
  # that runs nothing, so the identity below could not fail (M46 review).
  set.seed(404)
  with_call <- {
    invisible(nested_final_fit(wf, res))
    runif(3)
  }
  set.seed(404)
  without_call <- runif(3)
  expect_identical(with_call, without_call)
})

test_that("the RNG state and kind are restored when a Bayesian final fit errors", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  p <- bayes_param_info(wf)

  # A Bayesian result whose recorded specification cannot be re-evaluated:
  # the failure lands past the snapshot and past a set.seed(), as above.
  gone <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })
  set.seed(24)
  res_gone <- memoised(nested_tune_bayes(
    wf,
    gone,
    iter = 1,
    initial = 3,
    param_info = p
  ))

  entry_kind <- RNGkind()
  on.exit(
    RNGkind(entry_kind[[1]], entry_kind[[2]], entry_kind[[3]]),
    add = TRUE
  )

  set.seed(505)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  expect_error(nested_final_fit(wf, res_gone), "could not be")
  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)

  RNGkind("L'Ecuyer-CMRG")
  set.seed(606)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  expect_error(nested_final_fit(wf, res_gone), "could not be")
  expect_identical(RNGkind(), before_kind)
  expect_identical(.Random.seed, before_seed)
})

test_that("a session with no RNG state is left with a valid one by a Bayesian final fit", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  res <- bayes_final_results(d)

  saved <- .Random.seed
  on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)
  rm(".Random.seed", envir = globalenv())

  expect_no_error(nested_final_fit(wf, res))
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_no_error(runif(1))
})

test_that("AC4: the final fit reads nothing from the fold rows but splits and .completed", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  res <- bayes_final_results(d)

  # Every fold-row column but `splits` and `.completed` overwritten -- the
  # label columns, the per-fold records, the seeds -- by assignment on the
  # unclassed columns, the class and attributes then re-stamped. A verb would
  # strip the class (the invariant rule), which is why the corruption is
  # surgery. `.completed` is the one other column the fit reads: the
  # all-failed refusal (test-nested-final-fit-checks.R) reads it at entry, so
  # it is left as the run wrote it.
  corrupt <- res
  attrs <- attributes(res)
  class(corrupt) <- setdiff(class(corrupt), "nested_results")
  n <- nrow(corrupt)
  wrong <- setdiff(names(corrupt), c("splits", ".completed"))
  expect_setequal(
    wrong,
    c(
      "id",
      ".metrics",
      ".selected",
      ".inner_metrics",
      ".notes",
      ".tuning_seed",
      ".outer_fit_seed"
    )
  )
  for (nm in wrong) {
    corrupt[[nm]] <- if (is.list(corrupt[[nm]])) {
      rep(list("corrupted"), n)
    } else if (is.integer(corrupt[[nm]])) {
      rep(-1L, n)
    } else {
      rep("corrupted", n)
    }
  }
  attributes(corrupt) <- c(
    attrs[setdiff(names(attrs), "names")],
    list(names = names(corrupt))
  )
  expect_s3_class(corrupt, "nested_results")
  expect_identical(attr(corrupt, "procedure"), attr(res, "procedure"))
  expect_false(identical(corrupt$.tuning_seed, res$.tuning_seed))

  set.seed(31)
  clean <- memoised(nested_final_fit(wf, res))
  set.seed(31)
  from_corrupt <- nested_final_fit(wf, corrupt)

  expect_identical(from_corrupt$selected, clean$selected)
  expect_identical(
    lapply(from_corrupt$tuning$splits, function(s) s$in_id),
    lapply(clean$tuning$splits, function(s) s$in_id)
  )
  expect_identical(
    predict(extract_workflow(from_corrupt), new_data = d),
    predict(extract_workflow(clean), new_data = d)
  )
})
