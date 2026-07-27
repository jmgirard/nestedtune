# Printing a final fit, and the generics it deliberately does not answer
# (AC4, AC10).

final_for_print <- function() {
  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)
  set.seed(21)
  memoised(nested_final_fit(wf, folds, grid = det_grid(), metrics = reg_metrics()))
}

test_that("printing names the selection and where the estimate lives", {
  skip_if_no_engines()

  out <- print_text(final_for_print())

  expect_match(out, "final fit")
  expect_match(out, "num_comp = ")
  expect_match(out, "no performance estimate of its own")
  expect_match(out, "nested_tune_grid")
  # RR02 B3: the moment of deployment is when selection instability matters.
  expect_match(out, "\\.selected")
})

test_that("printing shows no number from the stored tuning run", {
  skip_if_no_engines()

  final <- final_for_print()
  out <- print_text(final)

  # Every metric the stored run could offer, checked against the output rather
  # than assumed absent. A print method that grew a "resampled RMSE" line would
  # be showing a selection-time number as though it described this model, which
  # is exactly the misreading IP3 forbids (AC10).
  tuning_metrics <- tune::collect_metrics(final$tuning)
  values <- c(tuning_metrics$mean, tuning_metrics$std_err)
  values <- values[!is.na(values)]
  expect_gt(length(values), 0L)

  for (v in values) {
    for (digits in 3:6) {
      expect_false(
        grepl(format(round(v, digits), nsmall = digits), out, fixed = TRUE),
        label = paste0("tuning metric ", v, " at ", digits, " digits")
      )
    }
  }
})

test_that("tune's ranking generics have no method for a final fit", {
  skip_if_no_engines()

  final <- final_for_print()

  # The same refusal D-010 chose for nested_results, for the same reason: an
  # answer here would look authoritative and describe nothing the user wants.
  # Some of these refuse through a default method tune wrote and some through
  # dispatch failing outright, so the wording differs; what matters is that
  # none of them answers.
  refusal <- "exists for|applicable method"
  expect_error(collect_metrics(final), refusal)
  expect_error(tune::show_best(final), refusal)
  expect_error(tune::select_best(final), refusal)
})

test_that("the printed report is stable", {
  skip_if_no_engines()

  expect_snapshot(print(final_for_print()))
})
