# The final fit on an annealing result (M51 AC5, T4): `nested_final_fit()`
# runs the recorded search again on the full data, and everything it reports
# about that search reads through the same derivation the fold record uses.
#
# O5 -- type "live" (reference implementation). Source:
#   reference_anneal_final_fit() in helper-orchestration.R, written from the
#   documented contract -- its own `set.seed(s)` and
#   `sample.int(.Machine$integer.max, 2)`, the inner rset built under the
#   first seed (D-016), `tune_sim_anneal()` under `control_sim_anneal(
#   verbose_iter = FALSE, allow_par = FALSE)`, `select_best()`,
#   `finalize_workflow()`, `fit()` under the second -- and never from the
#   object. Pinned by "the annealing final fit matches a hand-rolled reference
#   pipeline", on the stochastic fixture so a mis-seeded fit cannot agree by
#   accident.

anneal_final_and_reference <- function() {
  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- anneal_stoch_final_results(d)
  proc <- attr(res, "procedure")

  set.seed(99)
  final <- memoised(nested_final_fit(wf, res))

  ref <- memoised(reference_anneal_final_fit(
    wf,
    d,
    iter = proc$iter,
    initial = proc$initial,
    metrics = attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse",
    control = proc$control,
    param_info = proc$param_info
  ))
  list(d = d, final = final, ref = ref, res = res)
}

in_ids <- function(tuned) lapply(tuned$splits, function(s) s$in_id)

test_that("the annealing final fit matches a hand-rolled reference pipeline (AC5)", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  b <- anneal_final_and_reference()
  final <- b$final
  ref <- b$ref

  # The seed layout, derived independently from the documented contract.
  expect_identical(c(final$tuning_seed, final$fit_seed), ref$seeds)
  expect_identical(final$selected, ref$selected)
  # The resamples the search saw (D-016's ordering).
  expect_identical(in_ids(final$tuning), in_ids(ref$tuned))
  expect_identical(
    predict(extract_workflow(final), new_data = b$d),
    predict(ref$workflow, new_data = b$d)
  )

  # The run is an annealing search, recorded as the one that ran.
  expect_s3_class(final$tuning, "iteration_results")
  expect_identical(final$procedure$tuner, "tune_sim_anneal")
  expect_identical(final$procedure$iter, 2)
  expect_identical(final$procedure$initial, 3)
  expect_identical(final$procedure$control, attr(b$res, "procedure")$control)
  # The search iterated on this side too, so the identity above is with a
  # driver that iterated and not merely with the initial stage.
  expect_true(any(final$tuning$.iter > 0L))
})

test_that("the final fit's candidates carry the iteration each came from (AC5, D-043)", {
  skip_if_no_anneal_fixture(stochastic = TRUE)

  b <- anneal_final_and_reference()
  final <- b$final

  cand <- extract_scored_candidates(final)
  expect_identical(cand, candidate_set(tune::collect_metrics(final$tuning)))
  expect_setequal(names(cand), c("min_n", ".config", ".iter"))
  # The initial rows are the design that ran: at most the 3 requested, and
  # possibly fewer, since a space-filling design on a small integer space
  # deduplicates (the print test below reads the count that ran).
  initial <- sum(cand$.iter == 0L)
  expect_gte(initial, 1L)
  expect_lte(initial, 3L)
})

test_that("print() and summary() name simulated annealing with the counts that ran (AC5)", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- anneal_final_results(d)
  set.seed(33)
  final <- memoised(nested_final_fit(wf, res))

  cand <- extract_scored_candidates(final)
  initial <- sum(cand$.iter == 0L)
  completed <- max(cand$.iter)
  expect_identical(completed, max(final$tuning$.iter))
  expect_gte(initial, 1L)

  s <- summary(final)
  expect_identical(s$tuner, "tune_sim_anneal")
  expect_identical(s$initial, initial)
  expect_identical(s$initial_requested, 3L)
  expect_identical(s$iterations_completed, completed)
  expect_identical(s$iterations_requested, 2L)
  expect_identical(s$candidates, nrow(cand))

  line <- sprintf(
    "simulated annealing, %d initial candidate%s \\(3 requested\\), %d iteration%s completed \\(2 requested\\)",
    initial,
    if (initial == 1L) "" else "s",
    completed,
    if (completed == 1L) "" else "s"
  )
  out <- print_text(final)
  expect_match(out, line)
  expect_no_match(out, "Bayesian")
  expect_no_match(out, "grid search")
  expect_match(print_text(s), line)
})

test_that("finetune must be installed to re-run an annealing result", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- anneal_final_results(d)

  real <- rlang::is_installed
  testthat::local_mocked_bindings(
    is_installed = function(pkg, ...) {
      if (pkg == "finetune") FALSE else real(pkg, ...)
    },
    .package = "rlang"
  )
  expect_error(
    nested_final_fit(wf, res),
    class = "nestedtune_pkg_not_installed"
  )
})
