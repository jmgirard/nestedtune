# Oracle records (DESIGN Conventions: oracles are recorded in the test file
# that asserts them).
#
# O1 -- type "closed-form". Source: the definition of sensitivity, the share of
#   true events the model called events, recomputed here with explicit code
#   from a refit of the fold's selected candidate. Nothing from `tune` computes
#   it, and `yardstick::sens_vec()` is read beside it as a second reading of
#   the same predictions. Pinned by "AC2: the sensitivity each outer fold
#   reports is the one yardstick computes at that event level".
#
# O2 -- type "live" (independent implementation). Source: a `tune::tune_grid()`
#   the test runs itself under `control_grid(allow_par = FALSE, event_level =
#   "second")`, seeded by the by-hand recipe documented at
#   `R/nested-final-fit.R:106-118` -- the object's own `tuning_seed`,
#   kind-pinned, with the inner rset built inside that seed's scope. Pinned by
#   "AC4: nested_final_fit() tunes under the caller's event level".
#
# O3 -- type "invariant". Source: two internal routes that must agree -- on a
#   two-class outcome, sensitivity at one event level is specificity at the
#   other, so the same run at the two settings has to exchange them. Pinned by
#   "AC3: the two levels exchange sensitivity and specificity".
#
# The factor level a caller can name as the event (M35).
#
# Everything here runs on the cls_* fixture (helper-orchestration.R), which is
# built so the setting has something to move: an imbalanced two-class outcome
# with the event first, stratified splits so no assessment set is single-class,
# and a metric set led by `roc_auc` so selection is level-invariant while
# `sens` and `spec` carry the difference. The first test asserts the fixture
# still has those properties -- without it the difference clauses below would
# pass vacuously on a fixture that had drifted.

cls_estimate <- function(res, i, metric) {
  m <- res$.metrics[[i]]
  m$.estimate[m$.metric == metric]
}

# Sensitivity from the definition, with no metric function of any kind: refit
# the fold's selected candidate on its analysis rows under the seed the fold
# recorded, predict the rows it held out, and count.
refit_and_count <- function(res, nested, wf, i, event) {
  final_wf <- tune::finalize_workflow(wf, res$.selected[[i]])
  set.seed(
    res$.outer_fit_seed[[i]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  fit <- parsnip::fit(
    final_wf,
    data = rsample::analysis(nested$splits[[i]])
  )
  held <- rsample::assessment(nested$splits[[i]])
  pred <- predict(fit, held)$.pred_class
  truth <- held$y
  list(
    counted = sum(pred == event & truth == event) / sum(truth == event),
    yardstick = yardstick::sens_vec(
      truth,
      pred,
      event_level = if (event == levels(truth)[[1L]]) "first" else "second"
    )
  )
}

cls_runs <- function(d, nested, wf) {
  set.seed(9)
  first <- memoised(nested_tune_grid(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "first"
  ))
  set.seed(9)
  second <- memoised(nested_tune_grid(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "second"
  ))
  list(first = first, second = second)
}

# The fixture -----------------------------------------------------------

test_that("the fixture keeps both classes in every split, and separates the two metrics", {
  skip_if_no_engines(stochastic = TRUE)

  d <- cls_data()
  nested <- cls_nested(d)

  expect_identical(levels(d$y), c("event", "other"))
  # The event is the minority class: at a balanced outcome sensitivity and
  # specificity sit close together and the difference clauses below would be
  # measuring noise rather than the setting.
  expect_lt(sum(d$y == "event"), sum(d$y == "other"))

  # Every assessment set the design will score against -- the outer sets and
  # each outer fold's inner rset. A single-class one makes sensitivity NA,
  # which takes select_best() down with it.
  for (rset in cls_design_rsets(nested)) {
    expect_identical(missing_assessment_levels(rset), rep("", nrow(rset)))
  }

  runs <- cls_runs(d, nested, cls_workflow(d))
  differs <- vapply(
    seq_len(nrow(nested)),
    function(i) {
      !isTRUE(all.equal(
        cls_estimate(runs$first, i, "sens"),
        cls_estimate(runs$first, i, "spec")
      ))
    },
    logical(1)
  )
  expect_true(any(differs))
})

# AC1 -------------------------------------------------------------------

test_that("AC1: a value that names no level is refused, by both orchestrators", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  bad <- list(
    "third",
    1L,
    c("first", "second"),
    NA_character_
  )

  for (value in bad) {
    for (fn in list(nested_tune_grid, nested_final_fit)) {
      cnd <- tryCatch(
        fn(wf, folds, grid = det_grid(), event_level = value),
        error = function(e) e
      )
      expect_s3_class(cnd, "rlang_error")
      expect_match(
        conditionMessage(cnd),
        "must be .*first.* or .*second"
      )
    }
  }

  # The abort names the function the user called, not a check helper.
  cnd <- tryCatch(
    nested_tune_grid(wf, folds, grid = det_grid(), event_level = "third"),
    error = function(e) e
  )
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_tune_grid")
  expect_match(conditionMessage(cnd), "third", fixed = TRUE)

  cnd <- tryCatch(
    nested_final_fit(wf, folds, grid = det_grid(), event_level = 1L),
    error = function(e) e
  )
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_final_fit")
  expect_match(conditionMessage(cnd), "an integer", fixed = TRUE)
})

test_that("AC1: the refusal fires before anything is fitted", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d, v = 2)

  set.seed(1)
  before <- .Random.seed
  expect_error(
    nested_tune_grid(wf, folds, grid = det_grid(), event_level = "third")
  )
  expect_identical(.Random.seed, before)
})

