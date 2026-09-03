# The final fit on a racing result (M50 AC6, T5): `nested_final_fit()` races
# the recorded grid again on the full data, and everything it reports about
# that race reads through the same derivation the fold record uses.
#
# O5 -- type "live" (reference implementation). Source:
#   reference_race_final_fit() in helper-orchestration.R, written from the
#   documented contract -- its own `set.seed(s)` and
#   `sample.int(.Machine$integer.max, 2)`, the inner rset built under the
#   first seed (D-016), the race under `control_race(burn_in = 2, allow_par =
#   FALSE)`, `select_best()`, `finalize_workflow()`, `fit()` under the second
#   -- and never from the object. Pinned by "the racing final fit matches a
#   hand-rolled reference pipeline", for each racer, on the stochastic
#   fixture so a mis-seeded fit cannot agree by accident.

race_final_and_reference <- function(fn) {
  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- race_stoch_final_results(fn, d)
  proc <- attr(res, "procedure")

  set.seed(99)
  final <- memoised(nested_final_fit(wf, res))

  ref <- memoised(reference_race_final_fit(
    fn,
    wf,
    d,
    grid = proc$grid,
    metrics = attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse",
    control = proc$control
  ))
  list(d = d, final = final, ref = ref, res = res)
}

in_ids <- function(tuned) lapply(tuned$splits, function(s) s$in_id)

test_that("the racing final fit matches a hand-rolled reference pipeline (AC6)", {
  skip_if_no_race_fixture(stochastic = TRUE)

  for (fn in RACERS) {
    b <- race_final_and_reference(fn)
    final <- b$final
    ref <- b$ref

    # The seed layout, derived independently from the documented contract.
    expect_identical(c(final$tuning_seed, final$fit_seed), ref$seeds)
    expect_identical(final$selected, ref$selected)
    # The resamples the race saw (D-016's ordering).
    expect_identical(in_ids(final$tuning), in_ids(ref$tuned))
    expect_identical(
      predict(extract_workflow(final), new_data = b$d),
      predict(ref$workflow, new_data = b$d)
    )

    # The run is a race, recorded as the one that ran.
    expect_s3_class(final$tuning, "tune_race")
    expect_identical(final$procedure$tuner, fn)
    expect_identical(final$procedure$grid, stoch_grid())
    expect_identical(final$procedure$control, attr(b$res, "procedure")$control)
  }
})

test_that("the final fit's candidates are every candidate its race scored (AC6, D-043)", {
  skip_if_no_race_fixture(stochastic = TRUE)

  for (fn in RACERS) {
    b <- race_final_and_reference(fn)
    final <- b$final

    cand <- extract_scored_candidates(final)
    # The same derivation the fold reader applies: the distinct parameter
    # rows of `collect_metrics(<race>, all_configs = TRUE)`.
    expect_identical(
      cand,
      candidate_set(tune::collect_metrics(final$tuning, all_configs = TRUE))
    )
    expect_setequal(names(cand), c("min_n", ".config"))
    expect_false(".iter" %in% names(cand))

    # Eliminated candidates are in it: the survivors-only table finetune
    # returns by default is shorter than what was scored, on this fixture.
    survivors <- tune::collect_metrics(final$tuning)
    everyone <- tune::collect_metrics(final$tuning, all_configs = TRUE)
    expect_lt(nrow(survivors), nrow(everyone))
    expect_identical(nrow(cand), length(unique(everyone$.config)))
    expect_identical(nrow(cand), nrow(stoch_grid()))
  }
})

test_that("print() and summary() name the racing method with the count scored (AC6)", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  labels <- c(
    tune_race_anova = "ANOVA racing",
    tune_race_win_loss = "win/loss racing"
  )

  for (fn in RACERS) {
    res <- race_final_results(fn, d)
    set.seed(33)
    final <- memoised(nested_final_fit(wf, res))

    s <- summary(final)
    expect_identical(s$tuner, fn)
    expect_identical(s$candidates, nrow(extract_scored_candidates(final)))
    # The Bayesian counts stay NULL: a race has no initial set or iterations.
    expect_null(s$initial)
    expect_null(s$iterations_completed)

    line <- sprintf(
      "%s, %d candidates scored",
      labels[[fn]],
      s$candidates
    )
    expect_match(print_text(final), line, fixed = TRUE)
    expect_match(print_text(s), line, fixed = TRUE)
    expect_no_match(print_text(final), "grid search")
  }
})

test_that("a workflow other than the one the race was built around is refused on the recorded grid", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  res <- race_final_results("tune_race_anova", d)
  # The recorded grid names `num_comp`; this workflow tunes `threshold`.
  other <- cont_workflow(d)

  expect_error(
    nested_final_fit(other, res),
    "recorded grid has a column for"
  )
  expect_error(nested_final_fit(other, res), "num_comp")
})

test_that("the racing final fit's tuning run answers tune's collect_metrics() with both scopes", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- race_final_results("tune_race_anova", d)
  set.seed(33)
  final <- memoised(nested_final_fit(wf, res))

  tuning <- extract_tune_results(final)
  expect_s3_class(tuning, "tune_race")
  # `n` is the resamples each candidate was scored on: every survivor at the
  # full count, and the full-data inner design is three resamples here.
  everyone <- tune::collect_metrics(tuning, all_configs = TRUE)
  expect_true(all(everyone$n <= 3L))
  expect_true(any(everyone$n == 3L))
})
