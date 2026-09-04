# Every cli_abort() branch in the orchestrator's argument checks, fired once.
# GP3: a provably invalid design is refused rather than warned about.

valid_folds <- function(d, v = 2) {
  set.seed(1)
  nested_resamples(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = 3)
  )
}

test_that("`object` must be an unfitted workflow", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(parsnip::linear_reg(), folds),
    "must be a"
  )
  expect_error(nested_tune_grid("not a workflow", folds), "must be a")
  expect_error(nested_tune_grid(NULL, folds), "must be a")

  fitted <- parsnip::fit(
    workflows::workflow(y ~ x1 + x2 + x3 + x4, parsnip::linear_reg()),
    data = d
  )
  expect_error(nested_tune_grid(fitted, folds), "already be fitted")
})

# A preprocessor-only workflow used to fail from inside
# workflows::extract_spec_parsnip(), which check_workflow() calls -- so the
# message was workflows' and conditionCall() named an internal call the user
# never wrote, where every other bad-`object` shape names theirs.

test_that("a workflow carrying no model spec is refused by nestedtune", {
  skip_if_no_engines()

  d <- make_reg_data()
  folds <- valid_folds(d)
  prep_only <- workflows::workflow(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d)
  )

  expect_error(nested_tune_grid(prep_only, folds), "no model specification")
  expect_error(
    nested_tune_grid(workflows::workflow(), folds),
    "no model specification"
  )

  # The two shapes get different bullets: an empty workflow carries no
  # preprocessor either, and saying it does would describe the wrong object.
  expect_match(
    conditionMessage(tryCatch(
      nested_tune_grid(prep_only, folds),
      error = function(e) e
    )),
    "carries a preprocessor only"
  )
  expect_match(
    conditionMessage(tryCatch(
      nested_tune_grid(workflows::workflow(), folds),
      error = function(e) e
    )),
    "is empty"
  )

  cnd <- tryCatch(nested_tune_grid(prep_only, folds), error = function(e) e)
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
  # The remedy, not just a bullet: GP3 refuses, and every other check says how
  # to stop being refused.
  expect_match(conditionMessage(cnd), "add_model")
})

test_that("the workflow's engine packages must be installed", {
  skip_if_no_engines()
  # A real engine that is almost certainly absent. Skipped rather than
  # asserted if it happens to be installed.
  skip_if(rlang::is_installed("kknn"))

  d <- make_reg_data()
  folds <- valid_folds(d)

  missing_engine <- workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    parsnip::set_mode(
      parsnip::set_engine(parsnip::nearest_neighbor(), "kknn"),
      "regression"
    )
  )
  expect_error(nested_tune_grid(missing_engine, folds), "not installed")
})

test_that("`resamples` must be a nested resampling design", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  expect_error(nested_tune_grid(wf, d), "nested resampling design")
  expect_error(nested_tune_grid(wf, "folds"), "nested resampling design")
  # A plain rset has splits but no inner_resamples: the commonest mistake.
  expect_error(
    nested_tune_grid(wf, rsample::vfold_cv(d, v = 3)),
    "nested resampling design"
  )

  empty <- valid_folds(d)[0, ]
  class(empty) <- class(valid_folds(d))
  expect_error(nested_tune_grid(wf, empty), "no outer folds")
})

test_that("`resamples` must name its outer folds", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # Splits and inner resamples but no id column. Without this check the whole
  # loop runs and only then assembles a results object whose columns disagree
  # in length -- every fold's compute spent before anything complains.
  no_id <- data.frame(row.names = seq_len(nrow(folds)))
  no_id$splits <- folds$splits
  no_id$inner_resamples <- folds$inner_resamples

  expect_error(nested_tune_grid(wf, no_id, grid = det_grid()), "no id column")
})

test_that("an outer bootstrap is refused, not warned about", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)

  # rsample only warns here, so this design is reachable and has to be caught
  # on the way in (GP3). nested_resamples() refuses it at construction.
  suppressWarnings(
    boot_folds <- rsample::nested_cv(
      d,
      outside = rsample::bootstraps(times = 3),
      inside = rsample::vfold_cv(v = 3)
    )
  )

  expect_error(nested_tune_grid(wf, boot_folds), "cannot use a bootstrap")
})

test_that("`grid` must be candidates or a positive whole number", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(wf, folds, grid = det_grid()[0, , drop = FALSE]),
    "at least one candidate"
  )
  expect_error(nested_tune_grid(wf, folds, grid = 0), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = -1), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = 2.5), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = c(1, 2)), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = NA_integer_), "whole number")
  expect_error(nested_tune_grid(wf, folds, grid = "three"), "whole number")
})

