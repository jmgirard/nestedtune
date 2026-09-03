# Every cli_abort() branch on the final-fit path, fired once (M05 AC5, AC11;
# re-cut at M46 AC1 for the `(object, results)` signature, D-041).
#
# The workflow check is exercised through nested_final_fit() rather than
# assumed from the orchestrators' suites: a check that is not wired into this
# function passes its own tests and refuses nothing here. The design checks
# no longer apply -- the final fit takes a results object, and what it asks of
# that object is `check_results_record()`'s three refusals below.

test_that("the workflow checks are wired into the final fit", {
  skip_if_no_engines()

  d <- make_reg_data()
  res <- final_results(d)
  wf <- det_workflow(d)

  expect_error(nested_final_fit("not a workflow", res), "must be a")
  expect_error(
    nested_final_fit(
      parsnip::fit(
        workflows::workflow(y ~ x1 + x2 + x3 + x4, parsnip::linear_reg()),
        data = d
      ),
      res
    ),
    "already be fitted"
  )

  prep_only <- workflows::workflow(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d)
  )
  expect_error(nested_final_fit(prep_only, res), "no model specification")
  cnd <- tryCatch(nested_final_fit(prep_only, res), error = function(e) e)
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))

  # The recorded grid is judged against the workflow handed over, as the
  # orchestrator judged it: a workflow tuning a parameter the grid has no
  # column for is refused here, not by tune one tuning run later.
  # The message names `object`, the side the user wrote, and `results`, the
  # side the grid came from -- never a `grid` argument this signature lacks.
  other <- cont_workflow(d)
  cnd <- tryCatch(nested_final_fit(other, res), error = function(e) e)
  expect_match(conditionMessage(cnd), "`object`")
  expect_match(conditionMessage(cnd), "recorded grid")
  expect_match(conditionMessage(cnd), "`results`")
  expect_no_match(conditionMessage(cnd), "`grid`")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("the former procedure arguments are refused as unknown", {
  skip_if_no_engines()

  d <- make_reg_data()
  res <- final_results(d)
  wf <- det_workflow(d)

  # Each of the five formals D-041 removed. They come from `results` now, so
  # passing one is the dots error rather than a silent positional match.
  former <- list(
    grid = det_grid(),
    param_info = NULL,
    metrics = reg_metrics(),
    event_level = "first",
    eval_time = 1
  )
  for (nm in names(former)) {
    # Spliced rather than `do.call()`, which would put the function object in
    # the condition's call and leave nothing for `call_name()` to read.
    cnd <- rlang::catch_cnd(rlang::inject(nested_final_fit(
      wf,
      res,
      !!!former[nm]
    )))
    expect_s3_class(cnd, "rlib_error_dots_nonempty")
    expect_identical(rlang::call_name(conditionCall(cnd)), "nested_final_fit")
  }
})

# The results-record refusals (AC1, RR05 Q3): one class, a message per
# origin, the user's call named, and nothing fitted or drawn first.

expect_bad_results <- function(expr, pattern) {
  cnd <- tryCatch(expr, error = function(e) e)
  testthat::expect_s3_class(cnd, "nestedtune_bad_results")
  testthat::expect_match(conditionMessage(cnd), pattern)
  testthat::expect_identical(
    conditionCall(cnd)[[1]],
    as.name("nested_final_fit")
  )
  invisible(cnd)
}

test_that("an object that is not a nested_results is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  res <- final_results(d)
  wf <- det_workflow(d)

  expect_bad_results(nested_final_fit(wf, "not a run"), "must be a")
  expect_bad_results(nested_final_fit(wf, final_nested(d)), "must be a")

  # The invariant rule returns a bare tibble for an operation that changed
  # the rows, so a subset arrives here with the class and the record both
  # gone -- never as a classed object missing its record -- and the message
  # says which door it came through.
  subset <- res[1L, ]
  expect_false(inherits(subset, "nested_results"))
  expect_bad_results(nested_final_fit(wf, subset), "plain tibble")
  expect_bad_results(nested_final_fit(wf, res[0L, ]), "plain tibble")
})

