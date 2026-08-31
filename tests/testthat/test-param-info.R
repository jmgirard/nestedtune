# `param_info` reaching tune, demonstrated by what it changes (M34, AC3).
#
# The test is behavioural rather than a capture of the argument at the boundary:
# a capture asserts the harness saw the value, not that tune acted on it, and a
# mocked binding never reaches a mirai daemon at all (plan gate, 2026-08-30).
# What is asserted instead is the one thing forwarding buys -- a restricted
# range restricts the grid every fold searches -- with the unrestricted run
# beside it as the control that shows the restriction is doing the work.

NARROW_THRESHOLD <- c(0.05, 0.15)

narrow_param_info <- function(wf) {
  update(
    tune::extract_parameter_set_dials(wf),
    threshold = dials::threshold(NARROW_THRESHOLD)
  )
}

selected_thresholds <- function(res) {
  vapply(res$.selected[res$.completed], function(x) x$threshold, numeric(1))
}

test_that("AC3: param_info restricts what every outer fold selects", {
  skip_if_no_engines()
  skip_if_not_installed("dials")

  d <- make_reg_data()
  nested <- det_nested(d)
  # The continuous tunable, not the integer one: `num_comp` reaches only as
  # many values as there are predictors, so a "narrow" range for it is most of
  # the parameter space and the two grids would not separate.
  wf <- cont_workflow(d)

  # An integer `grid`, so tune generates the candidates from `param_info` --
  # a data-frame grid would carry its own values and forwarding would change
  # nothing to observe.
  set.seed(7)
  unrestricted <- memoised(nested_tune_grid(
    wf,
    nested,
    grid = 5,
    metrics = reg_metrics()
  ))
  set.seed(7)
  restricted <- memoised(nested_tune_grid(
    wf,
    nested,
    param_info = narrow_param_info(wf),
    grid = 5,
    metrics = reg_metrics()
  ))

  expect_true(all(restricted$.completed))
  expect_true(all(unrestricted$.completed))

  restricted_values <- selected_thresholds(restricted)
  expect_length(restricted_values, nrow(nested))
  expect_true(all(restricted_values >= NARROW_THRESHOLD[[1L]]))
  expect_true(all(restricted_values <= NARROW_THRESHOLD[[2L]]))

  # The control. Without it the assertion above is satisfied by a `threshold`
  # that happens to live in that interval anyway, and forwarding nothing at all
  # would pass.
  unrestricted_values <- selected_thresholds(unrestricted)
  expect_true(any(unrestricted_values > NARROW_THRESHOLD[[2L]]))
})

test_that("AC3: param_info restricts what the final fit selects", {
  skip_if_no_engines()
  skip_if_not_installed("dials")

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- cont_workflow(d)

  set.seed(7)
  unrestricted <- memoised(nested_final_fit(
    wf,
    folds,
    grid = 5,
    metrics = reg_metrics()
  ))
  set.seed(7)
  restricted <- memoised(nested_final_fit(
    wf,
    folds,
    param_info = narrow_param_info(wf),
    grid = 5,
    metrics = reg_metrics()
  ))

  expect_gte(restricted$selected$threshold, NARROW_THRESHOLD[[1L]])
  expect_lte(restricted$selected$threshold, NARROW_THRESHOLD[[2L]])
  expect_gt(unrestricted$selected$threshold, NARROW_THRESHOLD[[2L]])
})

test_that("a param_info that is not a parameters object is refused up front", {
  skip_if_no_engines()

  d <- make_reg_data()
  nested <- det_nested(d)
  wf <- det_workflow(d)

  # Named for the argument and raised by the entry point, which is the whole
  # reason the check is here rather than left to tune: it fires before any fold
  # is fitted.
  expect_error(
    nested_tune_grid(wf, nested, param_info = "wide", grid = det_grid()),
    "`param_info` must be"
  )
  expect_error(
    nested_final_fit(wf, nested, param_info = "wide", grid = det_grid()),
    "`param_info` must be"
  )
})
