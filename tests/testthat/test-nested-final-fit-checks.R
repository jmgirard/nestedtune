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
