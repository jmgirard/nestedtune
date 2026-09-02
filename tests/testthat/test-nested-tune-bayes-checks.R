# Every refusal `nested_tune_bayes()` makes at entry, fired once (M45 AC6).
# GP3: a provably wrong call is refused before a whole outer loop is paid for.
#
# Two halves. The three arguments that are this orchestrator's own -- `iter`,
# `initial`, `objective` -- each refuse with a class of their own, naming the
# user's call. And every check the grid orchestrator makes, other than the two
# that judge a grid, is made here too: the set is read off both function
# bodies rather than listed by hand, so a check added to one and forgotten in
# the other fails by name.

bayes_folds <- function(d) det_nested(d, v = 2)

# The refusal, as the condition it raised. Fitting is replaced by a sentinel
# so a check that ran AFTER the loop began would surface as the sentinel's
# class rather than its own -- which is what separates "refused at entry" from
# "refused eventually".
refusal <- function(expr) {
  sentinel <- function(...) {
    rlang::abort("fitting began", class = "nestedtune_sentinel")
  }
  testthat::local_mocked_bindings(dispatch_folds = sentinel)
  tryCatch(expr, error = function(cnd) cnd)
}

expect_refused <- function(cnd, class, pattern) {
  testthat::expect_s3_class(cnd, class)
  testthat::expect_false(inherits(cnd, "nestedtune_sentinel"))
  testthat::expect_match(conditionMessage(cnd), pattern)
  testthat::expect_identical(
    conditionCall(cnd)[[1L]],
    as.name("nested_tune_bayes")
  )
  invisible(cnd)
}

test_that("`iter` must be a single non-negative whole number", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  for (bad in list(-1, 2.5, "3", c(1, 2), NA_real_, Inf, NULL, TRUE)) {
    cnd <- refusal(nested_tune_bayes(wf, folds, iter = bad))
    expect_refused(cnd, "nestedtune_bad_iter", "non-negative whole number")
  }
  # The value is named when there is one to name.
  cnd <- refusal(nested_tune_bayes(wf, folds, iter = 2.5))
  expect_match(conditionMessage(cnd), "2.5")
})

test_that("`initial` must be a single whole number of at least 2", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  for (bad in list(1, 0, -3, 2.5, "5", c(3, 4), NA_real_, Inf, NULL)) {
    cnd <- refusal(nested_tune_bayes(wf, folds, initial = bad))
    expect_refused(cnd, "nestedtune_bad_initial", "at least 2")
  }
})

test_that("`initial` refuses a tune_results, which tune would accept", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  # A genuine tuning run, so the refusal is shown to fire on the object tune's
  # own `check_initial()` accepts rather than on a stand-in wearing its class.
  set.seed(1)
  earlier <- tune::tune_grid(
    wf,
    resamples = folds$inner_resamples[[1L]],
    grid = 3,
    param_info = bayes_param_info(wf),
    control = tune::control_grid(allow_par = FALSE)
  )
  expect_s3_class(earlier, "tune_results")

  cnd <- refusal(nested_tune_bayes(wf, folds, initial = earlier))
  expect_refused(cnd, "nestedtune_bad_initial", "not a")
  expect_match(conditionMessage(cnd), "tune_results")
  expect_match(conditionMessage(cnd), "assessment rows")
})

test_that("`objective` must be an acquisition function", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  # `tune::exp_improve` uncalled is the likeliest slip: a function, not the
  # object it returns.
  for (bad in list(NULL, "exp_improve", tune::exp_improve, list(), 1)) {
    cnd <- refusal(nested_tune_bayes(wf, folds, objective = bad))
    expect_refused(cnd, "nestedtune_bad_objective", "acquisition function")
  }
  expect_match(
    conditionMessage(refusal(nested_tune_bayes(wf, folds, objective = 1))),
    "exp_improve"
  )
})

test_that("the three acquisition functions tune offers are accepted", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  # Accepted means the sentinel is reached: the checks passed and the loop was
  # about to begin.
  for (ok in list(
    tune::exp_improve(),
    tune::prob_improve(),
    tune::conf_bound()
  )) {
    cnd <- refusal(nested_tune_bayes(wf, folds, objective = ok))
    expect_s3_class(cnd, "nestedtune_sentinel")
  }
})

# The shared checks. The list is derived, not written: every `check_*()` the
# grid orchestrator's body calls, less the two that judge a grid, must appear
# in this orchestrator's body.

check_calls <- function(fn) {
  nms <- all.names(body(fn))
  sort(unique(nms[startsWith(nms, "check_")]))
}

