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
  memoised(nested_tune_grid(wf, folds, grid = det_grid(), metrics = metrics))
}

test_that("the results object retains one row per outer fold with its selection", {
  skip_if_no_engines()

  res <- example_results()

  expect_s3_class(res, "nested_results")
  expect_identical(nrow(res), 3L)
  expect_true(all(
    c(
      "splits",
      "id",
      ".metrics",
      ".selected",
      ".tuning_seed",
      ".outer_fit_seed"
    ) %in%
      names(res)
  ))

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

  expect_identical(
    names(summarized),
    c(".metric", ".estimator", "mean", "n", "std_err")
  )
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

  expect_identical(
    names(per_fold),
    c("id", ".metric", ".estimator", ".estimate")
  )
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

test_that("a fold scoring NA is dropped from the summary rather than poisoning it", {
  skip_if_no_engines()

  res <- example_results()
  # The real route here is an outer assessment set with a single class, where
  # last_fit() returns roc_auc = NA. The shape is what matters, so it is
  # injected rather than contrived out of imbalanced data.
  is_rmse <- res$.metrics[[1]]$.metric == "rmse"
  res$.metrics[[1]]$.estimate[is_rmse] <- NA_real_

  summarized <- collect_metrics(res)
  rmse <- summarized[summarized$.metric == "rmse", ]
  rsq <- summarized[summarized$.metric == "rsq", ]

  # n counts the folds that actually contributed, so the row never reports no
  # estimate while claiming every fold was in it.
  expect_identical(rmse$n, 2L)
  expect_false(is.na(rmse$mean))
  expect_identical(rsq$n, 3L)

  per_fold <- collect_metrics(res, summarize = FALSE)
  vals <- per_fold$.estimate[per_fold$.metric == "rmse"]
  expect_equal(rmse$mean, mean(vals[!is.na(vals)]))
  expect_equal(rmse$std_err, stats::sd(vals[!is.na(vals)]) / sqrt(2))
})

test_that("a metric that is NA in every fold summarizes to NA with n = 0", {
  skip_if_no_engines()

  res <- example_results()
  for (i in seq_len(nrow(res))) {
    is_rmse <- res$.metrics[[i]]$.metric == "rmse"
    res$.metrics[[i]]$.estimate[is_rmse] <- NA_real_
  }

  summarized <- collect_metrics(res)
  rmse <- summarized[summarized$.metric == "rmse", ]

  expect_identical(rmse$n, 0L)
  expect_true(is.na(rmse$mean))
  expect_true(is.na(rmse$std_err))
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

test_that("the object carries the grid and metrics it was asked to run", {
  skip_if_no_engines()

  # IP4: the object records what was asked for, positively, rather than leaving
  # it to be inferred. Until M20 both attributes were written by
  # new_nested_results() and read by nothing, so either could be dropped
  # without a test noticing.
  #
  # The metric set is bound ONCE and compared to that binding. Two
  # metric_set() calls are never identical() -- the closure environment refers
  # to itself and identical() compares environments by reference, the same
  # cycle helper-orchestration.R's canonical_form() exists to cut -- so
  # comparing against a second reg_metrics() call fails against correct code.
  metrics <- reg_metrics()
  grid <- det_grid()
  d <- make_reg_data()
  wf <- det_workflow(d)
  set.seed(1)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(55)
  res <- nested_tune_grid(wf, folds, grid = grid, metrics = metrics)

  expect_identical(attr(res, "grid"), grid)
  expect_identical(attr(res, "metrics"), metrics)

  # Both describe the call rather than the rows, so an operation the invariants
  # allow keeps them as they are. Reordering the folds is such an operation:
  # the folds are a set, and rearranging them changes nothing the object claims.
  reordered <- res[rev(seq_len(nrow(res))), ]
  expect_s3_class(reordered, "nested_results")
  expect_identical(attr(reordered, "grid"), grid)
  expect_identical(attr(reordered, "metrics"), metrics)
  expect_identical(reordered$id, rev(res$id))

  # Dropping the two seed columns used to keep the class, on the ground that
  # has_results_columns() does not name them. M36 widened the set an operation
  # must leave alone to every column the constructor writes, so it no longer
  # does -- and the call's record goes with the class rather than staying
  # readable on the tibble that comes back.
  cols <- setdiff(names(res), c(".tuning_seed", ".outer_fit_seed"))
  narrowed <- res[, cols]
  expect_false(inherits(narrowed, "nested_results"))
  expect_null(attr(narrowed, "grid"))
  expect_null(attr(narrowed, "metrics"))
})

test_that("each fold records the candidates its inner tuning actually scored", {
  skip_if_no_engines()

  # IP4 asks for "the grid actually evaluated", which the `grid` attribute
  # cannot supply: it holds the request, so a size request records a number and
  # never the candidates. This column is the record, per fold because folds can
  # genuinely disagree (measured at M21's plan gate: integer-grid expansion is
  # stochastic for a continuous parameter, and each fold tunes under its own
  # seed).
  grid <- det_grid()
  res <- example_results()

  expect_true(".grid" %in% names(res))
  expect_type(res$.grid, "list")
  expect_length(res$.grid, 3L)

  for (g in res$.grid) {
    expect_true(is.data.frame(g))
    expect_identical(nrow(g), nrow(grid))
    expect_true(all(c("num_comp", ".config") %in% names(g)))

    # Compared by the shared parameter column, NEVER by .config. tune renumbers
    # .config into ascending parameter order, so a request frame given in any
    # other order fails a .config-ordered comparison on a set that is identical
    # (measured at M21's criteria audit, tune 2.1.0). Sorting the parameter
    # values is the comparison that holds for any request order.
    expect_identical(sort(g$num_comp), sort(grid$num_comp))
  }
})

test_that("the evaluated-candidate record travels with the rows it describes", {
  skip_if_no_engines()

  # Unlike the `grid` attribute, this record describes the rows rather than the
  # call -- so it is a column, and a row subset carries each fold's own record
  # rather than the parent's. An attribute could not do this: M20 measured that
  # arbitrary attributes survive a row subset untouched, which is exactly the
  # stale-parent claim IP4 forbids.
  res <- example_results()

  subset <- res[2:3, ]
  expect_length(subset$.grid, 2L)
  expect_identical(subset$.grid, res$.grid[2:3])
})

test_that("a run given no metric set carries no metrics attribute", {
  skip_if_no_engines()

  # `attr(x, "metrics") <- NULL` DELETES the attribute rather than storing a
  # NULL, so the default run is the case where the attribute is absent. Pinned
  # so the test above cannot be weakened into passing on a NULL-metrics run,
  # where every assertion in it holds vacuously.
  res <- example_results(metrics = NULL)

  expect_false("metrics" %in% names(attributes(res)))
  expect_null(attr(res, "metrics"))
})
