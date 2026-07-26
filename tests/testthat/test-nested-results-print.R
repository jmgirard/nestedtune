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
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  txt <- print_text(res)

  expect_match(txt, "3-fold cross-validation")
  expect_match(txt, "3 requested")
  expect_match(txt, "3 completed")
})

test_that("the outer scheme is dropped rather than misreported after subsetting", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  txt <- print_text(res[1:2, ])

  # The rows kept are not the design the label describes (IP4).
  expect_no_match(txt, "3-fold cross-validation")
  expect_match(txt, "2 requested")
})

test_that("a failed fold is named along with the stage it failed at", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))
  txt <- print_text(res)

  expect_match(txt, "Fold2")
  expect_match(txt, "outer fit")
  expect_match(txt, "3 requested")
  expect_match(txt, "2 completed")

  set.seed(2)
  inner <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 1L, "inner tuning"),
    grid = det_grid(), metrics = reg_metrics()
  ))

  expect_match(print_text(inner), "inner tuning")
})

test_that("unanimous selection is distinguished from disagreement", {
  skip_if_no_engines()

  d <- make_reg_data()
  set.seed(2)
  agreed <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  agreed_txt <- print_text(agreed)

  expect_match(agreed_txt, "num_comp")
  expect_match(agreed_txt, "agree")
  expect_no_match(agreed_txt, "disagree")

  u <- unstable_data()
  set.seed(2)
  split <- nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4),
    grid = unstable_grid(), metrics = reg_metrics()
  )
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
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  txt <- print_text(res)

  expect_match(txt, "procedure")
  expect_match(txt, "not a model you can deploy")
})

test_that("printing shows the estimate over the folds that contributed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
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
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))

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
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_every_fold(det_nested(d)),
    grid = det_grid(), metrics = reg_metrics()
  ))

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
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )

  cli::cli_fmt(returned <- withVisible(print(res)))
  expect_false(returned$visible)
  expect_identical(returned$value, res)

  expect_false(
    is.null(utils::getS3method("print", "nested_results", optional = TRUE))
  )
})

test_that("printed output holds its shape", {
  skip_if_no_engines()
  d <- make_reg_data()
  u <- unstable_data()

  set.seed(2)
  complete <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  set.seed(2)
  partial <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))
  # Unanimity has to be checked, not assumed: the same design on the smaller
  # frame splits 3, 3, 2, 3, 3, so a fixture labelled unanimous that quietly
  # stopped being unanimous would still record a perfectly valid snapshot.
  big <- make_reg_data(n = 150)
  set.seed(2)
  unanimous <- nested_tune_grid(
    det_workflow(big), det_nested(big, v = 5), grid = det_grid(),
    metrics = reg_metrics()
  )
  expect_identical(
    vapply(unanimous$.selected, function(s) s$num_comp, integer(1)),
    rep(3L, 5L)
  )
  set.seed(2)
  divergent <- nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4), grid = unstable_grid(),
    metrics = reg_metrics()
  )
  set.seed(2)
  nothing <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_every_fold(det_nested(d)),
    grid = det_grid(), metrics = reg_metrics()
  ))

  expect_snapshot(print(complete))
  expect_snapshot(print(partial))
  expect_snapshot(print(unanimous))
  expect_snapshot(print(divergent))
  expect_snapshot(print(nothing))
})
