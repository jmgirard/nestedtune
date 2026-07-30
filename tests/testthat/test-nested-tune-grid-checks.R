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

# A preprocessor-only workflow used to fail from inside
# workflows::extract_spec_parsnip(), which check_workflow() calls -- so the
# message was workflows' and conditionCall() named an internal call the user
# never wrote, where every other bad-`object` shape names theirs.

test_that("a workflow carrying no model spec is refused by nestedtune", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)
  prep_only <- workflows::workflow(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d)
  )

  expect_error(nested_tune_grid(prep_only, folds), "no model specification")
  expect_error(nested_tune_grid(workflows::workflow(), folds),
               "no model specification")

  cnd <- tryCatch(nested_tune_grid(prep_only, folds), error = function(e) e)
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
  # The remedy, not just a bullet: GP3 refuses, and every other check says how
  # to stop being refused.
  expect_match(conditionMessage(cnd), "add_model")
})

test_that("the workflow's engine packages must be installed", {
  skip_if_no_engines()
  # A real engine that is almost certainly absent. Skipped rather than
  # asserted if it happens to be installed.
  skip_if(rlang::is_installed("kknn"))

  d <- make_reg_data()
  folds <- valid_folds(d)

  missing_engine <- workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    parsnip::set_mode(
      parsnip::set_engine(parsnip::nearest_neighbor(), "kknn"),
      "regression"
    )
  )
  expect_error(nested_tune_grid(missing_engine, folds), "not installed")
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

test_that("`resamples` must name its outer folds", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # Splits and inner resamples but no id column. Without this check the whole
  # loop runs and only then assembles a results object whose columns disagree
  # in length -- every fold's compute spent before anything complains.
  no_id <- data.frame(row.names = seq_len(nrow(folds)))
  no_id$splits <- folds$splits
  no_id$inner_resamples <- folds$inner_resamples

  expect_error(nested_tune_grid(wf, no_id, grid = det_grid()), "no id column")
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

# The grid is judged against the workflow up front (M03). Both directions are
# wrong for every fold rather than for one, so both are call errors -- and once
# fold failures are recorded rather than raised, an unchecked grid would show up
# as an entire design failing instead.

test_that("a grid column not marked for tuning is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2)),
    "not marked for tuning"
  )
  # Named, so the caller knows which column to fix.
  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2)),
    "not_a_param"
  )
})

test_that("a tuned parameter with no grid column is refused", {
  skip_if_no_engines()
  skip_if_not_installed("dials")

  d <- make_reg_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = tune::tune()),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  skip_if_not_installed("ranger")
  wf <- workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(min_n = c(2L, 10L))),
    "no column for"
  )
  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(min_n = c(2L, 10L))),
    "trees"
  )
})

test_that("a grid given as a size is not held to the column check", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # There are no columns to judge yet; tune generates them.
  expect_no_error(check_grid_params(wf, 5))
})

test_that("the grid check fires before any fitting happens", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2)))
  expect_identical(.Random.seed, before)
})
