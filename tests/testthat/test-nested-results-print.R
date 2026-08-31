# Printing a nested_results object (M04).
#
# The snapshots at the bottom pin the shapes that carry meaning. The assertions
# above them pin the facts a snapshot alone would let drift silently: an
# approved snapshot records whatever the code printed, not what it owed, so a
# criterion that must hold is asserted in words as well as recorded in shape.

test_that("printing reports the outer design and how much of it ran", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- print_text(res)

  expect_match(txt, "3-fold cross-validation")
  expect_match(txt, "3 requested")
  expect_match(txt, "3 completed")
})

test_that("the outer scheme is dropped rather than misreported after subsetting", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- print_text(as_fold_subset(res, 1:2))

  # The rows kept are not the design the label describes (IP4). Since M36 `[`
  # sheds the class outright on a row subset, so the object printed here is
  # built by the helper rather than by `[`; what print() must do with a results
  # object carrying no scheme label is unchanged, and that is what this asserts.
  expect_no_match(txt, "3-fold cross-validation")
  expect_match(txt, "2 requested")
})

test_that("a failed fold is named along with the stage it failed at", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  txt <- print_text(res)

  expect_match(txt, "Fold2")
  expect_match(txt, "outer fit")
  expect_match(txt, "3 requested")
  expect_match(txt, "2 completed")

  set.seed(2)
  inner <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 1L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  expect_match(print_text(inner), "inner tuning")
})

test_that("unanimous selection is distinguished from disagreement", {
  skip_if_no_engines()

  d <- make_reg_data()
  set.seed(2)
  agreed <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  agreed_txt <- print_text(agreed)

  expect_match(agreed_txt, "num_comp")
  expect_match(agreed_txt, "agree")
  expect_no_match(agreed_txt, "disagree")

  u <- unstable_data()
  set.seed(2)
  split <- memoised(nested_tune_grid(
    unstable_workflow(u),
    det_nested(u, v = 4),
    grid = unstable_grid(),
    metrics = reg_metrics()
  ))
  split_txt <- print_text(split)

  # The fixture's folds land on 4, 4, 4, 3 -- every fold's value is shown, in
  # fold order, so the run that produced the disagreement stays readable.
  expect_identical(
    vapply(split$.selected, function(s) s$num_comp, integer(1)),
    c(4L, 4L, 4L, 3L)
  )
  expect_match(split_txt, "4, 4, 4, 3")
  expect_match(split_txt, "disagree")
})

test_that("printing says the estimate describes the procedure, not a model", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- print_text(res)

  expect_match(txt, "procedure")
  expect_match(txt, "not a model you can deploy")
})

test_that("printing shows the estimate over the folds that contributed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  summarized <- collect_metrics(res)
  txt <- print_text(res)

  expect_match(txt, "rmse")
  expect_match(txt, "rsq")
  expect_match(txt, format(summarized$mean[[1L]], digits = 3), fixed = TRUE)
  expect_match(txt, "3 of 3 outer folds")
})

test_that("printing a partial run neither warns nor errors", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # collect_metrics() warns here by design; printing is not a summary request,
  # so it reports the same partiality in the header instead of raising.
  expect_warning(collect_metrics(res), class = "nestedtune_partial_summary")
  expect_no_warning(print_text(res))
  expect_match(print_text(res), "2 of 3 outer folds")
})

test_that("printing a run where nothing completed neither warns nor errors", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # collect_metrics() refuses outright; printing still has to describe the run.
  expect_error(collect_metrics(res))
  expect_no_error(print_text(res))
  expect_no_warning(print_text(res))

  txt <- print_text(res)
  expect_match(txt, "0 completed")
  expect_match(txt, "no estimate")
})

test_that("print returns its input invisibly and is registered for S3 dispatch", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  cli::cli_fmt(returned <- withVisible(print(res)))
  expect_false(returned$visible)
  expect_identical(returned$value, res)

  expect_false(
    is.null(utils::getS3method("print", "nested_results", optional = TRUE))
  )
})

test_that("a subset missing the per-fold record prints as a plain tibble", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Keeping .completed alone once kept the class, and print() then read
  # columns that were gone: two "unknown or uninitialised column" warnings
  # and an "invalid 'times' argument" error, on a method that promises neither.
  thin <- res[, c("id", ".completed")]
  expect_false(inherits(thin, "nested_results"))
  expect_no_error(utils::capture.output(print(thin)))
  expect_no_warning(utils::capture.output(print(thin)))
})

test_that("a single completed fold reads in the singular", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  expect_match(
    print_text(as_fold_subset(res, 1L)),
    "Estimate (1 of 1 outer fold)",
    fixed = TRUE
  )
})

test_that("a parameter only some folds chose is not reported as disagreement", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # One fold carries no value for num_comp. The folds that did choose agree,
  # so flagging instability here would be a false alarm about the very thing
  # this method exists to surface.
  partial_param <- res
  partial_param$.selected[[2L]] <-
    partial_param$.selected[[2L]][, ".config", drop = FALSE]
  txt <- print_text(partial_param)

  expect_no_match(txt, "disagree")
  expect_match(txt, "all 2 folds that chose it agree", fixed = TRUE)
  expect_match(txt, "1 recorded no value", fixed = TRUE)
})

test_that("a fold that selected NA is a value, not an absent one", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  na_selected <- res
  na_selected$.selected[[1L]]$num_comp <- NA_integer_
  txt <- print_text(na_selected)

  # NA is a choice this fold made and "--" means the fold had no column at
  # all; rendering both the same way would make each unreadable as the other.
  expect_match(txt, "num_comp: NA, 3, 3 (folds disagree)", fixed = TRUE)
})

