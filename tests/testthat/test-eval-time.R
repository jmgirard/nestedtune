# Oracle records (DESIGN Conventions: oracles are recorded in the test file
# that asserts them). The records for the behavioral oracles are added with the
# tests that pin them; this file opens with the fixture's own properties, which
# are asserted rather than assumed because every comparison below is vacuous
# without them.

# The evaluation times a censored-regression metric is measured at (M41).
#
# Everything here runs on the srv_* fixture (helper-orchestration.R), built so
# `eval_time` has something to move: a mixture of early failures no log-normal
# can reproduce and a long tail no exponential can match, so the grid's three
# distributions rank differently at the fixture's early time than at its late
# one. The first tests assert the fixture still has those properties -- without
# them a run at either time would agree with a run at the other for reasons
# having nothing to do with whether the argument was forwarded.

test_that("both evaluation times have observations at risk and events on either side", {
  skip_if_no_censored()

  data <- srv_data()
  times <- srv_eval_times()

  for (t in times) {
    profile <- srv_risk_profile(data, t)
    expect_gt(profile[["at_risk"]], 0L)
    expect_gt(profile[["events_before"]], 0L)
    expect_gt(profile[["events_after"]], 0L)
  }

  # The metric is computed on each outer fold's assessment set, not on the
  # whole frame, so the property has to hold there too -- a fold whose
  # assessment set has nobody left at risk reports a Brier score that says
  # nothing about the evaluation time.
  nested <- srv_nested(data)
  for (i in seq_len(nrow(nested))) {
    assessment <- rsample::assessment(nested$splits[[i]])
    for (t in times) {
      profile <- srv_risk_profile(assessment, t)
      expect_gt(profile[["at_risk"]], 0L)
      expect_gt(profile[["events_before"]], 0L)
      expect_gt(profile[["events_after"]], 0L)
    }
  }
})

test_that("the fixture's grid is ranked differently at the two evaluation times", {
  skip_if_no_censored()

  data <- srv_data()
  times <- srv_eval_times()
  workflow <- srv_workflow(data)

  set.seed(7)
  resamples <- rsample::vfold_cv(data, v = 3)

  ranked <- lapply(times, function(t) {
    set.seed(99)
    tuned <- tune::tune_grid(
      workflow,
      resamples = resamples,
      grid = srv_grid(),
      metrics = srv_metrics(),
      eval_time = t,
      control = tune::control_grid(allow_par = FALSE)
    )
    scored <- tune::collect_metrics(tuned)
    scored <- scored[scored$.metric == "brier_survival", ]
    scored[order(scored$mean), ]
  })

  early <- ranked[[1L]]
  late <- ranked[[2L]]

  # Which candidate is best, not merely by how much: the log-normal is the best
  # of the three at the early time and the worst at the late one, so a run that
  # ignored `eval_time` could not produce both orders.
  expect_identical(early$dist[[1L]], "lognormal")
  expect_identical(late$dist[[nrow(late)]], "lognormal")
  expect_false(identical(early$dist, late$dist))

  # And the winner is not a tie broken by rounding. Measured 2026-09-01 on
  # tune 2.1.0 / censored 0.3.4: 1.0% at the early time, 3.5% at the late one.
  for (scored in ranked) {
    expect_gt((scored$mean[[2L]] - scored$mean[[1L]]) / scored$mean[[1L]], 0.005)
  }
})

# AC1 -------------------------------------------------------------------
#
# These run on the regression fixture rather than the censored one: what they
# assert is the entry check and its position, neither of which consults the
# mode, and running them without `censored` installed is what makes the refusal
# testable everywhere the package is.

# The values the check refuses, and why each is here. `-1` is negative,
# `NA_real_` missing, `Inf` not finite, `"1"` not numeric at all -- a value tune
# would have coerced -- and `numeric(0)` leaves tune with nothing to evaluate
# at. `c(1, NA_real_)` is the one that matters most: every other probe has
# length one, so a check that looked only at `eval_time[[1]]` would pass all of
# them.
unusable_eval_times <- function() {
  list(-1, NA_real_, "1", Inf, numeric(0), c(1, NA_real_))
}