test_that("`metrics` must be a metric set or NULL", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(nested_tune_grid(wf, folds, metrics = "rmse"), "metric_set")
  expect_error(
    nested_tune_grid(wf, folds, metrics = yardstick::rmse),
    "metric_set"
  )
})

test_that("the checks fire before any fitting happens", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # A bad argument costs a second, not a full inner tuning run: the error
  # arrives without the RNG ever being drawn from.
  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_grid(wf, folds, metrics = "rmse"))
  expect_identical(.Random.seed, before)
})

# The grid is judged against the workflow up front (M03). Both directions are
# wrong for every fold rather than for one, so both are call errors -- and once
# fold failures are recorded rather than raised, an unchecked grid would show up
# as an entire design failing instead.

test_that("a grid column not marked for tuning is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2)),
    "not marked for tuning"
  )
  # Named, so the caller knows which column to fix.
  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(not_a_param = 1:2)),
    "not_a_param"
  )
})

test_that("a tuned parameter with no grid column is refused", {
  skip_if_no_engines()
  skip_if_not_installed("dials")

  d <- make_reg_data()
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = tune::tune()),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  skip_if_not_installed("ranger")
  wf <- workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)
  folds <- valid_folds(d)

  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(min_n = c(2L, 10L))),
    "no column for"
  )
  expect_error(
    nested_tune_grid(wf, folds, grid = data.frame(min_n = c(2L, 10L))),
    "trees"
  )
})

test_that("a grid given as a size is not held to the column check", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # There are no columns to judge yet; tune generates them.
  expect_no_error(check_grid_params(wf, 5))
})

test_that("the grid check fires before any fitting happens", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_grid(
    wf,
    folds,
    grid = data.frame(not_a_param = 1:2)
  ))
  expect_identical(.Random.seed, before)
})

# The two list columns are checked element by element (M19). Before this, a bad
# element was not a call error at all: tune raised it once per fold, so the run
# cost a full pass and came back as an all-folds-failed object carrying tune's
# message rather than ours -- the shape check_grid_params() already prevents for
# a malformed grid.

test_that("a non-rset element of inner_resamples is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$inner_resamples[[2]] <- "not an rset"

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "inner_resamples")
  cnd <- tryCatch(
    nested_tune_grid(wf, bad, grid = det_grid()),
    error = function(e) e
  )
  # The position, so a design with many folds says which one to look at.
  expect_match(conditionMessage(cnd), "Element 2")
  expect_match(conditionMessage(cnd), "rset")
  expect_match(conditionMessage(cnd), "`resamples`")
  # What it holds instead, so the reader is not left guessing.
  expect_match(conditionMessage(cnd), "string")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
  expect_s3_class(cnd, "nestedtune_bad_design")
})

test_that("a non-rsplit element of splits is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  bad <- valid_folds(d)
  bad$splits[[1]] <- "not an rsplit"

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "splits")
  cnd <- tryCatch(
    nested_tune_grid(wf, bad, grid = det_grid()),
    error = function(e) e
  )
  expect_match(conditionMessage(cnd), "rsplit")
  expect_match(conditionMessage(cnd), "Element 1")
  expect_match(conditionMessage(cnd), "`resamples`")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
  expect_s3_class(cnd, "nestedtune_bad_design")
})

# The reachable route to such a design is not hand-editing: rsample's own
# constructor admits an `inside` that produces no rset, where nested_resamples()
# refuses it at construction (M18).

test_that("an rsample design whose inside produced no rset is refused", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  set.seed(1)
  bad <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = list()
  )

  expect_error(nested_tune_grid(wf, bad, grid = det_grid()), "inner_resamples")

  # The final fit no longer takes a design directly -- it takes a results
  # object, and a malformed design like this one never reaches nested_tune_grid()
  # far enough to produce one, so there is nothing further to check here.
})

# The negative half of the same rule: what the loop does not need, it does not
# check. A design carrying no `inside` attribute cannot be re-run by the final
# fit, and the loop is indifferent to that -- it never re-evaluates anything.

test_that("the loop still accepts a design with no inner specification", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)
  attr(folds, "inside") <- NULL

  res <- memoised(nested_tune_grid(wf, folds, grid = det_grid()))
  expect_identical(res$.completed, c(TRUE, TRUE))

  # And the result records no specification either: an attribute cannot hold
  # NULL, so this object is indistinguishable from one built before the
  # specification was recorded at all, which is why `nested_final_fit()`'s
  # refusal of it names both origins (M46, RR05 B1).
  expect_null(attr(res, "inside"))
  expect_false("inside" %in% names(attributes(res)))
})

