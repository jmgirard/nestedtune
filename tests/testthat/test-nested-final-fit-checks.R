# Every cli_abort() branch on the final-fit path, fired once (AC5, AC11).
#
# The shared checks are exercised through nested_final_fit() rather than assumed
# from nested_tune_grid()'s suite: a check that is not wired into the new
# function passes its own tests and refuses nothing here.

valid_folds <- function(d, v = 2) {
  set.seed(1)
  nested_resamples(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = 3)
  )
}

test_that("the shared argument checks are wired into the final fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)
  wf <- det_workflow(d)

  expect_error(nested_final_fit("not a workflow", folds), "must be a")
  expect_error(
    nested_final_fit(
      parsnip::fit(
        workflows::workflow(y ~ x1 + x2 + x3 + x4, parsnip::linear_reg()),
        data = d
      ),
      folds
    ),
    "already be fitted"
  )
  expect_error(nested_final_fit(wf, "not a design"), "nested resampling design")
  expect_error(nested_final_fit(wf, folds[0, ]), "no outer folds")
  expect_error(
    nested_final_fit(wf, folds, grid = data.frame(nope = 1:2)),
    "not marked for tuning"
  )
  expect_error(nested_final_fit(wf, folds, grid = 0), "positive whole number")
  expect_error(nested_final_fit(wf, folds, metrics = "rmse"), "metric_set")

  prep_only <- workflows::workflow(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d)
  )
  expect_error(nested_final_fit(prep_only, folds), "no model specification")
  cnd <- tryCatch(nested_final_fit(prep_only, folds), error = function(e) e)
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("the remaining shared abort branches fire through the final fit too", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)
  wf <- det_workflow(d)

  # A design with the two required columns but no id column.
  no_id <- data.frame(row.names = seq_len(nrow(folds)))
  no_id$splits <- folds$splits
  no_id$inner_resamples <- folds$inner_resamples
  attr(no_id, "inside") <- attr(folds, "inside")
  expect_error(nested_final_fit(wf, no_id, grid = det_grid()), "no id column")

  # rsample only warns for an outer bootstrap, so the design is reachable.
  suppressWarnings(
    boot_folds <- rsample::nested_cv(
      d,
      outside = rsample::bootstraps(times = 3),
      inside = rsample::vfold_cv(v = 3)
    )
  )
  expect_error(nested_final_fit(wf, boot_folds), "cannot use a bootstrap")

  expect_error(
    nested_final_fit(wf, folds, grid = det_grid()[0, , drop = FALSE]),
    "at least one candidate"
  )
})

test_that("a tuned parameter with no grid column is refused by the final fit", {
  skip_if_no_engines(stochastic = TRUE)
  skip_if_not_installed("dials")

  d <- make_reg_data()
  folds <- valid_folds(d)
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = tune::tune()),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  wf <- workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)

  expect_error(
    nested_final_fit(wf, folds, grid = data.frame(min_n = c(2L, 10L))),
    "no column for"
  )
})

test_that("a missing engine package is refused by the final fit", {
  skip_if_no_engines()
  # A real engine that is almost certainly absent; skipped rather than
  # asserted if it happens to be installed.
  skip_if(rlang::is_installed("kknn"))

  d <- make_reg_data()
  folds <- valid_folds(d)
  missing_engine <- workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    parsnip::set_mode(
      parsnip::set_engine(
        parsnip::nearest_neighbor(neighbors = tune::tune()),
        "kknn"
      ),
      "regression"
    )
  )

  expect_error(
    nested_final_fit(missing_engine, folds, grid = data.frame(neighbors = 3L)),
    "not installed"
  )
})

test_that("a design carrying no inner specification is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)
  wf <- det_workflow(d)

  # What a hand-assembled design looks like: the columns are all there, so
  # every other check passes, and only the missing specification stops it.
  attr(folds, "inside") <- NULL

  expect_error(
    nested_final_fit(wf, folds),
    "no inner resampling specification"
  )
})

test_that("an inner specification that cannot be re-evaluated names itself", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Built inside a function, so `v` is gone by the time the final fit tries to
  # re-evaluate the call the design stored (RR02 B1).
  folds <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })

  expect_error(
    nested_final_fit(wf, folds),
    "could not be\\s+re-evaluated"
  )
  # The message names the call it tried, which is the only way a reader can
  # tell which variable went missing.
  expect_error(nested_final_fit(wf, folds), "vfold_cv")
})

test_that("an inner specification that is not an rset is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # Evaluates cleanly and hands back something that is not a resampling
  # object, which is a different failure from one that errors outright.
  attr(folds, "inside") <- quote(data.frame())

  expect_error(nested_final_fit(wf, folds), "did not produce an")
})

# The design-column checks reach the final fit too (M19).
#
# The final fit reads only `splits[[1]]$data` and never touches
# `inner_resamples` at all, so neither of these refusals is needed to make it
# work. They are here because "is this design valid" gets one answer, not one
# per entry point: a user who saw every outer fold fail should not then be
# handed a model built from the same object. What stays final-fit-only is the
# check the loop genuinely has no use for -- `check_inside_spec()`.

test_that("a non-rset element of inner_resamples is refused by the final fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$inner_resamples[[2]] <- "not an rset"

  expect_error(nested_final_fit(wf, bad, grid = det_grid()), "inner_resamples")
  cnd <- tryCatch(nested_final_fit(wf, bad, grid = det_grid()),
                  error = function(e) e)
  # The position and the type held, asserted here and not only through the
  # loop's suite: a wrong index or a dropped type reddens both drivers or
  # neither, and only the loop's copy would have caught it.
  expect_match(conditionMessage(cnd), "Element 2")
  expect_match(conditionMessage(cnd), "string")
  expect_match(conditionMessage(cnd), "`resamples`")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("a non-rsplit element of splits is refused by the final fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$splits[[1]] <- "not an rsplit"

  # Before this the final fit reached split_data() and died in base R:
  # "$ operator is invalid for atomic vectors", naming no argument of ours.
  cnd <- tryCatch(nested_final_fit(wf, bad, grid = det_grid()),
                  error = function(e) e)
  expect_match(conditionMessage(cnd), "rsplit")
  expect_match(conditionMessage(cnd), "Element 1")
  expect_match(conditionMessage(cnd), "string")
  expect_match(conditionMessage(cnd), "`resamples`")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("a workflow with a model but no preprocessor is refused by the final fit", {
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

  cnd <- tryCatch(
    nested_final_fit(model_only, folds, grid = data.frame(min_n = c(2L, 10L))),
    error = function(e) e
  )
  expect_match(conditionMessage(cnd), "no preprocessor")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

# eval_inside_spec()'s two aborts named final_fit_worker() -- an internal frame
# the user never wrote -- where check_inside_spec() beside it already named the
# user's call. Same defect class M18 removed from check_workflow().

test_that("the inner-specification aborts name the user's call", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Could not be re-evaluated: `v` is gone by the time the design is re-run.
  gone <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })
  cnd <- tryCatch(nested_final_fit(wf, gone), error = function(e) e)
  expect_match(conditionMessage(cnd), "could not be\\s+re-evaluated")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))

  # Evaluated cleanly, produced something that is not an rset.
  not_rset <- valid_folds(d)
  attr(not_rset, "inside") <- quote(data.frame())
  cnd <- tryCatch(nested_final_fit(wf, not_rset), error = function(e) e)
  expect_match(conditionMessage(cnd), "did not produce an")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})
