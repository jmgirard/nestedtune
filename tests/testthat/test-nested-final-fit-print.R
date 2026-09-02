# Printing a final fit, and the generics it deliberately does not answer
# (AC4, AC10).

final_for_print <- function() {
  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)
  set.seed(21)
  memoised(nested_final_fit(wf, res))
}

test_that("printing names the selection and where the estimate lives", {
  skip_if_no_engines()

  out <- print_text(final_for_print())

  expect_match(out, "final fit")
  expect_match(out, "num_comp = ")
  expect_match(out, "no performance estimate of its own")
  expect_match(out, "results object this fit was built from")
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


# Summarizing a final fit (M40) ------------------------------------------

# What `print.nested_final_fit()` emitted before this milestone existed, under
# testthat's reproducible output settings, captured from the method as it stood
# at d6ff85f.
#
# Written out here rather than left to the snapshot below it. The snapshot is
# exactly the artifact a change to the print method would re-record, so a
# criterion forbidding that output to change cannot be pinned to it -- accepting
# the new snapshot would satisfy the pin and falsify the promise at the same
# time. These bytes have to be re-agreed by hand instead.
#
# M46 added a "Procedure:" line -- what search ran, grid or Bayesian, and at
# what counts -- and pointed the estimate sentence at the results object
# rather than naming `nested_tune_grid()`, since the record it reads from can
# equally be a `nested_tune_bayes()` result. That is a change to what this
# constant pins, re-agreed by hand rather than accepted from the snapshot for
# the same reason the original was.
PRINT_BEFORE_M40 <- paste(
  c(
    "",
    "-- Nested cross-validation final fit -------------------------------------------",
    "Procedure: grid search, 3 candidates scored",
    "Selected: num_comp = 3",
    "",
    "i This model has no performance estimate of its own. Report the nested estimate",
    "  from `collect_metrics()` on the results object this fit was built from, which",
    "  describes the procedure that produced it.",
    "i Compare the parameters above with `.selected` from that run. Outer folds",
    "  choosing differently is selection instability, and it is information about",
    "  the procedure rather than noise.",
    "i `extract_tune_results()` returns the tuning run selection came from, and",
    "  `extract_scored_candidates()` the candidates it scored. Any metric reachable",
    "  through the first is a selection-time quantity, optimistically biased as a",
    "  claim about this model."
  ),
  collapse = "\n"
)

test_that("AC1: printing a final fit is unchanged by summary() existing", {
  skip_if_no_engines()

  txt <- local({
    local_reproducible_output()
    paste(cli::cli_fmt(print(final_for_print())), collapse = "\n")
  })
  expect_identical(txt, PRINT_BEFORE_M40)
})

test_that("AC2: summary() returns a classed object naming what was selected", {
  skip_if_no_engines()

  final <- final_for_print()
  s <- summary(final)

  expect_s3_class(s, "summary.nested_final_fit")
  expect_identical(
    names(s),
    c(
      "tuning_label",
      "tuner",
      "candidates",
      "initial",
      "initial_requested",
      "iterations_completed",
      "iterations_requested",
      "selection",
      "estimate"
    )
  )
  # The absence is carried as a component rather than left out, so a caller
  # meets a recorded fact instead of a missing name (M40 Decisions).
  expect_true("estimate" %in% names(s))
  expect_null(s$estimate)

  expect_identical(s$tuning_label, "3-fold cross-validation")
  # Read off the accessor rather than written out, so the two cannot come to
  # disagree about how many candidates the run scored.
  expect_identical(s$candidates, nrow(extract_scored_candidates(final)))
  expect_identical(s$selection, list(num_comp = "3"))

  out <- print_text(s)
  expect_match(out, "num_comp: 3")
  expect_match(out, "no performance estimate of its own")
  expect_match(out, "results object this fit was built from")
})

test_that("AC3: the summary shows no number from the stored tuning run", {
  skip_if_no_engines()

  final <- final_for_print()
  out <- print_text(summary(final))

  # The same scan the print method gets above, run on the method that has an
  # Estimate heading and therefore the better opportunity to grow a number
  # under it. A "resampled RMSE" line here would be a selection-time quantity
  # dressed as this model's performance, which is the misreading IP3 forbids.
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

test_that("a summary with nothing to report drops the lines it cannot fill", {
  # Built directly rather than fitted: both branches are properties of the
  # print method, and a workflow with no tunable parameter and a tuning object
  # carrying no pretty() method would take an engine apiece to reach.
  s <- structure(
    list(
      tuning_label = NULL,
      candidates = 1L,
      selection = list(),
      estimate = NULL
    ),
    class = "summary.nested_final_fit"
  )

  out <- print_text(s)

  expect_match(out, "No tuned parameters")
  expect_no_match(out, "Full-data tuning")
  # The heading and its sentence stand whether or not anything was tuned: this
  # object never has an estimate, and that is what the section exists to say.
  expect_match(out, "no performance estimate of its own")
})

test_that("the summary report is stable", {
  skip_if_no_engines()

  expect_snapshot(print(summary(final_for_print())))
})

test_that("the stored selection keeps the value's own precision", {
  # Built directly: this is a property of how the component is rendered, and a
  # continuous tuning parameter would take an engine to reach.
  #
  # A value whose display rendering and whose value differ. The results-side
  # summary stores `as.character()`, and comparing the two selections is what
  # the component is for, so a rounded string here would report two equal
  # selections as different ones -- and would change answer with the session's
  # `digits` option (M40 review F1).
  penalty <- 0.0031622776601683794
  final <- structure(
    list(
      workflow = NULL,
      selected = data.frame(
        penalty = penalty,
        .config = "Preprocessor1_Model1"
      ),
      tuning = NULL,
      tuning_seed = 1L,
      fit_seed = 2L
    ),
    class = "nested_final_fit"
  )

  expect_identical(
    summary(final)$selection,
    list(penalty = as.character(penalty))
  )
  expect_identical(summary(final)$selection$penalty, "0.00316227766016838")

  # Restored with on.exit() rather than withr, which this package does not
  # depend on.
  op <- options(digits = 3)
  on.exit(options(op), add = TRUE)
  expect_identical(summary(final)$selection$penalty, "0.00316227766016838")
  options(op)

  # The one-line print label is unchanged by that: it renders for reading, and
  # `print.nested_final_fit()` emits exactly what it always did.
  expect_identical(selected_label(final$selected), "penalty = 0.003162278")
})
