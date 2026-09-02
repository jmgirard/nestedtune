# Oracle records for nested_final_fit() (DESIGN Conventions: oracles are
# recorded in the test file that asserts them).
#
# O3 -- type "live" (reference implementation). Source: the tidymodels pipeline
#   itself, recomputed at test time by reference_final_fit() in
#   helper-orchestration.R, which is written from the documented seed contract
#   (D-011, D-016) and never from the returned object -- it derives its own
#   seeds, builds its own inner rset under the first of them, and spells out the
#   inner specification rather than reading the design's. Pinned by "the final
#   fit matches a hand-rolled reference pipeline". Satisfies AC2/AC9.
#
# O4 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. With a single-candidate grid
#   there is nothing to select, so the tuning stage cannot influence the result
#   and the final fit must equal a direct fit of the workflow finalized on that
#   one candidate. Pinned by "a single-candidate grid degenerates to a direct
#   fit". Satisfies AC2. Deterministic engine, so the equality is exact rather
#   than seed-contingent (D-013).
#
# O5 -- type "live" (independent reference implementation), the third strand
#   RR02 recommended. Source: tune's own fit_best(), tidymodels' separately
#   written "select, finalize, and fit on everything" path -- code neither this
#   package nor this test author wrote. Pinned by "the final fit matches
#   tune::fit_best() on the same tuning run". Needs save_workflow = TRUE on the
#   test's own tune_grid() call, which is why reference_final_fit() sets it.
#
# O3 and O4 are the >=2 independent oracle types GP2 requires; O5 reduces the
# exposure the first two share by routing the finalize-and-fit tail through
# upstream code.
#
# M46 (D-041): the final fit reads its procedure off the results object, so
# every reference here is fed the recorded procedure -- `attr(res,
# "procedure")` and `attr(res, "metrics")` -- rather than the values the test
# happens to know. The Bayesian path adds:
#
# O3b -- type "live" (reference implementation). Source:
#   reference_bayes_final_fit() in helper-orchestration.R, written from the
#   documented seed contract and D-040's rule that the Gaussian process is
#   seeded from the tuning seed through `control_bayes(seed = )` built after
#   `set.seed()` on that number, the initial set drawn inside that call from
#   the same stream, the rset built inside the seed's scope (D-016). Pinned by
#   "the Bayesian final fit matches a hand-rolled reference pipeline".
#   Satisfies AC2.
#
# O4b -- type "invariant". Source: the agreement between two internal routes.
#   At `iter = 0` a Bayesian run scores its initial candidates and proposes
#   nothing, so the final fit of that result must equal the final fit of a
#   grid result on the grid those candidates form -- the same design, the
#   same entry seed -- `dials::grid_space_filling()` on the two-parameter
#   fixture being seed-independent (asserted, as test-nested-tune-bayes-oracles.R
#   does). Pinned by "at iter = 0 the Bayesian final fit is the grid final fit
#   on the space-filling grid". Satisfies AC3.
#
# O5 (Bayesian strand) -- `tune::fit_best()` on the reference's own
#   `tune_bayes()` run, built with `save_workflow = TRUE` on the test's own
#   tuner call (RR02 Q5, RR05 Q1: tune refuses `fit_best()` on a run stored
#   without it, and the package's controls never set it), run under the
#   independently derived fit seed with the kind pinned. The reference run is
#   asserted identical to the final fit's stored run on selection and `in_id`
#   splits in the AC2 strand above it. Weaker than the grid strand, since
#   `fit_best()` never runs `tune_bayes()`; it pins that `select_best()` on an
#   `.iter`-bearing run picks the row the package picked, and routes the tail
#   through upstream code. Satisfies AC3's second clause.

test_that("the final fit matches a hand-rolled reference pipeline", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(99)
  final <- nested_final_fit(wf, res)

  ref <- reference_final_fit(
    wf,
    d,
    attr(res, "procedure")$grid,
    attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse"
  )

  # The seed layout itself, derived independently from the documented contract.
  expect_identical(c(final$tuning_seed, final$fit_seed), ref$seeds)
  expect_identical(final$selected, ref$selected)

  # The resamples the tuning run actually saw, which is what pins D-016's
  # ordering. Asserting only on the selection and the predictions does not:
  # verified by inversion -- moving the rset construction outside the tuning
  # seed's scope leaves both of those unchanged whenever the selection happens
  # to be stable across the two fold sets, and it was for this fixture. The
  # folds themselves differ immediately.
  expect_identical(
    lapply(final$tuning$splits, function(s) s$in_id),
    lapply(ref$tuned$splits, function(s) s$in_id)
  )

  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(ref$workflow, new_data = d)
  )
})

test_that("a single-candidate grid degenerates to a direct fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  one <- data.frame(num_comp = 2L)
  res <- final_results(d, grid = one)

  set.seed(5)
  final <- nested_final_fit(wf, res)

  # Nothing to select, so the tuning stage cannot have influenced anything: the
  # result must be the workflow finalized on that candidate and fitted on all
  # the data. The engine is deterministic, so no seed enters the comparison.
  direct <- parsnip::fit(tune::finalize_workflow(wf, one), data = d)

  expect_identical(final$selected$num_comp, one$num_comp)
  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(direct, new_data = d)
  )
})

