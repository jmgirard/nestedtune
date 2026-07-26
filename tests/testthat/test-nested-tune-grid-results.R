example_results <- function(v = 3, metrics = reg_metrics(), seed = 55) {
  d <- make_reg_data()
  wf <- det_workflow(d)
  set.seed(1)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(seed)
  nested_tune_grid(wf, folds, grid = det_grid(), metrics = metrics)
}

test_that("the results object retains one row per outer fold with its selection", {
  skip_if_no_engines()

  res <- example_results()

  expect_s3_class(res, "nested_results")
  expect_identical(nrow(res), 3L)
  expect_true(all(c("splits", "id", ".metrics", ".selected",
                    ".tuning_seed", ".outer_fit_seed") %in% names(res)))

  # Selection instability is the thing nothing else in the ecosystem keeps.
  for (sel in res$.selected) {
    expect_true(is.data.frame(sel))
    expect_identical(nrow(sel), 1L)
    expect_true("num_comp" %in% names(sel))
  }
  expect_type(res$.tuning_seed, "integer")
  expect_type(res$.outer_fit_seed, "integer")
})

test_that("collect_metrics() summarizes across outer folds", {
  skip_if_no_engines()

  res <- example_results()
  summarized <- collect_metrics(res)

  expect_identical(names(summarized),
                   c(".metric", ".estimator", "mean", "n", "std_err"))
  expect_setequal(summarized$.metric, c("rmse", "rsq"))
  expect_true(all(summarized$n == 3L))

  # The summary is the mean of the per-fold estimates, computed the dumb way.
  per_fold <- collect_metrics(res, summarize = FALSE)
  for (m in summarized$.metric) {
    expect_equal(
      summarized$mean[summarized$.metric == m],
      mean(per_fold$.estimate[per_fold$.metric == m])
    )
    vals <- per_fold$.estimate[per_fold$.metric == m]
    expect_equal(
      summarized$std_err[summarized$.metric == m],
      stats::sd(vals) / sqrt(length(vals))
    )
  }
})

test_that("collect_metrics(summarize = FALSE) returns one row per fold and metric", {
  skip_if_no_engines()

  res <- example_results()
  per_fold <- collect_metrics(res, summarize = FALSE)

  expect_identical(names(per_fold),
                   c("id", ".metric", ".estimator", ".estimate"))
  expect_identical(nrow(per_fold), 6L)
  expect_setequal(per_fold$id, res$id)
})

test_that("a single outer fold gives an NA standard error rather than an error", {
  skip_if_no_engines()

  res <- example_results(v = 2)
  # Two folds still admit an SE; the guard is for the degenerate case, which
  # is reached by summarizing a one-row object.
  one <- res[1, ]
  class(one) <- class(res)
  summarized <- collect_metrics(one)

  expect_true(all(is.na(summarized$std_err)))
  expect_true(all(summarized$n == 1L))
})

test_that("the results object is not a tune_results, so tune's selectors refuse it", {
  skip_if_no_engines()

  res <- example_results()

  expect_false(inherits(res, "tune_results"))
  # show_best()/select_best() on outer folds would rank folds against each
  # other and return something authoritative-looking and meaningless (D-010).
  expect_error(tune::select_best(res))
  expect_error(tune::show_best(res))
})

test_that("metrics = NULL falls back to tune's defaults", {
  skip_if_no_engines()

  res <- example_results(metrics = NULL)
  summarized <- collect_metrics(res)

  expect_setequal(summarized$.metric, c("rmse", "rsq"))
})