test_that("a results object carrying no inner specification is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # A design assembled by hand carries no `inside` call, and the loop runs it
  # without complaint; the result then records none. An attribute cannot hold
  # NULL, so this object is what a result built before the specification was
  # recorded looks like too, and the message names both origins.
  folds <- final_nested(d)
  attr(folds, "inside") <- NULL
  set.seed(22)
  res <- memoised(nested_tune_grid(wf, folds, grid = det_grid()))
  expect_null(attr(res, "inside"))

  cnd <- expect_bad_results(
    nested_final_fit(wf, res),
    "no inner resampling specification"
  )
  expect_match(conditionMessage(cnd), "earlier version")
  expect_match(conditionMessage(cnd), "assembled by hand")
  expect_match(conditionMessage(cnd), "not migrated")

  # A specification that is present but is not a call cannot be re-run
  # either, and lands in the same refusal.
  not_call <- final_results(d)
  attr(not_call, "inside") <- "vfold_cv(v = 3)"
  expect_bad_results(
    nested_final_fit(wf, not_call),
    "no inner resampling specification"
  )
})

test_that("a results object carrying no procedure is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Only an object from before the procedure was recorded looks like this;
  # it is reached here by removing the attribute, which no verb does.
  res <- final_results(d)
  attr(res, "procedure") <- NULL
  expect_s3_class(res, "nested_results")

  cnd <- expect_bad_results(nested_final_fit(wf, res), "no tuning procedure")
  expect_match(conditionMessage(cnd), "earlier version")

  # Both missing at once names both, in the order the record lists them.
  attr(res, "inside") <- NULL
  expect_bad_results(
    nested_final_fit(wf, res),
    "no inner resampling specification and tuning procedure"
  )
})

test_that("a results object with the record and no rows is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)

  # Reachable only by surgery: `res[0, ]` and `vctrs::vec_ptype(res)` both
  # hand back a bare tibble (measured 2026-09-02), so a classed zero-row
  # object wearing the record is a prototype, built here as the private
  # branch of `vec_restore()` would stamp one.
  empty <- res[0L, ]
  for (nm in results_attributes()) {
    attr(empty, nm) <- attr(res, nm)
  }
  class(empty) <- c("nested_results", class(empty))
  expect_identical(nrow(empty), 0L)

  cnd <- expect_bad_results(nested_final_fit(wf, empty), "has no rows")
  expect_match(conditionMessage(cnd), "prototype")
})

test_that("the record refusals fire before anything is drawn", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)
  attr(res, "inside") <- NULL

  # The seed draw sits after the check block; a reordering that moved the
  # check below it would leave the caller's stream advanced by a refusal.
  set.seed(1)
  before <- .Random.seed
  expect_error(nested_final_fit(wf, res), class = "nestedtune_bad_results")
  expect_identical(.Random.seed, before)
})

# The all-failed refusal: a run in which no outer fold completed has no
# estimate, so a model fitted from it would be reported with a number that
# does not exist (IP3). It is refused after the three record refusals and
# before the tuner, grid and seed steps, with its own class -- the one
# collect_metrics(), autoplot() and agreement() raise on the same object.

all_failed_results <- function(d, wf, stage) {
  set.seed(22)
  suppressWarnings(memoised(nested_tune_grid(
    wf,
    break_every_fold(final_nested(d), stage),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
}

test_that("a results object in which no outer fold completed is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Both stages a fold can fail at. `.completed` is written by one
  # constructor whichever tuner ran, so the grid result stands for the five.
  for (stage in c("inner tuning", "outer fit")) {
    res <- all_failed_results(d, wf, stage)
    expect_s3_class(res, "nested_results")
    expect_false(any(res$.completed))

    cnd <- rlang::catch_cnd(nested_final_fit(wf, res), "error")
    expect_s3_class(cnd, "nestedtune_no_completed_folds")
    expect_match(conditionMessage(cnd), "no outer fold completed", fixed = TRUE)
    expect_match(conditionMessage(cnd), "summary()", fixed = TRUE)
    expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
  }
})

test_that("the all-failed refusal fires before anything is drawn", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- all_failed_results(d, wf, "inner tuning")

  set.seed(1)
  before <- .Random.seed
  expect_error(
    nested_final_fit(wf, res),
    class = "nestedtune_no_completed_folds"
  )
  expect_identical(.Random.seed, before)
})

test_that("the record refusals fire before the all-failed one", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- all_failed_results(d, wf, "inner tuning")

  # A classed zero-row prototype of an all-failed run, built as the no-rows
  # test above builds one: `.completed` is `logical(0)`, which the all-failed
  # check would read as "no fold completed", so the record refusal has to
  # answer first (the order NEWS states).
  empty <- res[0L, ]
  for (nm in results_attributes()) {
    attr(empty, nm) <- attr(res, nm)
  }
  class(empty) <- c("nested_results", class(empty))
  expect_identical(nrow(empty), 0L)

  cnd <- rlang::catch_cnd(nested_final_fit(wf, empty), "error")
  expect_s3_class(cnd, "nestedtune_bad_results")
  expect_false(inherits(cnd, "nestedtune_no_completed_folds"))
  expect_match(conditionMessage(cnd), "has no rows", fixed = TRUE)
})

