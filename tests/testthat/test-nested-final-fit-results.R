# What the final fit hands back (AC1).

test_that("the final fit returns a trained workflow inside its own object", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)

  set.seed(3)
  final <- memoised(nested_final_fit(
    wf,
    folds,
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  expect_s3_class(final, "nested_final_fit")
  expect_named(
    final,
    c("workflow", "selected", "tuning", "tuning_seed", "fit_seed")
  )

  extracted <- extract_workflow(final)
  expect_s3_class(extracted, "workflow")
  expect_true(workflows::is_trained_workflow(extracted))

  # The selection is a single candidate row drawn from the grid that was asked
  # for, not a ranking over candidates.
  expect_s3_class(final$selected, "data.frame")
  expect_identical(nrow(final$selected), 1L)
  expect_true(final$selected$num_comp %in% det_grid()$num_comp)

  # The tuning run it was chosen from travels with it, and it is tune's own
  # object rather than a summary of one.
  expect_s3_class(final$tuning, "tune_results")

  expect_type(final$tuning_seed, "integer")
  expect_type(final$fit_seed, "integer")
  expect_false(identical(final$tuning_seed, final$fit_seed))
})

test_that("the fitted workflow predicts on new data", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)

  set.seed(3)
  final <- memoised(nested_final_fit(wf, folds, grid = det_grid()))

  preds <- predict(extract_workflow(final), new_data = d[1:5, ])
  expect_identical(nrow(preds), 5L)
  expect_true(all(is.finite(preds$.pred)))
})

test_that("the final fit trains on every row, not on an outer analysis set", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)

  set.seed(3)
  final <- memoised(nested_final_fit(wf, folds, grid = det_grid()))

  # The mould records how many rows the workflow was fitted on. Any outer
  # analysis set would be smaller, so this is what separates a final fit from
  # one more fold.
  mould <- workflows::extract_mold(extract_workflow(final))
  expect_identical(nrow(mould$predictors), nrow(d))
})