test_that("every check the grid path makes, the Bayesian path makes too", {
  grid_checks <- check_calls(nested_tune_grid)
  bayes_checks <- check_calls(nested_tune_bayes)

  # One fact held independently of the derivation: the enumeration cannot
  # silently empty.
  expect_true(all(c("check_workflow", "check_nested") %in% grid_checks))

  shared <- setdiff(grid_checks, c("check_grid", "check_grid_params"))
  expect_identical(setdiff(shared, bayes_checks), character(0))
  # And the two grid checks stay off the Bayesian path, where there is no grid.
  expect_false(any(c("check_grid", "check_grid_params") %in% bayes_checks))
})

test_that("each shared check fires through nested_tune_bayes()", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  # One refusal per shared check, keyed by the check's name so the table below
  # is held to the derived list rather than the other way round.
  fired <- list(
    check_dots_control = function() nested_tune_bayes(wf, folds, 3),
    check_control = function() nested_tune_bayes(wf, folds, control = "no"),
    check_workflow = function() nested_tune_bayes(parsnip::linear_reg(), folds),
    check_nested = function() {
      nested_tune_bayes(wf, rsample::vfold_cv(d, v = 2))
    },
    check_metrics = function() nested_tune_bayes(wf, folds, metrics = "rmse"),
    check_param_info = function() {
      nested_tune_bayes(wf, folds, param_info = data.frame(df1 = 1:3))
    },
    check_event_level = function() {
      nested_tune_bayes(wf, folds, event_level = "third")
    },
    check_eval_time = function() nested_tune_bayes(wf, folds, eval_time = -1)
  )
  patterns <- c(
    check_dots_control = "accepts `control`",
    check_control = "control_bayes",
    check_workflow = "must be a",
    check_nested = "nested resampling design",
    check_metrics = "metric_set",
    check_param_info = "parameters",
    check_event_level = "event_level",
    check_eval_time = "eval_time"
  )

  shared <- setdiff(
    check_calls(nested_tune_grid),
    c("check_grid", "check_grid_params")
  )
  expect_identical(setdiff(shared, names(fired)), character(0))

  for (nm in names(fired)) {
    cnd <- refusal(fired[[nm]]())
    expect_s3_class(cnd, "error")
    expect_false(inherits(cnd, "nestedtune_sentinel"))
    expect_match(conditionMessage(cnd), patterns[[nm]], info = nm)
    expect_identical(conditionCall(cnd)[[1L]], as.name("nested_tune_bayes"))
  }
})

# M48: what `...` accepts, and what a control may carry.

test_that("`...` accepts `control` and nothing else (M48, AC5)", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  cnd <- refusal(nested_tune_bayes(wf, folds, nonesuch = 1))
  expect_refused(cnd, "nestedtune_bad_dots", "nonesuch")

  cnd <- refusal(nested_tune_bayes(wf, folds, 3))
  expect_refused(cnd, "nestedtune_bad_dots", "unnamed")

  cnd <- refusal(nested_tune_bayes(wf, folds, control = ac1_control(), no = 1))
  expect_refused(cnd, "nestedtune_bad_dots", "`no`")

  # `call` is the name of the check's own formal: a caller's `call = ` once
  # bound there and slipped the fence (M48 review round 1, finding 1).
  cnd <- refusal(nested_tune_bayes(wf, folds, call = quote(bogus())))
  expect_refused(cnd, "nestedtune_bad_dots", "`call`")
})

test_that("`control` must be what tune::control_bayes() returns (M48, AC5)", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  # The grid control is the one a caller is likeliest to reach for, and tune
  # itself would accept it (its `condense_control()` reads slots by name).
  for (bad in list(tune::control_grid(), list(allow_par = FALSE), "no", 1)) {
    cnd <- refusal(nested_tune_bayes(wf, folds, control = bad))
    expect_refused(cnd, "nestedtune_bad_control", "control_bayes")
  }
})

test_that("a control naming another event level is refused at entry (M48, AC3)", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  cnd <- refusal(nested_tune_bayes(
    wf,
    folds,
    event_level = "first",
    control = tune::control_bayes(event_level = "second")
  ))
  expect_refused(cnd, "nestedtune_bad_control", "event_level")
  expect_match(conditionMessage(cnd), "\"first\"")
  expect_match(conditionMessage(cnd), "\"second\"")

  # A control left at tune's default takes the argument's level instead of
  # being refused: the entry checks pass and fitting begins.
  cnd <- refusal(nested_tune_bayes(
    wf,
    folds,
    event_level = "second",
    control = tune::control_bayes()
  ))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

test_that("a refusal leaves the RNG where it found it", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- bayes_folds(d)

  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_bayes(wf, folds, iter = -1))
  expect_error(nested_tune_bayes(wf, folds, initial = 1))
  expect_error(nested_tune_bayes(wf, folds, objective = NULL))
  expect_identical(.Random.seed, before)
})