test_that("a workflow with a model but no preprocessor is refused", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- valid_folds(d)
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = 10),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  model_only <- workflows::add_model(workflows::workflow(), spec)

  expect_error(
    nested_tune_grid(model_only, folds, grid = data.frame(min_n = c(2L, 10L))),
    "no preprocessor"
  )
  cnd <- tryCatch(
    nested_tune_grid(model_only, folds, grid = data.frame(min_n = c(2L, 10L))),
    error = function(e) e
  )
  # The remedy, as the neighbouring `object` checks give one.
  expect_match(conditionMessage(cnd), "add_formula|add_recipe|add_variables")
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_tune_grid"))
})

# `pre$actions` is not the same question as "has a preprocessor":
# workflows::add_case_weights() files an action there too. Counting them let a
# workflow with a model and case weights but no formula, recipe or variables
# slip the guard and fail once per outer fold -- and described that same
# workflow as carrying "a preprocessor only" when it had no model either.

test_that("case weights are not mistaken for a preprocessor", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  folds <- valid_folds(d)
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = 10),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  grid <- data.frame(min_n = c(2L, 10L))

  # The `case_weights` entry is added by hand rather than through
  # workflows::add_case_weights(), which would need a case-weights vector from
  # hardhat and so a dependency this package does not declare. What the check
  # reads is names(object$pre$actions), and that is what is staged here -- with
  # the weakness that comes with it: if workflows ever renamed the slot, this
  # test would keep passing while the real hole reopened. The end-to-end shape
  # was verified against a genuine add_case_weights() workflow at M19 review.
  weights_only <- workflows::add_model(workflows::workflow(), spec)
  weights_only$pre$actions$case_weights <- TRUE

  expect_false(has_preprocessor(weights_only))
  expect_error(
    nested_tune_grid(weights_only, folds, grid = grid),
    "no preprocessor"
  )

  # And the no-model bullet describes what is actually there: case weights are
  # not a preprocessor, so this workflow is empty of both.
  no_model <- workflows::workflow()
  no_model$pre$actions$case_weights <- TRUE
  cnd <- tryCatch(
    nested_tune_grid(no_model, folds, grid = grid),
    error = function(e) e
  )
  expect_match(conditionMessage(cnd), "no model specification")
  expect_match(conditionMessage(cnd), "is empty")

  # The predicate says yes to each of the three things that really preprocess.
  expect_true(has_preprocessor(workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    spec
  )))
  expect_true(has_preprocessor(
    workflows::workflow(recipes::recipe(y ~ x1 + x2 + x3 + x4, data = d), spec)
  ))
})

# Every refusal added here fires before the entry sample.int() draw. Seed
# *identity* cannot show this: both drivers install their restoring on.exit()
# before drawing, so .Random.seed is put back on every exit path including one
# that already drew and re-seeded. What discriminates is existence -- a session
# that has never drawn has no .Random.seed, and restore_rng() deliberately
# leaves in place any state it created.

test_that("the new refusals fire before the RNG is drawn from", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  refused <- list(
    function() {
      bad <- folds
      bad$inner_resamples[[2]] <- "not an rset"
      nested_tune_grid(wf, bad, grid = det_grid())
    },
    function() {
      bad <- folds
      bad$splits[[1]] <- "not an rsplit"
      nested_tune_grid(wf, bad, grid = det_grid())
    },
    function() {
      no_pre <- workflows::add_model(
        workflows::workflow(),
        parsnip::linear_reg()
      )
      nested_tune_grid(no_pre, folds, grid = det_grid())
    }
  )

  # Restored with on.exit() rather than withr::defer(): test_that() evaluates
  # its block as a function body, so on.exit() fires at the end of it, and withr
  # is deliberately not a dependency of this package (teardown-fixture-cache.R).
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv())
  on.exit(
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    },
    add = TRUE
  )

  for (refuse in refused) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
    expect_error(refuse())
    expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  }
})

# M48: what `...` accepts, and what a control may carry. Fitting is replaced
# by a sentinel so a refusal is shown to fire at entry rather than after the
# loop began, as test-nested-tune-bayes-checks.R does for its sibling.

grid_refusal <- function(expr) {
  sentinel <- function(...) {
    rlang::abort("fitting began", class = "nestedtune_sentinel")
  }
  testthat::local_mocked_bindings(dispatch_folds = sentinel)
  tryCatch(expr, error = function(cnd) cnd)
}