test_that("a run with one failed fold and one completed is fitted", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Built inline rather than from `final_results()`, which hardcodes its
  # design; on `final_nested()` because `det_nested()`'s inner specification
  # cannot be re-evaluated by the final fit (M05).
  set.seed(22)
  res <- suppressWarnings(memoised(nested_tune_grid(
    wf,
    break_fold(final_nested(d), 1L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  expect_identical(res$.completed, c(FALSE, TRUE))

  set.seed(5)
  final <- memoised(nested_final_fit(wf, res))
  expect_s3_class(final, "nested_final_fit")
})

# The specification is re-run in the caller's frame, so a design built with a
# variable that is gone by now fails there -- two frames below the user's call
# -- and the abort still names that call (M05, RR02 B1).

test_that("an inner specification that cannot be re-evaluated names itself and the call", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # Built inside a function, so `v` is gone by the time the final fit tries
  # to re-evaluate the call the design stored and the result recorded. The
  # loop never re-evaluates it, so the results object builds fine.
  gone <- local({
    v <- 3
    set.seed(1)
    nested_resamples(
      d,
      outside = rsample::vfold_cv(v = 2),
      inside = rsample::vfold_cv(v = v)
    )
  })
  set.seed(22)
  res <- memoised(nested_tune_grid(wf, gone, grid = det_grid()))
  expect_true(all(res$.completed))

  cnd <- tryCatch(nested_final_fit(wf, res), error = function(e) e)
  expect_match(conditionMessage(cnd), "could not be\\s+re-evaluated")
  # The message names the call it tried, which is the only way a reader can
  # tell which variable went missing.
  expect_match(conditionMessage(cnd), "vfold_cv")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("an inner specification that is not an rset is refused, naming the call", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d)

  # Evaluates cleanly and hands back something that is not a resampling
  # object, which is a different failure from one that errors outright.
  attr(res, "inside") <- quote(data.frame())

  cnd <- tryCatch(nested_final_fit(wf, res), error = function(e) e)
  expect_match(conditionMessage(cnd), "did not produce an")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_final_fit"))
})

test_that("a run that recorded no metric set re-runs under tune's defaults", {
  skip_if_no_engines()

  # `attr(x, "metrics")` is absent rather than NULL for such a run; the
  # rebuilt procedure passes NULL on and tune picks, exactly as the loop did
  # (RR05 B4). Not a refusal case.
  d <- make_reg_data()
  wf <- det_workflow(d)
  res <- final_results(d, metrics = NULL)
  expect_false("metrics" %in% names(attributes(res)))

  set.seed(5)
  final <- memoised(nested_final_fit(wf, res))
  expect_identical(
    sort(unique(tune::collect_metrics(final$tuning)$.metric)),
    c("rmse", "rsq")
  )
})

test_that("a missing engine package is refused by the final fit", {
  skip_if_no_engines()
  # A real engine that is almost certainly absent; skipped rather than
  # asserted if it happens to be installed.
  skip_if(rlang::is_installed("kknn"))

  d <- make_reg_data()
  res <- final_results(d)
  missing_engine <- workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    parsnip::set_mode(
      parsnip::set_engine(
        parsnip::nearest_neighbor(neighbors = tune::tune()),
        "kknn"
      ),
      "regression"
    )
  )

  expect_error(nested_final_fit(missing_engine, res), "not installed")
})