test_that("a list-valued selection prints instead of aborting", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Not something select_best() produces, but the method promises never to
  # raise and vapply() would abort on a length-2 result before printing at all.
  listy <- res
  listy$.selected[[1L]]$num_comp <- list(1:2)

  expect_no_error(print_text(listy))
  expect_match(print_text(listy), "1, 2", fixed = TRUE)
})

test_that("folds that searched different candidate sets are said to have", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  # A continuous parameter with a grid SIZE: tune expands it per fold, under
  # each fold's own seed, and the expansions differ (measured in
  # test-nested-tune-grid-oracles.R). The disagreement is checked here rather
  # than assumed, so a fixture that quietly stopped disagreeing could not go on
  # recording a valid-looking snapshot of a line it no longer earns.
  set.seed(20)
  differing <- nested_tune_grid(
    cont_workflow(d),
    folds,
    grid = 5,
    metrics = reg_metrics()
  )
  expect_false(same_candidates(differing$.grid))

  # The branch this line lives on is reached by no other fixture in the file,
  # so the method's "never raises, never warns" promise is re-asserted here
  # rather than assumed from the partial-run and nothing-completed tests above.
  expect_no_error(print_text(differing))
  expect_no_warning(print_text(differing))

  txt <- print_text(differing)
  expect_match(txt, "Candidates searched: 5, 5, 5")
  expect_match(txt, "did not search the\\s+same grid")

  # A data-frame grid is handed to every fold unchanged, so there is nothing to
  # disagree about and the line stays away. Asserted because a line that fires
  # unconditionally would look identical in the snapshot above.
  set.seed(20)
  agreeing <- nested_tune_grid(
    det_workflow(d),
    folds,
    grid = det_grid(),
    metrics = reg_metrics()
  )
  expect_true(same_candidates(agreeing$.grid))
  expect_no_match(print_text(agreeing), "Candidates searched")
})

test_that("the candidate-set comparison ignores order and tune's config labels", {
  # `.config` is positional, so two folds that searched the same candidates in a
  # different order carry different labels for them -- comparing on the label
  # would report every such pair as a disagreement.
  a <- data.frame(cost = c(1, 2, 3), .config = c("pre1", "pre2", "pre3"))
  b <- data.frame(cost = c(3, 1, 2), .config = c("pre9", "pre8", "pre7"))
  expect_true(same_candidates(list(a, b)))

  # And a difference below print precision is still a difference: the comparison
  # runs on the values, not on what they format to.
  c1 <- data.frame(
    cost = c(1, 2, 3 + 1e-12),
    .config = c("pre1", "pre2", "pre3")
  )
  expect_false(same_candidates(list(a, c1)))

  # A fold carrying a different parameter entirely is a difference too, rather
  # than a coincidence of values.
  d1 <- data.frame(penalty = c(1, 2, 3), .config = c("pre1", "pre2", "pre3"))
  expect_false(same_candidates(list(a, d1)))
})

test_that("printing survives a list-valued parameter column (M21 review F1)", {
  # Regression. `candidate_key()` normalised row order with
  # `do.call(order, values)`, and order() RAISES on a list column
  # ("unimplemented type 'list' in 'orderVector1'") -- so a `.grid` carrying one
  # aborted a method whose header promises it never raises. The shape is
  # producible: test-nested-tune-grid-failures.R asserts scored_candidates()
  # returns exactly such a record.
  #
  # Asserted on same_candidates() rather than only through print(), because the
  # raise is in the comparison and a print-only test would pass the day the
  # call moved.
  listy <- data.frame(.config = c("pre1", "pre2"))
  listy$cost <- list(1:2, 3:4)

  expect_no_error(same_candidates(list(listy, listy)))
  expect_true(same_candidates(list(listy, listy)))

  # Two folds whose list-valued candidates genuinely differ are a difference,
  # not an error and not a false agreement.
  other <- data.frame(.config = c("pre1", "pre2"))
  other$cost <- list(1:2, 5:6)
  expect_no_error(same_candidates(list(listy, other)))
  expect_false(same_candidates(list(listy, other)))

  # Row order still normalises away for a list column, as it does for an atomic
  # one -- the rendering that replaced order() must not lose that.
  reordered <- data.frame(.config = c("pre9", "pre8"))
  reordered$cost <- list(3:4, 1:2)
  expect_true(same_candidates(list(listy, reordered)))
})

test_that("printed output holds its shape", {
  skip_if_no_engines()
  d <- make_reg_data()
  u <- unstable_data()

  set.seed(2)
  complete <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  # Unanimity has to be checked, not assumed: the same design on the smaller
  # frame splits 3, 3, 2, 3, 3, so a fixture labelled unanimous that quietly
  # stopped being unanimous would still record a perfectly valid snapshot.
  big <- make_reg_data(n = 150)
  set.seed(2)
  unanimous <- memoised(nested_tune_grid(
    det_workflow(big),
    det_nested(big, v = 5),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  expect_identical(
    vapply(unanimous$.selected, function(s) s$num_comp, integer(1)),
    rep(3L, 5L)
  )
  set.seed(2)
  divergent <- memoised(nested_tune_grid(
    unstable_workflow(u),
    det_nested(u, v = 4),
    grid = unstable_grid(),
    metrics = reg_metrics()
  ))
  set.seed(2)
  nothing <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # The candidate-set line's own shape, snapshot beside the rest (M21). Built
  # from a grid SIZE rather than a frame, which is the only way folds come to
  # search different candidates.
  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(20)
  differing <- nested_tune_grid(
    cont_workflow(d),
    folds,
    grid = 5,
    metrics = reg_metrics()
  )

  expect_snapshot(print(complete))
  expect_snapshot(print(partial))
  expect_snapshot(print(unanimous))
  expect_snapshot(print(divergent))
  expect_snapshot(print(nothing))
  expect_snapshot(print(differing))
})
