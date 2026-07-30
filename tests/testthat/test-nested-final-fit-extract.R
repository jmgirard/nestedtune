# The named accessors onto what selection saw (AC1, AC2, AC3).
#
# Oracle provenance: none is claimed here and none is owed. These accessors
# produce no numeric result of their own -- one returns a stored object
# untouched, the other delegates to `scored_candidates()`, whose derivation M21
# oracle-verified against a hand-run `tune_grid()` (O3) and a data-frame
# invariant (O4). What is asserted below is the contract, not the arithmetic.

final_for_extract <- function() {
  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)
  set.seed(21)
  memoised(nested_final_fit(wf, folds, grid = det_grid(), metrics = reg_metrics()))
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

  # D-023: the same shape a fold's `.grid` carries, `.config` included, so the
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
  final <- memoised(nested_final_fit(wf, folds, grid = grid, metrics = reg_metrics()))
  cand <- extract_scored_candidates(final)

  expect_identical(nrow(cand), nrow(grid))
  expect_setequal(cand$threshold, grid$threshold)
  expect_true(any(grepl("^pre1[0-9]_", cand$.config)))
})

test_that("what the accessors return agrees with what the loop records", {
  skip_if_no_engines()

  # The `@return` promises a reader they can compare this table against a
  # fold's `.grid` directly. That promise is only worth making if the two
  # really are the same shape, which nothing above checks -- both assertions so
  # far read the accessor alone.
  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)

  set.seed(21)
  final <- memoised(nested_final_fit(wf, folds, grid = det_grid(), metrics = reg_metrics()))
  set.seed(22)
  res <- memoised(nested_tune_grid(wf, folds, grid = det_grid(), metrics = reg_metrics()))

  expect_identical(
    names(extract_scored_candidates(final)),
    names(res$.grid[[1L]])
  )
})

test_that("both accessors refuse an object they cannot answer for", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- final_nested(d)
  wf <- det_workflow(d)
  set.seed(22)
  res <- memoised(nested_tune_grid(wf, folds, grid = det_grid(), metrics = reg_metrics()))

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

test_that("the refusals read the same for both accessors", {
  skip_if_no_engines()

  expect_snapshot(error = TRUE, {
    extract_tune_results(1:3)
    extract_scored_candidates(1:3)
  })
})
