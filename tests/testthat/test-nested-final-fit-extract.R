# The named accessors onto what selection saw (AC1, AC2, AC3).
#
# Oracle provenance: none is claimed here and none is owed. These accessors
# produce no numeric result of their own -- one returns a stored object
# untouched, the other delegates to `scored_candidates()`, whose derivation M21
# oracle-verified against a hand-run `tune_grid()` (O3) and a data-frame
# invariant (O4). What is asserted below is the contract, not the arithmetic.

final_for_extract <- function() {
  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)
  set.seed(21)
  memoised(nested_final_fit(wf, res))
}

test_that("the tuning-run accessor returns the stored run, unreduced", {
  skip_if_no_engines()

  final <- final_for_extract()

  expect_identical(extract_tune_results(final), final$tuning)

  # The leg that carries the weight. `expect_identical()` above compares the
  # accessor against the slot it reads, so it cannot tell a live tune_results
  # from a reduced one -- reduce the storage and both sides reduce together.
  # This asks the returned object to behave like tune's own, which a summary
  # or a stripped copy would not.
  extracted <- extract_tune_results(final)
  expect_s3_class(extracted, "tune_results")
  metrics <- tune::collect_metrics(extracted)
  expect_s3_class(metrics, "data.frame")
  expect_gt(nrow(metrics), 0L)
})

test_that("the candidate accessor reports the candidates that scored", {
  skip_if_no_engines()

  final <- final_for_extract()
  cand <- extract_scored_candidates(final)

  # det_grid() is data.frame(num_comp = 1:3) on a four-predictor recipe, so
  # every candidate is reachable and every one of them scores. The right answer
  # is therefore known before the run: three rows, those three values.
  expect_s3_class(cand, "tbl_df")
  expect_identical(nrow(cand), nrow(det_grid()))
  expect_setequal(cand$num_comp, det_grid()$num_comp)

  # D-023: the same shape a fold's candidate set derived from `.inner_metrics`
  # carries, `.config` included, so the
  # two records of one thing can be compared without translating between them.
  expect_true(".config" %in% names(cand))
  expect_setequal(names(cand), c("num_comp", ".config"))
})

test_that("the candidate accessor holds up past nine candidates", {
  skip_if_no_engines()

  # tune zero-pads `.config` from ten candidates on ("pre01_" rather than
  # "pre1_"), and `scored_candidates()` orders by that label. Below ten the
  # padding never engages, so a fixture that stops at three cannot show whether
  # ordering survives the change -- which is the case a lexical sort of an
  # unpadded label would get wrong.
  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- cont_workflow(d)
  grid <- data.frame(threshold = seq(0.05, 0.95, length.out = 11L))

  set.seed(4)
  res <- memoised(nested_tune_grid(
    wf,
    folds,
    grid = grid,
    metrics = reg_metrics()
  ))

  set.seed(4)
  final <- memoised(nested_final_fit(wf, res))
  cand <- extract_scored_candidates(final)

  expect_identical(nrow(cand), nrow(grid))
  expect_setequal(cand$threshold, grid$threshold)
  expect_true(any(grepl("^pre1[0-9]_", cand$.config)))
})

test_that("what the accessors return agrees with what the loop records", {
  skip_if_no_engines()

  # The `@return` promises a reader they can compare this table against a
  # fold's candidate set directly. That promise is only worth making if the two
  # really are the same shape, which nothing above checks -- both assertions so
  # far read the accessor alone.
  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)

  set.seed(21)
  final <- memoised(nested_final_fit(wf, res))

  from_fit <- extract_scored_candidates(final)
  from_loop <- candidate_set(res$.inner_metrics[[1L]])

  expect_identical(names(from_fit), names(from_loop))

  # Names alone cannot fail here: both sides come from `scored_candidates()`
  # over the same deterministic grid, so they agree by construction. The plan
  # gate's recorded falsifier for this milestone's shape choice was "the
  # accessor and the fold's candidate set disagreeing on a run where both are
  # defined", and disagreement in VALUES is what that names -- so the values
  # are what has to be compared.
  expect_setequal(from_fit$num_comp, from_loop$num_comp)
  expect_setequal(from_fit$.config, from_loop$.config)
})

test_that("a survival fit's candidates carry no evaluation-time column", {
  skip_if_no_censored()

  # A dynamic survival metric is scored once per evaluation time, so the
  # run's own table has `.eval_time` and as many rows per candidate as there
  # are times. The accessor reports candidates, one row each, with the
  # per-metric columns -- `.eval_time` among them -- dropped (AC6).
  #
  # Two evaluation times draw tune's notice that the first is the one
  # selection uses -- once per fold and once at the final fit, the
  # documented behavior -- and that notice is not under test.
  data <- srv_data()
  workflow <- srv_workflow(data)
  res <- suppressWarnings(memoised(nested_tune_grid(
    workflow,
    srv_nested(data),
    grid = srv_grid(),
    metrics = srv_metrics(),
    eval_time = srv_eval_times()
  )))
  set.seed(11)
  final <- suppressWarnings(memoised(nested_final_fit(workflow, res)))

  scored <- tune::collect_metrics(extract_tune_results(final))
  expect_true(".eval_time" %in% names(scored))
  expect_identical(nrow(scored), nrow(srv_grid()) * length(srv_eval_times()))

  cand <- extract_scored_candidates(final)
  expect_setequal(names(cand), c("dist", ".config"))
  expect_identical(nrow(cand), nrow(srv_grid()))
  expect_setequal(cand$dist, srv_grid()$dist)
})

test_that("both accessors refuse an object they cannot answer for", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)
  set.seed(22)
  res <- memoised(nested_tune_grid(
    wf,
    folds,
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # A results object is the near miss worth firing: it is this package's own
  # class, it holds candidates, and it is the thing a user reaching for these
  # names is most likely to be holding by mistake.
  for (obj in list(res, list(a = 1), 1:3)) {
    expect_error(
      extract_tune_results(obj),
      class = "nestedtune_no_extract_method"
    )
    expect_error(
      extract_scored_candidates(obj),
      class = "nestedtune_no_extract_method"
    )
  }

  # R's bare dispatch failure names neither what it was handed nor what would
  # have answered, and never reaches the user here.
  expect_false(
    grepl(
      "applicable method",
      conditionMessage(rlang::catch_cnd(extract_tune_results(res)))
    )
  )
})

# The refusal names the object before anything in the dots. Before M56 the
# defaults checked their dots first, so `extract_tune_results(1, foo = 1)`
# complained of `foo` and said nothing of `1` (an `rlib_error_dots_nonempty`,
# measured 2026-09-03).
test_that("an object with no method is refused as such whatever rides in the dots", {
  for (fn in list(extract_tune_results, extract_scored_candidates)) {
    cnd <- rlang::catch_cnd(fn(1, foo = 1))
    expect_s3_class(cnd, "nestedtune_no_extract_method")
    expect_false(inherits(cnd, "rlib_error_dots_nonempty"))
  }

  # The passing control: the methods still refuse a stray argument, so the
  # dots check moved rather than went.
  skip_if_no_engines()
  final <- final_for_extract()
  expect_error(
    extract_tune_results(final, foo = 1),
    class = "rlib_error_dots_nonempty"
  )
  expect_error(
    extract_scored_candidates(final, foo = 1),
    class = "rlib_error_dots_nonempty"
  )
})

test_that("the refusals read the same for both accessors", {
  skip_if_no_engines()

  expect_snapshot(error = TRUE, {
    extract_tune_results(1:3)
    extract_scored_candidates(1:3)
  })
})
