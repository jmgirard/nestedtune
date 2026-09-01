# Oracle records (DESIGN Conventions: oracles are recorded in the test file
# that asserts them). The file opens with the fixture's own properties, which
# are asserted rather than assumed because every comparison below is vacuous
# without them.
#
# O1 -- type "closed-form". Source: the definition of the IPCW Brier score --
#   the mean over the held-out rows of w_i * (1{T_i > t} - S_hat(t | x_i))^2,
#   with Graf's inverse-probability-of-censoring weights built here from a
#   reverse Kaplan-Meier of the censoring distribution fitted on the fold's own
#   analysis rows (`survival::survfit(Surv(time, 1 - event) ~ 1)`), evaluated at
#   `min(T_i, t)` and zero for a row censored before `t`. Nothing from `tune`
#   or `yardstick` computes it; `yardstick::brier_survival()` is read beside it
#   as a second reading of the same predictions. Pinned by "AC2: the metric each
#   outer fold reports at the named evaluation time is the IPCW Brier score".
#
# O2 -- type "live" (independent implementation). Source: a `tune::tune_grid()`
#   plus `tune::last_fit()` the test runs itself from the fold's own
#   `inner_resamples` and split, seeded by the recipe `nested_fold_fit()`
#   follows -- the fold's recorded `.tuning_seed` then its `.outer_fit_seed`,
#   both kind-pinned -- at the same evaluation time. Pinned by "AC3: each run's
#   per-fold metrics are the ones tune produces at that evaluation time", and in
#   its final-fit form by "AC4: nested_final_fit() tunes and selects under the
#   caller's evaluation time".
#
# O3 -- type "invariant". Source: two internal routes that must agree -- a run
#   at a multi-element `eval_time` and a run at that vector's first element have
#   to select the same candidate and report the same number at that element,
#   because `tune:::first_eval_time()` takes element one either way. Pinned by
#   "AC3: a multi-element evaluation time reports what its first element names".

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

# AC2 -- O1 -------------------------------------------------------------

# The generator kind `nested_fold_fit()` pins, so a reference run draws the same
# stream the recorded seed drew.
seed_as_fold <- function(seed) {
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
}

# The IPCW Brier score at `t` from the definition, with no metric function of
# any kind: refit the fold's selected candidate on its analysis rows under the
# seed the fold recorded, predict the survival probability of the rows it held
# out, and average the squared error under Graf's weights.
#
# The weights are built here rather than read off the prediction object, so the
# comparison does not confirm itself: a reverse Kaplan-Meier of the censoring
# distribution -- the same data with the event indicator flipped -- fitted on
# the analysis rows alone. A row still at risk at `t` is weighted by 1/G(t), a
# row that failed before `t` by 1/G at its own failure time, and a row censored
# before `t` contributes nothing, since whether it would have survived to `t`
# is not observed.
brier_from_definition <- function(res, nested, workflow, i, t) {
  final_workflow <- tune::finalize_workflow(workflow, res$.selected[[i]])
  seed_as_fold(res$.outer_fit_seed[[i]])
  analysis <- rsample::analysis(nested$splits[[i]])
  fit <- parsnip::fit(final_workflow, data = analysis)

  held <- rsample::assessment(nested$splits[[i]])
  predicted <- predict(fit, new_data = held, type = "survival", eval_time = t)
  survival_at_t <- vapply(
    predicted$.pred,
    function(x) x$.pred_survival,
    numeric(1)
  )

  censoring <- survival::survfit(
    survival::Surv(time, 1 - event) ~ 1,
    data = analysis
  )
  g <- stats::stepfun(censoring$time, c(1, censoring$surv))
  weights <- ifelse(
    held$time > t,
    1 / g(t),
    ifelse(held$event == 1, 1 / g(held$time), 0)
  )
  still_alive <- as.numeric(held$time > t)

  # And the same predictions read a second way, through the metric tune calls.
  weighted <- parsnip::.censoring_weights_graf(
    workflows::extract_fit_parsnip(fit),
    dplyr::bind_cols(
      tibble::tibble(surv = survival::Surv(held$time, held$event)),
      predicted
    )
  )

  list(
    defined = mean(weights * (still_alive - survival_at_t)^2),
    yardstick = yardstick::brier_survival(
      weighted,
      truth = surv,
      .pred
    )$.estimate
  )
}

test_that("AC2: the metric each outer fold reports at the named evaluation time is the IPCW Brier score", {
  skip_if_no_censored()

  data <- srv_data()
  nested <- srv_nested(data)
  workflow <- srv_workflow(data)
  t <- srv_eval_times()[[1L]]

  set.seed(9)
  res <- memoised(nested_tune_grid(
    workflow,
    nested,
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = t
  ))

  expect_true(all(res$.completed))

  for (i in seq_len(nrow(nested))) {
    reported <- res$.metrics[[i]]
    expect_identical(reported$.metric, "brier_survival")
    expect_identical(reported$.eval_time, t)

    both <- brier_from_definition(res, nested, workflow, i, t)
    expect_equal(reported$.estimate, both$defined)
    expect_equal(both$yardstick, both$defined)
  }
})

# AC3 -- O2, O3 ---------------------------------------------------------

