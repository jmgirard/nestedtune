# A failing outer fold is recorded, not fatal (M03, IP4).
#
# The two stages fail in different shapes and both are covered here: inner
# tuning raises, while the outer fit returns quietly with no metrics. A driver
# that only catches thrown errors passes half of this file.

test_that("a fold that fails at inner tuning does not abort the run", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_s3_class(res, "nested_results")
  expect_identical(nrow(res), 3L)
  expect_identical(res$.completed, c(TRUE, FALSE, TRUE))
})

test_that("a fold that fails at the outer fit does not abort the run", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 3L, stage = "outer fit")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_identical(nrow(res), 3L)
  expect_identical(res$.completed, c(TRUE, TRUE, FALSE))
})

test_that("the failing stage and its cause are recorded, tune's own notes included", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  tuning_failed <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "inner tuning"),
    grid = det_grid(), metrics = reg_metrics()
  )))
  notes <- tuning_failed$.notes[[2L]]

  expect_named(notes, c("location", "type", "note", "trace"))
  expect_true(nrow(notes) > 1L)
  expect_identical(notes$location[[1L]], "inner tuning")
  expect_identical(notes$type[[1L]], "error")
  # tune's own notes carried through verbatim (GP1): the real cause is the
  # recipe refusing the foreign frame, and only tune ever saw it.
  expect_true(any(grepl("Not all variables in the recipe", notes$note)))

  set.seed(2)
  fit_failed <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 3L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  )))
  fit_notes <- fit_failed$.notes[[3L]]

  expect_identical(fit_notes$location[[1L]], "outer fit")
  expect_true(any(grepl("Not all variables in the recipe", fit_notes$note)))
})

test_that("a completed fold carries an empty note table", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_identical(nrow(res$.notes[[1L]]), 0L)
  expect_named(res$.notes[[1L]], c("location", "type", "note", "trace"))
})

test_that("the object records folds attempted and completed", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_identical(attr(res, "folds_attempted"), 3L)
  expect_identical(attr(res, "folds_completed"), 2L)
})

test_that("the run itself warns when a fold fails, naming it", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  # tune warns as well, and deliberately is not muffled (GP1) -- the outer
  # expectation catches it so this test asserts both, rather than leaking one.
  expect_warning(
    expect_warning(
      memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics())),
      "Fold2",
      class = "nestedtune_failed_folds"
    ),
    "All models failed"
  )
})

test_that("collect_metrics() averages the completed folds and warns about the rest", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_warning(
    collect_metrics(res),
    "Fold2",
    class = "nestedtune_partial_summary"
  )
  # expect_warning() hands back the condition, not the value, so the object
  # under test is fetched separately.
  summarized <- suppressWarnings(collect_metrics(res))

  expect_true(all(summarized$n == 2L))
  # The mean is over the two folds that ran, and nothing else.
  per_fold <- suppressWarnings(collect_metrics(res, summarize = FALSE))
  expect_identical(sort(unique(per_fold$id)), c("Fold1", "Fold3"))
  rmse <- per_fold$.estimate[per_fold$.metric == "rmse"]
  expect_equal(summarized$mean[summarized$.metric == "rmse"], mean(rmse))
})

test_that("collect_metrics() aborts when no fold completed", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- det_nested(d)
  for (i in 1:3) nested <- break_fold(nested, i, "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_identical(attr(res, "folds_completed"), 0L)
  expect_error(collect_metrics(res), "no outer fold completed")
  expect_error(collect_metrics(res, summarize = FALSE), "no outer fold completed")
})

test_that("failure capture leaves a clean run exactly as M02 left it", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- det_nested(d)

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()
  ))

  expect_true(all(res$.completed))
  expect_identical(attr(res, "folds_completed"), 3L)
  # No warning on a clean run, from either surface.
  expect_no_warning(collect_metrics(res))
  expect_named(collect_metrics(res), c(".metric", ".estimator", "mean", "n", "std_err"))
  expect_true(all(collect_metrics(res)$n == 3L))
})

test_that("a fold's seeds do not move when an earlier fold fails (IP2)", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  clean <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

  set.seed(2)
  broken <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 1L, "inner tuning"),
    grid = det_grid(), metrics = reg_metrics()
  )))

  expect_identical(clean$.tuning_seed, broken$.tuning_seed)
  expect_identical(clean$.outer_fit_seed, broken$.outer_fit_seed)
  # And the surviving folds are bit-for-bit what they were.
  expect_identical(clean$.metrics[[3L]], broken$.metrics[[3L]])
  expect_identical(clean$.selected[[2L]], broken$.selected[[2L]])
})

# Review findings, regression-tested (M03 review, F1 scored 96 and F2 scored 82).

