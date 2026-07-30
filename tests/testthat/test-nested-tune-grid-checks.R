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

  # The two shapes get different bullets: an empty workflow carries no
  # preprocessor either, and saying it does would describe the wrong object.
  expect_match(
    conditionMessage(tryCatch(nested_tune_grid(prep_only, folds),
                              error = function(e) e)),
    "carries a preprocessor only"
  )
  expect_match(
    conditionMessage(tryCatch(nested_tune_grid(workflows::workflow(), folds),
                              error = function(e) e)),
    "is empty"
  )

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

# The two list columns are checked element by element (M19). Before this, a bad
# element was not a call error at all: tune raised it once per fold, so the run
# cost a full pass and came back as an all-folds-failed object carrying tune's
# message rather than ours -- the shape check_grid_params() already prevents for
# a malformed grid.

test_that("a non-rset element of inner_resamples is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$inner_resamples[[2]] <- "not an rset"

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "inner_resamples")
  cnd <- tryCatch(nested_tune_grid(wf, bad, grid = det_grid()),
                  error = function(e) e)
  # The position, so a design with many folds says which one to look at.
  expect_match(conditionMessage(cnd), "2")
  expect_match(conditionMessage(cnd), "rset")
  # What it holds instead, so the reader is not left guessing.
  expect_match(conditionMessage(cnd), "string")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
})

test_that("a non-rsplit element of splits is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$splits[[1]] <- "not an rsplit"

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "splits")
  cnd <- tryCatch(nested_tune_grid(wf, bad, grid = det_grid()),
                  error = function(e) e)
  expect_match(conditionMessage(cnd), "rsplit")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
})

# The reachable route to such a design is not hand-editing: rsample's own
# constructor admits an `inside` that produces no rset, where nested_resamples()
# refuses it at construction (M18).

test_that("an rsample design whose inside produced no rset is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  set.seed(1)
  bad <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = list()
  )

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "inner_resamples")
})

# The negative half of the same rule: what the loop does not need, it does not
# check. A design carrying no `inside` attribute cannot be re-run by the final
# fit, and the loop is indifferent to that -- it never re-evaluates anything.

test_that("the loop still accepts a design with no inner specification", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)
  attr(folds, "inside") <- NULL

  res <- memoised(nested_tune_grid(wf, folds, grid = det_grid()))
  expect_true(all(res$.completed))
})

test_that("a workflow with a model but no preprocessor is refused", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- valid_folds(d)
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = 10),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  model_only <- workflows::add_model(workflows::workflow(), spec)

  expect_error(
    nested_tune_grid(model_only, folds, grid = data.frame(min_n = c(2L, 10L))),
    "no preprocessor"
  )
  cnd <- tryCatch(
    nested_tune_grid(model_only, folds, grid = data.frame(min_n = c(2L, 10L))),
    error = function(e) e
  )
  # The remedy, as the neighbouring `object` checks give one.
  expect_match(conditionMessage(cnd), "add_formula|add_recipe|add_variables")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
})

# Every refusal added here fires before the entry sample.int() draw. Seed
# *identity* cannot show this: both drivers install their restoring on.exit()
# before drawing, so .Random.seed is put back on every exit path including one
# that already drew and re-seeded. What discriminates is existence -- a session
# that has never drawn has no .Random.seed, and restore_rng() deliberately
# leaves in place any state it created.

test_that("the new refusals fire before the RNG is drawn from", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  refused <- list(
    function() {
      bad <- folds
      bad$inner_resamples[[2]] <- "not an rset"
      nested_tune_grid(wf, bad, grid = det_grid())
    },
    function() {
      bad <- folds
      bad$splits[[1]] <- "not an rsplit"
      nested_tune_grid(wf, bad, grid = det_grid())
    },
    function() {
      bad <- folds
      bad$inner_resamples[[2]] <- "not an rset"
      nested_final_fit(wf, bad, grid = det_grid())
    }
  )

  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv())
  withr::defer(
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  )

  for (refuse in refused) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
    expect_error(refuse())
    expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  }
})
