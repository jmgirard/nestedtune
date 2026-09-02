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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  expect_identical(nrow(res), 3L)
  expect_identical(res$.completed, c(TRUE, TRUE, FALSE))
})

test_that("the failing stage and its cause are recorded, tune's own notes included", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  tuning_failed <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
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
    det_workflow(d),
    break_fold(det_nested(d), 3L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
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
      memoised(nested_tune_grid(
        det_workflow(d),
        nested,
        grid = det_grid(),
        metrics = reg_metrics()
      )),
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
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
  for (i in 1:3) {
    nested <- break_fold(nested, i, "inner tuning")
  }

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  expect_identical(attr(res, "folds_completed"), 0L)
  expect_error(collect_metrics(res), "no outer fold completed")
  expect_error(
    collect_metrics(res, summarize = FALSE),
    "no outer fold completed"
  )
})

test_that("failure capture leaves a clean run exactly as M02 left it", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- det_nested(d)

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    nested,
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  expect_true(all(res$.completed))
  expect_identical(attr(res, "folds_completed"), 3L)
  # No warning on a clean run, from either surface.
  expect_no_warning(collect_metrics(res))
  expect_named(
    collect_metrics(res),
    c(".metric", ".estimator", "mean", "n", "std_err")
  )
  expect_true(all(collect_metrics(res)$n == 3L))
})

test_that("a fold's seeds do not move when an earlier fold fails (IP2)", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  clean <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  set.seed(2)
  broken <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 1L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  expect_true(res$.completed[[2L]])
  expect_true(nrow(res$.notes[[2L]]) > 0L)
  expect_true(any(grepl(
    "Not all variables in the recipe",
    res$.notes[[2L]]$note
  )))
  # A genuinely clean fold still carries nothing.
  expect_identical(nrow(res$.notes[[1L]]), 0L)

  # The inner table says the same thing in numbers (M49, AC1): every
  # candidate of fold 2 scored on two of its three inner resamples, so its
  # `n` is below the inner resample count, while a clean fold's is the count.
  partial <- res$.inner_metrics[[2L]]
  expect_identical(nrow(partial), nrow(res$.inner_metrics[[1L]]))
  expect_true(all(partial$n < 3L))
  expect_true(all(res$.inner_metrics[[1L]]$n == 3L))
})

test_that("a row subset carries no record of the run at all", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 1L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  # Until M36 these came back classed with the counts recomputed, which kept the
  # record true but left a two-row object describing itself as the three-fold
  # design it was cut from. Now the class goes, and the run's record goes with
  # it -- there is nothing left to be stale (#32, IP4).
  for (subset in list(res[res$.completed, ], res[1L, ])) {
    expect_false(inherits(subset, "nested_results"))
    for (nm in c(
      "grid",
      "metrics",
      "outer_label",
      "folds_attempted",
      "folds_completed"
    )) {
      expect_null(attr(subset, nm))
    }
  }
})

test_that("a results object holding no completed fold refuses to summarize", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 1L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  # Before the fix this passed the guard on the parent's stale count and
  # returned a 0-row tibble, reporting "2 of 3" for an object covering none.
  # The object is built by the helper, not by `[`, which since M36 returns a
  # bare tibble -- so this is about the guard, not about subsetting.
  expect_error(
    collect_metrics(as_fold_subset(res, 1L)),
    "no outer fold completed"
  )
})

test_that("dropping any of the per-fold columns sheds the results class", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
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
    inherits(
      res[, c(".metrics", ".selected", ".notes", ".completed")],
      "nested_results"
    )
  )

  # .inner_metrics is in that set (M49; the candidate column joined it at M21).
  # Asserted by dropping it from an otherwise
  # complete object rather than by listing a subset that happens to omit it, so
  # this fails if the column stops being required rather than passing on some
  # other column's absence.
  expect_false(
    inherits(res[, setdiff(names(res), ".inner_metrics")], "nested_results")
  )
  # The control: a column selection that drops nothing keeps the class, so the
  # assertions above fail on the column they name rather than on `[` having
  # stopped returning a results object for any reason at all.
  expect_s3_class(res[, names(res)], "nested_results")
})

# What the evaluated-candidate record says when not everything ran (M21, IP4).
#
# The record is derived from the tuning run's metrics, so every one of these
# cases is a different answer to "what does a fold that fell short record" --
# and the wrong answer in either direction is an IP4 failure. Recording the
# request would claim candidates that never ran; recording nothing for a fold
# that did tune would deny a grid that did.

test_that("a candidate that fails on every inner resample is absent from the record", {
  skip_if_no_engines()
  d <- make_reg_data()

  # -5 is refused by step_pca()'s prep() on every inner split, while 1 and 2
  # score everywhere. The fold still completes: tune_grid() returns a usable
  # result and select_best() chooses among the survivors, which is exactly the
  # "worked, on less than the whole design" case M03 records.
  grid <- data.frame(num_comp = c(1L, 2L, -5L))

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = grid,
    metrics = reg_metrics()
  )))

  expect_true(all(res$.completed))
  for (g in candidate_sets(res)) {
    expect_identical(nrow(g), 2L)
    expect_identical(sort(g$num_comp), c(1L, 2L))
  }
  # And the table itself carries no row for it: absent, not scored as NA.
  for (m in res$.inner_metrics) {
    expect_false(-5L %in% m$num_comp)
  }

  # The request is unchanged: the two records answer different questions, and
  # this is the case that separates them.
  expect_identical(attr(res, "grid"), grid)
})