test_that("the final fit matches tune::fit_best() on the same tuning run", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- stoch_final_results(d)

  set.seed(99)
  final <- nested_final_fit(wf, res)

  ref <- reference_final_fit(
    wf,
    d,
    attr(res, "procedure")$grid,
    attr(res, "metrics"),
    seed = 99,
    metric_name = "rmse"
  )

  # The tail routed through upstream's own implementation rather than ours:
  # fit_best() selects, finalizes, and fits on the full training set itself.
  set.seed(
    ref$seeds[[2L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  best_fit <- tune::fit_best(ref$tuned, metric = "rmse")

  expect_identical(
    predict(extract_workflow(final), new_data = d),
    predict(best_fit, new_data = d)
  )
})


# The Bayesian path (M46) -----------------------------------------------------

# One reference per file rather than per test: the final fit and its
# reference are each built once and served from the cache to both strands.
bayes_final_and_reference <- function() {
  d <- make_reg_data()
  wf <- stoch_workflow(d)
  res <- bayes_stoch_final_results(d)
  proc <- attr(res, "procedure")

  set.seed(97)
  final <- memoised(nested_final_fit(wf, res))

  ref <- memoised(reference_bayes_final_fit(
    wf,
    d,
    iter = proc$iter,
    initial = proc$initial,
    objective = proc$objective,
    param_info = proc$param_info,
    metrics = attr(res, "metrics"),
    seed = 97,
    metric_name = "rmse"
  ))
  list(d = d, final = final, ref = ref)
}

in_ids <- function(tuned) lapply(tuned$splits, function(s) s$in_id)

test_that("the Bayesian final fit matches a hand-rolled reference pipeline", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  b <- bayes_final_and_reference()
  final <- b$final
  ref <- b$ref

  # The seed layout, derived independently from the documented contract.
  expect_identical(c(final$tuning_seed, final$fit_seed), ref$seeds)
  expect_identical(final$selected, ref$selected)

  # The resamples the tuning run saw (D-016's ordering), and the identity the
  # O5 strand below rests on.
  expect_identical(in_ids(final$tuning), in_ids(ref$tuned))

  expect_identical(
    predict(extract_workflow(final), new_data = b$d),
    predict(ref$workflow, new_data = b$d)
  )

  # The search ran: at least one proposal was scored, so the reference agrees
  # with a driver that iterated and not merely with the initial stage.
  expect_true(any(final$tuning$.iter > 0L))
  expect_identical(final$procedure$tuner, "tune_bayes")
})

test_that("at iter = 0 the Bayesian final fit is the grid final fit on the space-filling grid", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- final_nested(d)
  p <- bayes_param_info(wf)
  ms <- reg_metrics()

  # The O4b premise, asserted rather than assumed: the two-parameter design
  # is the same under every seed, so one grid built outside any seed scope is
  # what every Bayesian run at `iter = 0` scored.
  set.seed(1)
  g <- dials::grid_space_filling(p, size = 3)
  set.seed(2)
  expect_identical(dials::grid_space_filling(p, size = 3), g)
  expect_identical(nrow(g), 3L)

  # The same design, the same entry seed, one result per orchestrator.
  set.seed(20)
  bayes <- memoised(nested_tune_bayes(
    wf,
    folds,
    iter = 0,
    initial = 3,
    param_info = p,
    metrics = ms
  ))
  set.seed(20)
  grid <- memoised(nested_tune_grid(
    wf,
    folds,
    grid = g,
    param_info = p,
    metrics = ms
  ))
  expect_true(all(bayes$.completed))
  expect_true(all(grid$.completed))

  set.seed(30)
  from_bayes <- memoised(nested_final_fit(wf, bayes))
  set.seed(30)
  from_grid <- memoised(nested_final_fit(wf, grid))

  expect_identical(from_bayes$tuning_seed, from_grid$tuning_seed)
  expect_identical(from_bayes$selected, from_grid$selected)
  expect_identical(in_ids(from_bayes$tuning), in_ids(from_grid$tuning))
  expect_identical(
    predict(extract_workflow(from_bayes), new_data = d),
    predict(extract_workflow(from_grid), new_data = d)
  )

  # And the Bayesian fit scored exactly the grid: the identity is with `g`,
  # not merely between two runs of the same code.
  cand <- extract_scored_candidates(from_bayes)
  expect_identical(cand$.iter, rep(0L, nrow(g)))
  expect_identical(
    sort(cand$df1 * 100L + cand$df2),
    sort(g$df1 * 100L + g$df2)
  )
})

test_that("the Bayesian final fit matches tune::fit_best() on the reference run", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  b <- bayes_final_and_reference()
  final <- b$final
  ref <- b$ref

  # The dependency the strand rests on, restated where it is used: the
  # reference run and the stored run are one search.
  expect_identical(ref$selected, final$selected)
  expect_identical(in_ids(ref$tuned), in_ids(final$tuning))

  # The tail routed through upstream's own implementation, under the
  # independently derived fit seed with the kind pinned, as the grid strand.
  set.seed(
    ref$seeds[[2L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  best_fit <- tune::fit_best(ref$tuned, metric = "rmse")

  expect_identical(
    predict(extract_workflow(final), new_data = b$d),
    predict(best_fit, new_data = b$d)
  )
})