expect_grid_refused <- function(cnd, class, pattern) {
  testthat::expect_s3_class(cnd, class)
  testthat::expect_false(inherits(cnd, "nestedtune_sentinel"))
  testthat::expect_match(conditionMessage(cnd), pattern)
  testthat::expect_identical(
    conditionCall(cnd)[[1L]],
    as.name("nested_tune_grid")
  )
  invisible(cnd)
}

test_that("`...` accepts `control` and nothing else (M48, AC5)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  cnd <- grid_refusal(nested_tune_grid(wf, folds, nonesuch = 1))
  expect_grid_refused(cnd, "nestedtune_bad_dots", "nonesuch")

  cnd <- grid_refusal(nested_tune_grid(wf, folds, det_grid()))
  expect_grid_refused(cnd, "nestedtune_bad_dots", "unnamed")

  cnd <- grid_refusal(nested_tune_grid(
    wf,
    folds,
    control = tune::control_grid(),
    no = 1
  ))
  expect_grid_refused(cnd, "nestedtune_bad_dots", "`no`")

  # `call` is the name of the check's own formal: a caller's `call = ` once
  # bound there and slipped the fence (M48 review round 1, finding 1).
  cnd <- grid_refusal(nested_tune_grid(wf, folds, call = quote(bogus())))
  expect_grid_refused(cnd, "nestedtune_bad_dots", "`call`")
})

test_that("`control` must be what tune::control_grid() returns (M48, AC5)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  # A `control_bayes()` carries every slot `control_grid()` does and is still
  # refused: the class is the contract, not the slot list.
  bad <- list(
    tune::control_bayes(seed = 1L),
    list(allow_par = FALSE),
    "no",
    1
  )
  for (b in bad) {
    cnd <- grid_refusal(nested_tune_grid(wf, folds, control = b))
    expect_grid_refused(cnd, "nestedtune_bad_control", "control_grid")
  }

  # The other side of that contract: tune 2.1.0 gives `control_resamples()`
  # and `control_last_fit()` the `control_grid` class, so each is what
  # `control_grid()` returns and passes the fence -- the entry checks pass and
  # fitting begins (M48 review round 1, finding 5).
  for (ok in list(tune::control_resamples(), tune::control_last_fit())) {
    cnd <- grid_refusal(nested_tune_grid(wf, folds, control = ok))
    expect_s3_class(cnd, "nestedtune_sentinel")
  }
})

test_that("a control naming another event level is refused at entry (M48, AC3)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  cnd <- grid_refusal(nested_tune_grid(
    wf,
    folds,
    event_level = "first",
    control = tune::control_grid(event_level = "second")
  ))
  expect_grid_refused(cnd, "nestedtune_bad_control", "event_level")
  expect_match(conditionMessage(cnd), "\"first\"")
  expect_match(conditionMessage(cnd), "\"second\"")

  cnd <- grid_refusal(nested_tune_grid(
    wf,
    folds,
    event_level = "second",
    control = tune::control_grid()
  ))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

test_that("the control refusals fire before the RNG is drawn from (M48)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- valid_folds(d)

  set.seed(1)
  before <- get(".Random.seed", envir = globalenv())
  grid_refusal(nested_tune_grid(wf, folds, nonesuch = 1))
  grid_refusal(nested_tune_grid(wf, folds, control = "no"))
  grid_refusal(nested_tune_grid(
    wf,
    folds,
    control = tune::control_grid(event_level = "second")
  ))
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

# M55: every design refusal carries one class, names the driver the user
# called, and names every offending position or column -- not the first one
# found. The shapes are built by malformed_designs(); each record says what
# the message must name.

# The refusal as the condition it raised, with fitting replaced by a sentinel
# so a check that ran after the loop began surfaces as the sentinel's class.
refusal <- function(expr) {
  sentinel <- function(...) {
    rlang::abort("fitting began", class = "nestedtune_sentinel")
  }
  testthat::local_mocked_bindings(dispatch_folds = sentinel)
  # Wide enough that cli never wraps a joined position list, so the
  # all-positions assertions read the positions and not the line breaks.
  rlang::local_options(cli.width = 500L)
  tryCatch(expr, error = function(cnd) cnd)
}

# cli joins a vector as "1, 2, and 3"; the planted positions are the fact held
# independently of the check, cli only the spelling.
joined <- function(x) cli::format_inline("{x}")

test_that("every planted design is refused, naming every offender (M55, AC1-AC4)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  planted <- malformed_designs(d)
  expect_gt(length(planted), 20L)

  for (nm in names(planted)) {
    record <- planted[[nm]]
    cnd <- refusal(nested_tune_grid(wf, record$design, grid = det_grid()))
    expect_s3_class(cnd, "nestedtune_bad_design")
    expect_false(inherits(cnd, "nestedtune_sentinel"), info = nm)
    expect_identical(conditionCall(cnd)[[1L]], as.name("nested_tune_grid"))
    msg <- conditionMessage(cnd)
    expect_match(msg, "`resamples`", info = nm)
    if (length(record$rows) > 0L) {
      expect_match(msg, joined(record$rows), fixed = TRUE, info = nm)
    }
    for (column in record$columns) {
      expect_match(msg, paste0("\\b", column, "\\b"), info = nm)
    }
  }
})