test_that("a fold that failed at the outer fit keeps the grid its tuning scored", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 3L, stage = "outer fit")

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    nested,
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # Fold 3 tuned successfully and died afterwards, so it DID evaluate a grid.
  # Giving it a zero-row record would report a fold that searched three
  # candidates as having searched none -- IP4 pointing the other way, and the
  # defect M21's criteria audit caught in the plan's own wording.
  expect_false(res$.completed[[3L]])
  scored <- candidate_set(res$.inner_metrics[[3L]])
  expect_identical(nrow(scored), 3L)
  expect_identical(sort(scored$num_comp), 1:3)

  # And it keeps the inner table that tuning produced (M49, AC1), checked
  # against tune re-run by hand under the fold's own seed: the outer failure
  # came after the inner run, so the table is the completed run's, not a
  # zero-row stand-in for a fold that did tune.
  set.seed(
    res$.tuning_seed[[3L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  tuned <- tune::tune_grid(
    det_workflow(d),
    resamples = nested$inner_resamples[[3L]],
    grid = det_grid(),
    metrics = reg_metrics(),
    control = tune::control_grid(allow_par = FALSE)
  )
  expect_identical(res$.inner_metrics[[3L]], tune::collect_metrics(tuned))
})

test_that("a fold that scored nothing records an empty table, never NULL", {
  skip_if_no_engines()
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    nested,
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  none <- res$.inner_metrics[[2L]]
  expect_false(res$.completed[[2L]])
  expect_false(is.null(none))
  expect_true(is.data.frame(none))
  expect_identical(nrow(none), 0L)

  # A NULL here would be indistinguishable from a column that was never filled,
  # and would make every lapply() over `.inner_metrics` special-case one fold.
  expect_false(any(vapply(res$.inner_metrics, is.null, logical(1))))

  # Zero rows under a completed fold's columns (M49, AC1), name for name and
  # type for type, so a reader stacking the folds' tables never meets a fold
  # whose columns differ. It is built without asking tune for it:
  # `collect_metrics()` raises on a run in which every candidate failed (the
  # M03 lesson), which is exactly this fold.
  done <- res$.inner_metrics[[1L]]
  expect_identical(names(none), names(done))
  expect_identical(
    vapply(none, function(col) class(col)[[1L]], character(1)),
    vapply(done, function(col) class(col)[[1L]], character(1))
  )
  # The passing control: the completed fold's table is not itself empty, so
  # the identities above compare against real columns.
  expect_true(nrow(done) > 0L)
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
    memoised(nested_tune_grid(
      wf,
      det_nested(d),
      grid = det_grid(),
      metrics = reg_metrics()
    ))
  )

  expect_false(any(res$.completed))
  expect_identical(res$.notes[[1L]]$location[[1L]], "inner tuning")
  expect_true(any(grepl("will not be tuned", res$.notes[[1L]]$note)))

  # No fold completed, so there is no completed fold's table to copy the
  # columns from: the zero-row table is built from the workflow's tuned
  # parameter and tune's summary columns instead (M49, AC1). This is the one
  # branch where tuning returned nothing at all, not even a run to read.
  for (m in res$.inner_metrics) {
    expect_identical(nrow(m), 0L)
    expect_identical(
      names(m),
      c("num_comp", ".metric", ".estimator", "mean", "n", "std_err", ".config")
    )
    expect_type(m$num_comp, "integer")
  }
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
    memoised(nested_tune_grid(
      det_workflow(d),
      nested,
      grid = det_grid(),
      metrics = reg_metrics()
    ))
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
    nested_tune_grid(
      det_workflow(d),
      det_nested(d),
      grid = det_grid(),
      metrics = reg_metrics()
    )
  )

  expect_false(any(res$.completed))
  expect_identical(nrow(res), 3L)
  expect_true(any(grepl("engineered finalize failure", res$.notes[[1L]]$note)))
})

test_that("bookkeeping the candidate record cannot abort a run", {
  # The candidate set is derived from a metrics table, on the final fit
  # outside every tryCatch -- so a raise there would abort a call that has a
  # fitted model to hand back, over bookkeeping rather than over a fit, which
  # is the one outcome M03 exists to prevent.
  #
  # A list-valued parameter column was the suspected raise and is not one:
  # the derivation orders by the label and both candidates come back.
  # Asserted rather than dropped, because that is the fact the defensive
  # wrapper's comment rests on, and an unasserted "we checked, it is fine"
  # rots.
  listy <- new_tbl(list(
    cost = list(1:2, 3:4),
    .metric = c("rmse", "rmse"),
    .estimator = c("standard", "standard"),
    mean = c(1, 2),
    n = c(3L, 3L),
    std_err = c(0.1, 0.1),
    .config = c("pre1", "pre2")
  ))

  expect_no_error(out <- candidate_set(listy))
  expect_true(is.data.frame(out))
  expect_identical(nrow(out), 2L)
  expect_identical(out$.config, c("pre1", "pre2"))
  expect_no_error(out <- scored_candidates(fake_tuning(listy)))
  expect_identical(out$.config, c("pre1", "pre2"))

  # And the wrapper is genuinely a wrapper: an input that DOES raise inside the
  # derivation returns the empty record rather than propagating.
  local_mocked_bindings(
    candidate_set = function(metrics) stop("boom")
  )
  expect_no_error(fallback <- scored_candidates(fake_tuning(listy)))
  expect_identical(nrow(fallback), 0L)
})