test_that("a fold that completed on a truncated inner design keeps tune's notes", {
  skip_if_no_engines()
  d <- make_reg_data()
  # One of fold 2's three inner splits is broken: tuning still returns a
  # candidate, so the fold completes -- but not on the design that was asked for.
  nested <- break_inner_split(det_nested(d), fold = 2L, split = 1L)

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_true(res$.completed[[2L]])
  expect_true(nrow(res$.notes[[2L]]) > 0L)
  expect_true(any(grepl("Not all variables in the recipe", res$.notes[[2L]]$note)))
  # A genuinely clean fold still carries nothing.
  expect_identical(nrow(res$.notes[[1L]]), 0L)
})

test_that("subsetting keeps the object's record of what ran true", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 1L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  # The counts describe the rows in hand, not the run they came from.
  kept <- res[res$.completed, ]
  expect_identical(attr(kept, "folds_attempted"), 2L)
  expect_identical(attr(kept, "folds_completed"), 2L)

  failed_only <- res[1L, ]
  expect_identical(attr(failed_only, "folds_attempted"), 1L)
  expect_identical(attr(failed_only, "folds_completed"), 0L)
})

test_that("a subset holding no completed fold refuses to summarize", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 1L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  # Before the fix this passed the guard on the parent's stale count and
  # returned a 0-row tibble, reporting "2 of 3" for an object covering none.
  expect_error(collect_metrics(res[1L, ]), "no outer fold completed")
})

test_that("dropping any of the per-fold columns sheds the results class", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

  # Without .completed nothing can answer for the run, so the object stops
  # claiming it can rather than answering from a stale attribute.
  expect_false(inherits(res["id"], "nested_results"))

  # M03 asserted here that keeping .completed was enough to keep the class.
  # Corrected at M04: it is not. Such an object kept the class while every
  # method that reads .metrics or .selected -- collect_metrics() on M03,
  # print() on M04 -- failed on it. The class is kept only when the whole
  # per-fold record and an id column survive.
  expect_false(inherits(res[, c("id", ".completed")], "nested_results"))
  expect_false(
    inherits(res[, c(".metrics", ".selected", ".notes", ".completed")],
             "nested_results")
  )
  expect_s3_class(res[1:2, ], "nested_results")
})

# The thrown-error branches at each stage (M03 review, F3). The fixtures above
# all reach the *quiet* paths -- tune returning a useless result rather than
# raising -- which left the raise branches structurally plausible and unproven.

test_that("an error raised by tune_grid() itself is recorded, not propagated", {
  skip_if_no_engines()
  d <- make_reg_data()

  # `penalty` is marked for tuning but the lm engine cannot tune it. It is not
  # in the workflow's tunable set, so a grid naming only `num_comp` passes the
  # pre-flight check -- and then tune_grid() raises before returning anything.
  rec <- recipes::step_pca(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d),
    recipes::all_predictors(),
    num_comp = tune::tune()
  )
  wf <- workflows::workflow(rec, parsnip::linear_reg(penalty = tune::tune()))

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(wf, det_nested(d), grid = det_grid(), metrics = reg_metrics()))
  )

  expect_false(any(res$.completed))
  expect_identical(res$.notes[[1L]]$location[[1L]], "inner tuning")
  expect_true(any(grepl("will not be tuned", res$.notes[[1L]]$note)))
})

test_that("an error raised by last_fit() is recorded against the outer fit", {
  skip_if_no_engines()
  d <- make_reg_data()

  # An rsplit indexing a row that does not exist: tuning succeeds, and last_fit()
  # raises rather than filing the problem in its notes as a foreign-but-valid
  # split would. The vehicle used to be a `splits` element that was not an
  # rsplit at all, which M19 now refuses at the call -- so it could no longer
  # reach the loop, and what this test is about is the loop's handling of a
  # raising last_fit(), not the class of the split.
  nested <- det_nested(d)
  nested$splits[[2L]]$in_id <- c(1L, 999999L)

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(det_workflow(d), nested, grid = det_grid(), metrics = reg_metrics()))
  )

  expect_identical(res$.completed, c(TRUE, FALSE, TRUE))
  expect_identical(res$.notes[[2L]]$location[[1L]], "outer fit")
  expect_true(any(grepl("past the end", res$.notes[[2L]]$note)))
})

test_that("an error while finalizing is this fold's failure, not the run's", {
  skip_if_no_engines()
  # Mocking a binding in another package needs testthat 3.2.0; the declared
  # floor is lower, so this skips rather than raising it for one test.
  skip_if_not_installed("testthat", "3.2.0")
  d <- make_reg_data()

  # finalize_workflow() sits between selection and the fit. Nothing reachable
  # makes it raise, so it is mocked -- the point is that the region is guarded.
  testthat::local_mocked_bindings(
    finalize_workflow = function(...) stop("engineered finalize failure"),
    .package = "tune"
  )

  set.seed(2)
  res <- suppressWarnings(
    nested_tune_grid(det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics())
  )

  expect_false(any(res$.completed))
  expect_identical(nrow(res), 3L)
  expect_true(any(grepl("engineered finalize failure", res$.notes[[1L]]$note)))
})