# AC2 -- O1 -------------------------------------------------------------

test_that("AC2: the sensitivity each outer fold reports is the one yardstick computes at that event level", {
  skip_if_no_engines(stochastic = TRUE)

  d <- cls_data()
  nested <- cls_nested(d)
  wf <- cls_workflow(d)
  runs <- cls_runs(d, nested, wf)

  expect_true(all(runs$first$.completed))
  expect_true(all(runs$second$.completed))

  for (i in seq_len(nrow(nested))) {
    at_first <- refit_and_count(runs$first, nested, wf, i, "event")
    expect_equal(cls_estimate(runs$first, i, "sens"), at_first$counted)
    expect_equal(at_first$yardstick, at_first$counted)

    at_second <- refit_and_count(runs$second, nested, wf, i, "other")
    expect_equal(cls_estimate(runs$second, i, "sens"), at_second$counted)
    expect_equal(at_second$yardstick, at_second$counted)

    # Without this the two halves above could both be reading a run that
    # ignored the setting.
    expect_false(isTRUE(all.equal(
      cls_estimate(runs$first, i, "sens"),
      cls_estimate(runs$second, i, "sens")
    )))
  }
})

# AC3 -- O3 -------------------------------------------------------------

test_that("AC3: the two levels exchange sensitivity and specificity", {
  skip_if_no_engines(stochastic = TRUE)

  d <- cls_data()
  nested <- cls_nested(d)
  runs <- cls_runs(d, nested, cls_workflow(d))

  expect_true(all(runs$first$.completed))
  expect_true(all(runs$second$.completed))

  # Selection has to be level-invariant for the exchange to be an identity
  # rather than a comparison of two different models. Asserted rather than
  # assumed: if a future tune scored roc_auc differently at the two levels
  # this would fail here, and not as an event_level regression below.
  expect_identical(runs$first$.selected, runs$second$.selected)

  for (i in seq_len(nrow(nested))) {
    expect_equal(
      cls_estimate(runs$second, i, "sens"),
      cls_estimate(runs$first, i, "spec")
    )
    expect_equal(
      cls_estimate(runs$second, i, "spec"),
      cls_estimate(runs$first, i, "sens")
    )
  }
})

# AC4 -- O2 -------------------------------------------------------------

test_that("AC4: nested_final_fit() tunes under the caller's event level", {
  skip_if_no_engines(stochastic = TRUE)

  d <- cls_data()
  nested <- cls_nested(d)
  wf <- cls_workflow(d)

  set.seed(11)
  at_first <- memoised(nested_final_fit(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "first"
  ))
  set.seed(11)
  at_second <- memoised(nested_final_fit(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "second"
  ))

  # The inner rset nested_final_fit() draws is not reachable from the design --
  # it is built inside the tuning seed's scope, from the full data -- so the
  # class-presence guard is applied to the reconstruction below rather than to
  # anything the fixture could hand over.
  set.seed(
    at_second$tuning_seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  inner <- rsample::vfold_cv(d, v = 3, strata = y)
  expect_identical(missing_assessment_levels(inner), rep("", nrow(inner)))

  reference <- tune::tune_grid(
    wf,
    resamples = inner,
    grid = cls_grid(),
    metrics = cls_metrics(),
    control = tune::control_grid(allow_par = FALSE, event_level = "second")
  )
  expect_identical(
    tune::collect_metrics(reference),
    tune::collect_metrics(extract_tune_results(at_second))
  )

  # And against the same object built at "first": roc_auc is level-invariant,
  # so it agrees candidate for candidate while sens and spec exchange.
  one <- tune::collect_metrics(extract_tune_results(at_first))
  two <- tune::collect_metrics(extract_tune_results(at_second))
  expect_false(identical(one, two))

  key <- function(m, metric) {
    rows <- m[m$.metric == metric, ]
    stats::setNames(rows$mean, rows$min_n)
  }
  expect_identical(key(one, "roc_auc"), key(two, "roc_auc"))
  expect_equal(key(one, "sens"), key(two, "spec"))
  expect_equal(key(one, "spec"), key(two, "sens"))
  # At least one candidate whose two estimates differ, without which the
  # exchange above is satisfied by any implementation at all.
  expect_true(any(key(one, "sens") != key(one, "spec")))
})