# One outer fold, rebuilt by hand: the recipe `nested_fold_fit()` follows, run
# from the fold's own inner resamples and split under the seeds the fold
# recorded, at the evaluation time the caller named.
fold_reference <- function(res, nested, workflow, i, eval_time) {
  seed_as_fold(res$.tuning_seed[[i]])
  tuned <- tune::tune_grid(
    workflow,
    resamples = nested$inner_resamples[[i]],
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = eval_time,
    control = tune::control_grid(allow_par = FALSE, event_level = "first")
  )
  metric_name <- tune::.get_tune_metric_names(tuned)[[1L]]
  selected <- suppressWarnings(tune::select_best(tuned, metric = metric_name))

  seed_as_fold(res$.outer_fit_seed[[i]])
  fitted <- tune::last_fit(
    tune::finalize_workflow(workflow, selected),
    split = nested$splits[[i]],
    metrics = srv_metrics(),
    eval_time = eval_time,
    control = tune::control_last_fit(event_level = "first", allow_par = FALSE)
  )
  list(selected = selected, metrics = tune::collect_metrics(fitted))
}

test_that("AC3: two runs differing only in `eval_time` report different metrics, each the one tune produces", {
  skip_if_no_censored()

  data <- srv_data()
  nested <- srv_nested(data)
  workflow <- srv_workflow(data)
  times <- srv_eval_times()

  runs <- lapply(times, function(t) {
    set.seed(9)
    memoised(nested_tune_grid(
      workflow,
      nested,
      grid = srv_grid(),
      metrics = srv_metrics(),
      eval_time = t
    ))
  })

  # The two runs disagree somewhere. Without this every equality below could
  # hold of a run that ignored the argument entirely.
  early <- vapply(runs[[1L]]$.metrics, function(m) m$.estimate, numeric(1))
  late <- vapply(runs[[2L]]$.metrics, function(m) m$.estimate, numeric(1))
  expect_false(isTRUE(all.equal(early, late)))

  for (k in seq_along(times)) {
    for (i in seq_len(nrow(nested))) {
      reference <- fold_reference(runs[[k]], nested, workflow, i, times[[k]])
      expect_identical(
        runs[[k]]$.metrics[[i]]$.estimate,
        reference$metrics$.estimate
      )
      expect_identical(runs[[k]]$.metrics[[i]]$.eval_time, times[[k]])
      expect_identical(runs[[k]]$.selected[[i]]$dist, reference$selected$dist)
    }
  }
})

test_that("AC3: a multi-element `eval_time` reports what its first element names", {
  skip_if_no_censored()

  data <- srv_data()
  nested <- srv_nested(data)
  workflow <- srv_workflow(data)
  times <- srv_eval_times()

  set.seed(9)
  scalar <- memoised(nested_tune_grid(
    workflow,
    nested,
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = times[[1L]]
  ))

  # tune says out loud that it is taking the first of them, once per fold; that
  # message is the behavior under test, not noise to be silenced elsewhere.
  set.seed(9)
  vector_run <- suppressWarnings(memoised(nested_tune_grid(
    workflow,
    nested,
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = times
  )))

  for (i in seq_len(nrow(nested))) {
    reported <- vector_run$.metrics[[i]]
    expect_identical(reported$.eval_time, times)

    at_first <- reported$.estimate[reported$.eval_time == times[[1L]]]
    expect_identical(at_first, scalar$.metrics[[i]]$.estimate)

    # And selection followed the first element too, which is what
    # `tune:::first_eval_time()` does with the same vector.
    expect_identical(
      vector_run$.selected[[i]]$dist,
      scalar$.selected[[i]]$dist
    )
  }
})

# AC4 -- O2 -------------------------------------------------------------

test_that("AC4: nested_final_fit() tunes and selects under the caller's evaluation time", {
  skip_if_no_censored()

  data <- srv_data()
  nested <- srv_nested(data)
  workflow <- srv_workflow(data)
  times <- srv_eval_times()

  fits <- lapply(times, function(t) {
    set.seed(11)
    memoised(nested_final_fit(
      workflow,
      nested,
      grid = srv_grid(),
      metrics = srv_metrics(),
      eval_time = t
    ))
  })

  for (k in seq_along(times)) {
    fit <- fits[[k]]

    # The inner rset is not reachable from the design -- it is drawn inside the
    # tuning seed's scope, from the full data -- so it is rebuilt here from the
    # seed the object recorded, exactly as the documented recipe says.
    seed_as_fold(fit$tuning_seed)
    inner <- rsample::vfold_cv(data, v = 3)
    reference <- tune::tune_grid(
      workflow,
      resamples = inner,
      grid = srv_grid(),
      metrics = srv_metrics(),
      eval_time = times[[k]],
      control = tune::control_grid(allow_par = FALSE, event_level = "first")
    )

    expect_identical(
      tune::collect_metrics(reference),
      tune::collect_metrics(extract_tune_results(fit))
    )
    expect_identical(
      tune::select_best(reference, metric = "brier_survival")$dist,
      fit$selected$dist
    )
  }

  # And the two evaluation times do not merely agree by chance: they rank the
  # candidates differently and choose differently.
  ranked <- lapply(fits, function(fit) {
    scored <- tune::collect_metrics(extract_tune_results(fit))
    scored$dist[order(scored$mean)]
  })
  expect_false(identical(ranked[[1L]], ranked[[2L]]))
  expect_false(identical(fits[[1L]]$selected$dist, fits[[2L]]$selected$dist))
})
