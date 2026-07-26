# Every cli_abort() branch in the orchestrator's argument checks, fired once.
# GP3: a provably invalid design is refused rather than warned about.

valid_folds <- function(d, v = 2) {
  set.seed(1)
  nested_resamples(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = 3)
  )
}

test_that("`object` must be an unfitted workflow", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(parsnip::linear_reg(), folds),
    "must be a"
  )
  expect_error(nested_tune_grid("not a workflow", folds), "must be a")
  expect_error(nested_tune_grid(NULL, folds), "must be a")

  fitted <- parsnip::fit(
    workflows::workflow(y ~ x1 + x2 + x3 + x4, parsnip::linear_reg()),
    data = d
  )
  expect_error(nested_tune_grid(fitted, folds), "already be fitted")
})

test_that("`resamples` must be a nested resampling design", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  expect_error(nested_tune_grid(wf, d), "nested resampling design")
  expect_error(nested_tune_grid(wf, "folds"), "nested resampling design")
  # A plain rset has splits but no inner_resamples: the commonest mistake.
  expect_error(
    nested_tune_grid(wf, rsample::vfold_cv(d, v = 3)),
    "nested resampling design"
  )

  empty <- valid_folds(d)[0, ]
  class(empty) <- class(valid_folds(d))
  expect_error(nested_tune_grid(wf, empty), "no outer folds")
})

test_that("an outer bootstrap is refused, not warned about", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # rsample only warns here, so this design is reachable and has to be caught
  # on the way in (GP3). nested_resamples() refuses it at construction.
  suppressWarnings(
    boot_folds <- rsample::nested_cv(
      d,
      outside = rsample::bootstraps(times = 3),
      inside = rsample::vfold_cv(v = 3)
    )
  )

  expect_error(nested_tune_grid(wf, boot_folds), "cannot use a bootstrap")
})

test_that("`grid` must be candidates or a positive whole number", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(nested_tune_grid(wf, folds, grid = det_grid()[0, , drop = FALSE]),
               "at least one candidate")
  expect_error(nested_tune_grid(wf, folds, grid = 0), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = -1), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = 2.5), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = c(1, 2)), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = NA_integer_), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = "three"), "whole number")
})

test_that("`metrics` must be a metric set or NULL", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(nested_tune_grid(wf, folds, metrics = "rmse"), "metric_set")
  expect_error(nested_tune_grid(wf, folds, metrics = yardstick::rmse),
               "metric_set")
})

test_that("the checks fire before any fitting happens", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # A bad argument costs a second, not a full inner tuning run: the error
  # arrives without the RNG ever being drawn from.
  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_grid(wf, folds, metrics = "rmse"))
  expect_identical(.Random.seed, before)
})