test_that("AC1: an unusable `eval_time` is refused, naming the function the user called", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  for (value in unusable_eval_times()) {
    cnd <- tryCatch(
      nested_tune_grid(wf, folds, grid = det_grid(), eval_time = value),
      error = function(e) e
    )
    expect_s3_class(cnd, "rlang_error")
    expect_match(conditionMessage(cnd), "eval_time", fixed = TRUE)
    expect_identical(rlang::call_name(conditionCall(cnd)), "nested_tune_grid")

    cnd <- tryCatch(
      nested_final_fit(wf, folds, grid = det_grid(), eval_time = value),
      error = function(e) e
    )
    expect_s3_class(cnd, "rlang_error")
    expect_match(conditionMessage(cnd), "eval_time", fixed = TRUE)
    expect_identical(rlang::call_name(conditionCall(cnd)), "nested_final_fit")
  }

  # A vector's offending positions are named, not just the fact that one exists.
  cnd <- tryCatch(
    nested_tune_grid(
      wf,
      folds,
      grid = det_grid(),
      eval_time = c(1, NA_real_, 3, -2)
    ),
    error = function(e) e
  )
  expect_match(conditionMessage(cnd), "2 and 4")
})

test_that("AC1: the refusal fires before any fitting begins", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  # The two functions that begin the fitting, replaced by a signal. A check that
  # ran after them would raise this sentinel instead of its own message, and an
  # accepted value has to raise it -- which is what distinguishes "refused
  # early" from "never got there at all".
  sentinel <- function(...) {
    rlang::abort("fitting began", class = "nestedtune_sentinel")
  }
  local_mocked_bindings(dispatch_folds = sentinel, final_fit_worker = sentinel)

  for (value in unusable_eval_times()) {
    expect_error(
      nested_tune_grid(wf, folds, grid = det_grid(), eval_time = value),
      class = "rlang_error"
    )
    expect_false(inherits(
      tryCatch(
        nested_tune_grid(wf, folds, grid = det_grid(), eval_time = value),
        error = function(e) e
      ),
      "nestedtune_sentinel"
    ))
    expect_false(inherits(
      tryCatch(
        nested_final_fit(wf, folds, grid = det_grid(), eval_time = value),
        error = function(e) e
      ),
      "nestedtune_sentinel"
    ))
  }

  # The accepting side, including the values tune normalizes rather than
  # refuses: zero, a repeat, and times out of order (D-038).
  accepted <- list(NULL, 0, c(0.5, 10), c(10, 0.5, 10))
  for (value in accepted) {
    expect_error(
      nested_tune_grid(wf, folds, grid = det_grid(), eval_time = value),
      class = "nestedtune_sentinel"
    )
    expect_error(
      nested_final_fit(wf, folds, grid = det_grid(), eval_time = value),
      class = "nestedtune_sentinel"
    )
  }
})

test_that("AC1: an accepted `eval_time` reaches the outer loop untouched", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  # What each entry point hands on, captured where the fitting would have
  # begun. `expect_identical()` rather than a comparison of sorted unique
  # values: nothing on this path is allowed to normalize the vector, since
  # deciding what tune does with a repeat or an unsorted pair is tune's job.
  seen <- new.env(parent = emptyenv())
  local_mocked_bindings(
    dispatch_folds = function(..., eval_time) {
      seen$value <- list(eval_time)
      rlang::abort("captured", class = "nestedtune_sentinel")
    }
  )

  for (value in list(NULL, 0, c(0.5, 10), c(10, 0.5, 10))) {
    seen$value <- NULL
    expect_error(
      nested_tune_grid(wf, folds, grid = det_grid(), eval_time = value),
      class = "nestedtune_sentinel"
    )
    expect_identical(seen$value, list(value))
  }
})

test_that("AC1: an accepted `eval_time` reaches the final fit untouched", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  seen <- new.env(parent = emptyenv())
  local_mocked_bindings(
    final_fit_worker = function(..., eval_time) {
      seen$value <- list(eval_time)
      rlang::abort("captured", class = "nestedtune_sentinel")
    }
  )

  for (value in list(NULL, 0, c(0.5, 10), c(10, 0.5, 10))) {
    seen$value <- NULL
    expect_error(
      nested_final_fit(wf, folds, grid = det_grid(), eval_time = value),
      class = "nestedtune_sentinel"
    )
    expect_identical(seen$value, list(value))
  }
})
