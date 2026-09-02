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

# What `print.nested_final_fit()` emits for a grid final fit, under testthat's
# reproducible output settings: first captured at M40 from the method as it
# stood at d6ff85f, and re-agreed at M46 (below).
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
PRINT_AS_AGREED_M46 <- paste(
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

test_that("printing a grid final fit is the hand-agreed text, not the snapshot", {
  skip_if_no_engines()

  txt <- local({
    local_reproducible_output()
    paste(cli::cli_fmt(print(final_for_print())), collapse = "\n")
  })
  expect_identical(txt, PRINT_AS_AGREED_M46)
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


# The procedure line and the Bayesian counts (M46 T5, AC5) -------------------

bayes_final_for_print <- function() {
  d <- make_reg_data()
  wf <- bayes_workflow(d)
  res <- bayes_final_results(d)
  set.seed(31)
  memoised(nested_final_fit(wf, res))
}

test_that("AC5: a Bayesian final fit names its procedure with the counts that ran", {
  skip_if_no_bayes_fixture()

  final <- bayes_final_for_print()

  # The candidate table is the `.iter`-bearing one the loop's derivation
  # gives, so the counts below are read off the same record a fold's candidate
  # set derived from `.inner_metrics` would be.
  cand <- extract_scored_candidates(final)
  expect_true(".iter" %in% names(cand))
  expect_identical(cand, scored_candidates(final$tuning))
  initial <- sum(cand$.iter == 0L)
  completed <- max(cand$.iter)
  # AC5: the iterations completed are the tuning run's largest `.iter`.
  expect_identical(completed, max(final$tuning$.iter))
  expect_gte(initial, 1L)

  s <- summary(final)
  expect_identical(s$tuner, "tune_bayes")
  expect_identical(s$initial, initial)
  expect_identical(s$initial_requested, 3L)
  expect_identical(s$iterations_completed, completed)
  expect_identical(s$iterations_requested, 2L)
  expect_identical(s$candidates, nrow(cand))

  line <- sprintf(
    "Bayesian optimization, %d initial candidate%s \\(3 requested\\), %d iteration%s completed \\(2 requested\\)",
    initial,
    if (initial == 1L) "" else "s",
    completed,
    if (completed == 1L) "" else "s"
  )
  out <- print_text(final)
  expect_match(out, line)
  expect_no_match(out, "nested_tune_grid")
  expect_match(print_text(s), line)
})

test_that("the counts read what ran, not what was asked for", {
  # Built by hand, so the scored counts can differ from the requested ones
  # without an engine: a metrics table holding two initial candidates where
  # three were requested, stopping at iteration 1 of 4 (IP4, RR05 Q2). The
  # run is a stand-in whose `collect_metrics()` is that table (M49).
  row <- function(config, value, iter = NULL) {
    out <- data.frame(
      df1 = value,
      .metric = "rmse",
      .estimator = "standard",
      mean = 1,
      n = 3L,
      std_err = 0.1,
      .config = config,
      stringsAsFactors = FALSE
    )
    if (!is.null(iter)) {
      out$.iter <- iter
    }
    out
  }
  tuning <- fake_tuning(rbind(
    row("pre1", 1L, 0L),
    row("pre2", 5L, 0L),
    row("iter1", 3L, 1L)
  ))
  final <- structure(
    list(
      workflow = NULL,
      selected = data.frame(df1 = 3L, .config = "iter1"),
      tuning = tuning,
      tuning_seed = 1L,
      fit_seed = 2L,
      procedure = list(
        tuner = "tune_bayes",
        iter = 4,
        initial = 3,
        objective = NULL,
        param_info = NULL,
        event_level = "first",
        eval_time = NULL
      )
    ),
    class = "nested_final_fit"
  )

  s <- summary(final)
  expect_identical(s$initial, 2L)
  expect_identical(s$initial_requested, 3L)
  expect_identical(s$iterations_completed, 1L)
  expect_identical(s$iterations_requested, 4L)
  expect_identical(s$candidates, 3L)
  # The singular forms, at the count where the wording changes.
  expect_match(
    print_text(final),
    "2 initial candidates \\(3 requested\\), 1 iteration completed \\(4 requested\\)"
  )

  # One initial candidate: the other singular branch of the Bayesian line.
  one_initial <- final
  one_initial$tuning <- fake_tuning(rbind(
    row("pre1", 1L, 0L),
    row("iter1", 3L, 1L)
  ))
  expect_identical(summary(one_initial)$initial, 1L)
  expect_match(
    print_text(one_initial),
    "1 initial candidate \\(3 requested\\), 1 iteration completed"
  )

  # And the grid line at one candidate.
  one_grid <- final
  one_grid$tuning <- fake_tuning(row("pre1", 1L))
  one_grid$procedure <- list(tuner = "tune_grid", grid = 1)
  expect_identical(summary(one_grid)$candidates, 1L)
  expect_match(print_text(one_grid), "grid search, 1 candidate scored")
})

test_that("a grid final fit carries the Bayesian counts as NULL and names its search", {
  skip_if_no_engines()

  final <- final_for_print()
  s <- summary(final)

  expect_identical(s$tuner, "tune_grid")
  for (nm in c(
    "initial",
    "initial_requested",
    "iterations_completed",
    "iterations_requested"
  )) {
    expect_true(nm %in% names(s))
    expect_null(s[[nm]])
  }
  expect_match(print_text(final), "grid search, 3 candidates scored")
  expect_match(print_text(s), "grid search, 3 candidates scored")
})

test_that("the Bayesian printed reports are stable", {
  skip_if_no_bayes_fixture()

  expect_snapshot(print(bayes_final_for_print()))
  expect_snapshot(print(summary(bayes_final_for_print())))
})
