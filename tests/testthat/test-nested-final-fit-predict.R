# `predict()` and `augment()` on a `nested_final_fit` (AC1-AC4, AC6).
#
# Oracle provenance: none is claimed here and none is owed. Both methods
# delegate to the trained workflow the object carries, so the reference for
# each assertion is the same call made on `extract_workflow(final)` -- the
# contract is "what the workflow gives", asserted as `identical()`, never a
# number of this package's own.

# Fixtures ---------------------------------------------------------------

# The regression final fit, on the same seed test-nested-final-fit-extract.R
# uses so the two files share one cache entry.
reg_final <- function() {
  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)
  set.seed(21)
  memoised(nested_final_fit(wf, res))
}

# The classification final fit, as test-event-level.R builds one.
cls_final <- function() {
  d <- cls_data()
  nested <- cls_nested(d)
  wf <- cls_workflow(d)
  res <- memoised(nested_tune_grid(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "first"
  ))
  set.seed(11)
  memoised(nested_final_fit(wf, res))
}

# The censored-regression final fit, as test-eval-time.R builds one.
srv_final <- function() {
  data <- srv_data()
  nested <- srv_nested(data)
  workflow <- srv_workflow(data)
  res <- memoised(nested_tune_grid(
    workflow,
    nested,
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = srv_eval_times()[[1L]]
  ))
  set.seed(11)
  memoised(nested_final_fit(workflow, res))
}

# AC1 -------------------------------------------------------------------

test_that("AC1: predict() on the regression fit is the workflow's prediction", {
  skip_if_no_engines()

  final <- reg_final()
  wf <- extract_workflow(final)
  d <- make_reg_data()

  expect_identical(
    predict(final, new_data = d),
    predict(wf, new_data = d)
  )
  expect_identical(
    predict(final, new_data = d, type = "conf_int", level = 0.9),
    predict(wf, new_data = d, type = "conf_int", level = 0.9)
  )
  # The control: `level` reached the model, so the interval it names differs
  # from the default one.
  expect_false(identical(
    predict(final, new_data = d, type = "conf_int", level = 0.9),
    predict(final, new_data = d, type = "conf_int")
  ))
})

test_that("AC1: predict() on the classification fit is the workflow's prediction", {
  skip_if_no_engines(stochastic = TRUE)

  final <- cls_final()
  wf <- extract_workflow(final)
  d <- cls_data()

  expect_identical(
    predict(final, new_data = d, type = "class"),
    predict(wf, new_data = d, type = "class")
  )
  expect_identical(
    predict(final, new_data = d, type = "prob"),
    predict(wf, new_data = d, type = "prob")
  )
  # The control: the two types come back in different shapes, so `type`
  # reached the model.
  expect_named(predict(final, new_data = d, type = "class"), ".pred_class")
  expect_named(
    predict(final, new_data = d, type = "prob"),
    c(".pred_event", ".pred_other")
  )
})

test_that("AC1: predict() on the censored fit is the workflow's prediction", {
  skip_if_no_censored()

  final <- srv_final()
  wf <- extract_workflow(final)
  d <- srv_data()
  times <- srv_eval_times()

  expect_identical(
    predict(final, new_data = d, type = "survival", eval_time = times),
    predict(wf, new_data = d, type = "survival", eval_time = times)
  )
  # The control: both evaluation times reached the model.
  got <- predict(final, new_data = d, type = "survival", eval_time = times)
  expect_identical(got$.pred[[1L]]$.eval_time, times)
})

# AC2 -------------------------------------------------------------------

test_that("AC2: augment() on the regression fit is the workflow's augmentation", {
  skip_if_no_engines()

  final <- reg_final()
  d <- make_reg_data()

  expect_identical(
    augment(final, new_data = d),
    augment(extract_workflow(final), new_data = d)
  )
  expect_true(all(c(".pred", ".resid", "y") %in% names(augment(final, d))))
})

test_that("AC2: augment() on the classification fit is the workflow's augmentation", {
  skip_if_no_engines(stochastic = TRUE)

  final <- cls_final()
  d <- cls_data()

  expect_identical(
    augment(final, new_data = d),
    augment(extract_workflow(final), new_data = d)
  )
  expect_true(all(c(".pred_class", ".pred_event") %in% names(augment(final, d))))
})

test_that("AC2: augment() on the censored fit is the workflow's augmentation", {
  skip_if_no_censored()

  final <- srv_final()
  d <- srv_data()
  times <- srv_eval_times()

  expect_identical(
    augment(final, new_data = d, eval_time = times),
    augment(extract_workflow(final), new_data = d, eval_time = times)
  )
  # The control: `eval_time` reached the model.
  got <- augment(final, new_data = d, eval_time = times)
  expect_identical(got$.pred[[1L]]$.eval_time, times)
})

# AC3 -------------------------------------------------------------------

test_that("AC3: predict() forwards an unknown argument to parsnip's refusal", {
  skip_if_no_engines()

  final <- reg_final()
  d <- make_reg_data()

  cnd <- rlang::catch_cnd(predict(final, new_data = d, nonesuch = 1))
  expect_s3_class(cnd, "error")
  # parsnip's wording (check_pred_type_dots(), parsnip 1.6.0), which names the
  # offending argument.
  expect_match(conditionMessage(cnd), "nonesuch")
  expect_match(
    conditionMessage(cnd),
    "not used to pass args to the model function's predict function"
  )
})

test_that("AC3: predict() without `new_data` raises the workflow's own error", {
  skip_if_no_engines()

  final <- reg_final()

  ours <- rlang::catch_cnd(predict(final))
  theirs <- rlang::catch_cnd(predict(extract_workflow(final)))
  expect_s3_class(ours, "error")
  expect_s3_class(theirs, "error")
  expect_identical(conditionMessage(ours), conditionMessage(theirs))
  expect_match(conditionMessage(ours), "new_data")
})

test_that("AC3: augment() refuses an argument it does not know", {
  skip_if_no_engines()

  final <- reg_final()
  d <- make_reg_data()

  cnd <- rlang::catch_cnd(augment(final, new_data = d, nonesuch = 1))
  expect_s3_class(cnd, "rlib_error_dots_nonempty")
  expect_identical(rlang::call_name(conditionCall(cnd)), "augment")
})

# AC4 -------------------------------------------------------------------

test_that("AC4: augment is re-exported, so the call works with tune unattached", {
  skip_if_no_engines()

  expect_false("package:tune" %in% search())
  expect_true("augment" %in% getNamespaceExports("nestedtune"))

  final <- reg_final()
  d <- make_reg_data()
  expect_identical(
    nestedtune::augment(final, new_data = d),
    augment(extract_workflow(final), new_data = d)
  )
})

# AC6 -------------------------------------------------------------------

test_that("AC6: tune's ranking and collecting generics still refuse the object", {
  skip_if_no_engines()

  final <- reg_final()

  for (fn in list(tune::collect_metrics, tune::show_best, tune::select_best)) {
    cnd <- rlang::catch_cnd(fn(final))
    expect_s3_class(cnd, "error")
    expect_match(conditionMessage(cnd), "no applicable method")
  }

  reg <- getNamespaceInfo(asNamespace("nestedtune"), "S3methods")
  on_final <- reg[reg[, 2L] == "nested_final_fit", 1L]
  expect_false(any(c("collect_metrics", "show_best", "select_best") %in% on_final))
  # The registry read has a domain: the class does carry methods of ours.
  expect_true("extract_workflow" %in% on_final)
})
