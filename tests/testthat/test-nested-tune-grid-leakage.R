# IP1 -- no leakage across the outer boundary. The property is checked, not
# asserted: the rows the driver actually hands to inner tuning and to the outer
# fit are compared against the rows that fold holds out.
#
# The orchestrator's own failure mode is pairing: handing fold i's split to
# fold j's inner resamples would leak while every individual object stayed
# valid, and no inspection of the result would show it. So the handoff is
# instrumented, not just the structure M01 built.

record_handoffs <- function(wf, folds, grid, metrics) {
  seen <- list()
  stub <- function(
    split,
    inner,
    seeds,
    object,
    grid,
    metrics,
    param_info,
    event_level
  ) {
    seen[[length(seen) + 1L]] <<- list(split = split, inner = inner)
    list(
      completed = TRUE,
      metrics = data.frame(
        .metric = "rmse",
        .estimator = "standard",
        .estimate = 0
      ),
      selected = data.frame(.config = "stub"),
      notes = nestedtune:::empty_notes()
    )
  }
  testthat::local_mocked_bindings(nested_fold_fit = stub)
  results <- nested_tune_grid(wf, folds, grid = grid, metrics = metrics)
  # The assembled object as well as the handoffs. Both are properties of the
  # driver's bookkeeping rather than of any fit, so the tests that read the
  # object get it from the stubbed run too -- there is no assertion here that a
  # real fit could satisfy and this one could not.
  list(seen = seen, results = results)
}

test_that("no fold's assessment rows reach its inner tuning or its outer fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  set.seed(2024)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 4),
    inside = rsample::vfold_cv(v = 3)
  )

  seen <- record_handoffs(wf, folds, det_grid(), reg_metrics())$seen
  expect_length(seen, nrow(folds))

  for (i in seq_along(seen)) {
    held_out <- as.integer(rsample::complement(seen[[i]]$split))
    expect_gt(length(held_out), 0L)

    # The outer fit trains here.
    outer_train <- as.integer(seen[[i]]$split$in_id)
    expect_length(intersect(outer_train, held_out), 0L)

    # Inner tuning sees these, both when fitting and when scoring.
    for (inner_split in seen[[i]]$inner$splits) {
      inner_train <- as.integer(inner_split$in_id)
      inner_score <- as.integer(rsample::complement(inner_split))
      expect_length(intersect(inner_train, held_out), 0L)
      expect_length(intersect(inner_score, held_out), 0L)
      # Everything inner tuning touches is drawn from the outer training rows.
      expect_true(all(c(inner_train, inner_score) %in% outer_train))
    }
  }
})

test_that("each fold is handed its own inner resamples, in order", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  set.seed(2025)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 4),
    inside = rsample::vfold_cv(v = 3)
  )

  seen <- record_handoffs(wf, folds, det_grid(), reg_metrics())$seen

  # A shifted pairing would still satisfy every "is this a valid rset" check
  # while training fold i on rows fold i scores. This is the assertion that
  # would catch it.
  for (i in seq_along(seen)) {
    expect_identical(seen[[i]]$split$in_id, folds$splits[[i]]$in_id)
    expect_identical(seen[[i]]$inner, folds$inner_resamples[[i]])
  }
})

test_that("the results object keeps each fold's own split", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  set.seed(2026)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  # Stubbed rather than fitted: neither assertion below reads a number a fit
  # produced. What they check is that the driver kept each fold's own split on
  # the row it assembled for it, which the stub exercises in full -- and thirty
  # real fits would have bought nothing but the wait.
  set.seed(9)
  res <- record_handoffs(wf, folds, det_grid(), reg_metrics())$results

  expect_identical(res$id, folds$id)
  for (i in seq_len(nrow(res))) {
    expect_identical(res$splits[[i]]$in_id, folds$splits[[i]]$in_id)
  }
})