test_that("each refusal says which defect it found (M55, AC1-AC3)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  planted <- malformed_designs(d)
  said <- function(nm) {
    conditionMessage(refusal(
      nested_tune_grid(wf, planted[[nm]]$design, grid = det_grid())
    ))
  }

  expect_match(said("inner_empty_first"), "no rows")
  expect_match(said("inner_empty_last"), "no rows")
  expect_match(said("label_na_first"), "NA")
  expect_match(said("label_na_last"), "NA")
  expect_match(said("label_na_level_first"), "NA")
  expect_match(said("label_na_level_last"), "NA")
  # An NA-only refusal is headed by missingness, not by the uniqueness claim.
  expect_no_match(said("label_na_first"), "uniquely")
  expect_match(said("label_repeat_last"), "uniquely")
  expect_match(said("label_repeat_last"), "1 and 3")
  expect_match(said("id_integer"), "integer")
  expect_match(said("id2_integer_before"), "integer")
  expect_match(said("weights_character_after"), "not named as rsample")
  expect_match(said("id10_character_after"), "not named as rsample")
  expect_match(said("id10_character_after"), "id9")
  expect_match(said("weights_numeric_before"), "weights")
  expect_match(said("extra_list_after"), "extra")
  # Both columns of a design carrying two, in one message.
  expect_match(said("two_columns"), "weights")
  expect_match(said("two_columns"), "extra")
})

test_that("the whole-object refusals carry the class too (M55, AC4)", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- det_nested(d)
  empty <- folds[0, ]
  class(empty) <- class(folds)
  no_id <- data.frame(row.names = seq_len(nrow(folds)))
  no_id$splits <- folds$splits
  no_id$inner_resamples <- folds$inner_resamples
  set.seed(1)
  boot <- suppressWarnings(rsample::nested_cv(
    d,
    outside = rsample::bootstraps(times = 2),
    inside = rsample::vfold_cv(v = 2)
  ))

  whole <- list(
    not_a_design = rsample::vfold_cv(d, v = 2),
    no_outer_folds = empty,
    no_id = no_id,
    bootstrap = boot
  )
  for (nm in names(whole)) {
    cnd <- refusal(nested_tune_grid(wf, whole[[nm]], grid = det_grid()))
    expect_s3_class(cnd, "nestedtune_bad_design")
    expect_identical(conditionCall(cnd)[[1L]], as.name("nested_tune_grid"))
  }
})

test_that("a well-formed design passes the entry check unchanged (M55, AC5)", {
  skip_if_no_engines()

  d <- make_reg_data()
  set.seed(1)
  from_rsample <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2, repeats = 2),
    inside = rsample::vfold_cv(v = 2)
  )
  set.seed(1)
  from_constructor <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2, repeats = 2),
    inside = rsample::vfold_cv(v = 2)
  )
  # The two repeated designs carry `id` and `id2`, `id` repeating across
  # repeats while the pair is unique -- the shape the tuple rule must admit.
  expect_identical(
    names(from_rsample),
    c("splits", "id", "id2", "inner_resamples")
  )
  expect_true(anyDuplicated(from_rsample$id) > 0L)

  factor_labels <- det_nested(d)
  factor_labels$id <- factor(factor_labels$id)

  well_formed <- list(
    det_nested = det_nested(d),
    factor_labels = factor_labels,
    valid_folds = valid_folds(d),
    repeated_design = repeated_design(),
    nested_resamples = from_constructor,
    nested_cv = from_rsample
  )
  for (nm in names(well_formed)) {
    design <- well_formed[[nm]]
    expect_invisible(check_nested(design))
    expect_identical(check_nested(design), design, info = nm)
  }

  # And the unaltered fixture the plantings start from is not refused by the
  # driver either: the refusal is about the planting, not the fixture.
  wf <- det_workflow(d)
  cnd <- refusal(nested_tune_grid(wf, det_nested(d), grid = det_grid()))
  expect_s3_class(cnd, "nestedtune_sentinel")
})
