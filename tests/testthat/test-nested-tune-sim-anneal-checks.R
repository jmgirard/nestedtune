# Every refusal `nested_tune_sim_anneal()` makes at entry, fired once (M51
# AC3). GP3: a provably wrong call is refused before a whole outer loop is
# paid for.
#
# Two halves. The refusals that are this orchestrator's own -- finetune not
# installed, `iter` below its floor of 1, `initial` below its floor of 1 or a
# `tune_results`, a control of another class -- each fire with a class of
# their own, naming the user's call. And every check the Bayesian sibling
# makes, other than the one that judges an acquisition function, is made here
# too: the set is read off both function bodies rather than listed by hand,
# so a check added to one and forgotten in the other fails by name.

anneal_folds <- function(d) det_nested(d, v = 2)

# The refusal, as the condition it raised. Fitting is replaced by a sentinel
# so a check that ran AFTER the loop began would surface as the sentinel's
# class rather than its own -- which is what separates "refused at entry"
# from "refused eventually".
refusal <- function(expr) {
  sentinel <- function(...) {
    rlang::abort("fitting began", class = "nestedtune_sentinel")
  }
  testthat::local_mocked_bindings(dispatch_folds = sentinel)
  tryCatch(expr, error = function(cnd) cnd)
}

expect_refused <- function(cnd, class, pattern) {
  testthat::expect_s3_class(cnd, class)
  testthat::expect_false(inherits(cnd, "nestedtune_sentinel"))
  testthat::expect_match(conditionMessage(cnd), pattern)
  testthat::expect_identical(
    conditionCall(cnd)[[1L]],
    as.name("nested_tune_sim_anneal")
  )
  invisible(cnd)
}

# The absence of one package, seen through the seam the check reads: every
# other package answers as it really is, so the refusal is shown to be about
# the one made absent and not about a mock that says no to everything.
local_absent <- function(pkg, env = parent.frame()) {
  real <- rlang::is_installed
  testthat::local_mocked_bindings(
    is_installed = function(pkg_, ...) {
      if (pkg_ %in% pkg) FALSE else real(pkg_, ...)
    },
    .package = "rlang",
    .env = env
  )
}

test_that("finetune must be installed", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  local({
    local_absent("finetune")
    cnd <- refusal(nested_tune_sim_anneal(wf, folds))
    expect_refused(cnd, "nestedtune_pkg_not_installed", "finetune")
    expect_match(conditionMessage(cnd), "not installed")
    expect_match(
      conditionMessage(cnd),
      'install.packages("finetune")',
      fixed = TRUE
    )
  })
  # The discrimination: with nothing made absent, the same call passes the
  # check and reaches the sentinel.
  cnd <- refusal(nested_tune_sim_anneal(wf, folds, control = anneal_control()))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

test_that("`iter` must be a single whole number of at least 1", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  # Each axis the criterion names has its exemplar: below the floor (0, where
  # finetune runs two iterations, and -1), fractional, non-numeric (character,
  # logical, list, NULL), length 0 and 2, `NA` in both types, and non-finite.
  for (bad in list(
    0,
    -1,
    2.5,
    "3",
    TRUE,
    list(1),
    NULL,
    numeric(0),
    c(1, 2),
    NA,
    NA_real_,
    Inf
  )) {
    cnd <- refusal(nested_tune_sim_anneal(wf, folds, iter = bad))
    expect_refused(cnd, "nestedtune_bad_iter", "at least 1")
  }
  # The value is named when there is one to name.
  cnd <- refusal(nested_tune_sim_anneal(wf, folds, iter = 0))
  expect_match(conditionMessage(cnd), "Got 0")

  # The floor is this sibling's own: `nested_tune_bayes()` still accepts 0.
  expect_no_error(check_iter(0))
  expect_error(check_iter(0, floor = 1), class = "nestedtune_bad_iter")

  # And 1 is accepted: the checks pass and the loop is about to begin.
  cnd <- refusal(nested_tune_sim_anneal(
    wf,
    folds,
    iter = 1,
    control = anneal_control()
  ))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

test_that("`initial` must be a single whole number of at least 1", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  for (bad in list(
    0,
    -3,
    2.5,
    "5",
    TRUE,
    list(1),
    NULL,
    numeric(0),
    c(3, 4),
    NA,
    NA_real_,
    Inf
  )) {
    cnd <- refusal(nested_tune_sim_anneal(wf, folds, initial = bad))
    # The class is shared with the `tune_results` refusal below, so the
    # message says which of the two fired.
    expect_refused(cnd, "nestedtune_bad_initial", "at least 1")
  }

  # The floor is this sibling's own: the Bayesian sibling's is 2.
  expect_no_error(check_initial(1, floor = 1))
  expect_error(check_initial(1), class = "nestedtune_bad_initial")

  cnd <- refusal(nested_tune_sim_anneal(
    wf,
    folds,
    initial = 1,
    control = anneal_control()
  ))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

test_that("`initial` refuses a tune_results, which finetune would accept", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  # A genuine tuning run, so the refusal is shown to fire on the object
  # tune's own `check_initial()` accepts rather than on a stand-in wearing
  # its class.
  set.seed(1)
  earlier <- tune::tune_grid(
    wf,
    resamples = folds$inner_resamples[[1L]],
    grid = det_grid(),
    control = tune::control_grid(allow_par = FALSE)
  )
  expect_s3_class(earlier, "tune_results")

  cnd <- refusal(nested_tune_sim_anneal(wf, folds, initial = earlier))
  expect_refused(cnd, "nestedtune_bad_initial", "not a")
  expect_match(conditionMessage(cnd), "tune_results")
  expect_match(conditionMessage(cnd), "assessment rows")
  expect_no_match(conditionMessage(cnd), "at least 1")
})

test_that("`control` must be what finetune::control_sim_anneal() returns", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  # The Bayesian control is the one a caller is likeliest to reach for, and
  # finetune itself would run under it (`condense_control()` reads slots by
  # name); the racing control is finetune's own other class.
  for (bad in list(
    tune::control_bayes(seed = 1L),
    finetune::control_race(),
    list(allow_par = FALSE),
    "no",
    1
  )) {
    cnd <- refusal(nested_tune_sim_anneal(wf, folds, control = bad))
    expect_refused(cnd, "nestedtune_bad_control", "control_sim_anneal")
    expect_match(conditionMessage(cnd), "finetune::control_sim_anneal")
    # The class is shared with the event-level conflict below, so the
    # message says which of the two fired.
    expect_no_match(conditionMessage(cnd), "event_level")
  }
})

test_that("a control naming another event level is refused at entry", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  cnd <- refusal(nested_tune_sim_anneal(
    wf,
    folds,
    event_level = "first",
    control = finetune::control_sim_anneal(event_level = "second")
  ))
  expect_refused(cnd, "nestedtune_bad_control", "event_level")
  expect_match(conditionMessage(cnd), "\"first\"")
  expect_match(conditionMessage(cnd), "\"second\"")

  # A control left at finetune's default takes the argument's level.
  cnd <- refusal(nested_tune_sim_anneal(
    wf,
    folds,
    event_level = "second",
    control = anneal_control()
  ))
  expect_s3_class(cnd, "nestedtune_sentinel")
})

# The shared checks. The list is derived, not written: every `check_*()` the
# Bayesian orchestrator's body calls, less the one that judges an acquisition
# function, must appear in this orchestrator's body, and the package check
# beside them.

check_calls <- function(fn) {
  nms <- all.names(body(fn))
  sort(unique(nms[startsWith(nms, "check_")]))
}

test_that("every check the Bayesian path makes, the annealing path makes too", {
  bayes_checks <- check_calls(nested_tune_bayes)
  anneal_checks <- check_calls(nested_tune_sim_anneal)

  # One fact held independently of the derivation: the enumeration cannot
  # silently empty.
  expect_true(all(c("check_iter", "check_initial") %in% bayes_checks))

  shared <- setdiff(bayes_checks, "check_objective")
  expect_identical(setdiff(shared, anneal_checks), character(0))
  # No acquisition function here, and no grid; the package check is added.
  expect_false(any(
    c("check_objective", "check_grid", "check_grid_params") %in% anneal_checks
  ))
  expect_true("check_tuner_installed" %in% anneal_checks)
})

test_that("each shared check fires through nested_tune_sim_anneal()", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)
  ctrl <- anneal_control()

  fired <- list(
    check_dots_control = function() {
      nested_tune_sim_anneal(wf, folds, 3, control = ctrl)
    },
    check_control = function() {
      nested_tune_sim_anneal(wf, folds, control = "no")
    },
    check_workflow = function() {
      nested_tune_sim_anneal(parsnip::linear_reg(), folds, control = ctrl)
    },
    check_nested = function() {
      nested_tune_sim_anneal(wf, rsample::vfold_cv(d, v = 2), control = ctrl)
    },
    check_iter = function() {
      nested_tune_sim_anneal(wf, folds, iter = 0, control = ctrl)
    },
    check_initial = function() {
      nested_tune_sim_anneal(wf, folds, initial = 0, control = ctrl)
    },
    check_metrics = function() {
      nested_tune_sim_anneal(wf, folds, metrics = "rmse", control = ctrl)
    },
    check_param_info = function() {
      nested_tune_sim_anneal(
        wf,
        folds,
        param_info = data.frame(num_comp = 1:3),
        control = ctrl
      )
    },
    check_event_level = function() {
      nested_tune_sim_anneal(wf, folds, event_level = "third", control = ctrl)
    },
    check_eval_time = function() {
      nested_tune_sim_anneal(wf, folds, eval_time = -1, control = ctrl)
    }
  )
  patterns <- c(
    check_dots_control = "accepts `control`",
    check_control = "control_sim_anneal",
    check_workflow = "must be a",
    check_nested = "nested resampling design",
    check_iter = "at least 1",
    check_initial = "at least 1",
    check_metrics = "metric_set",
    check_param_info = "parameters",
    check_event_level = "event_level",
    check_eval_time = "eval_time"
  )

  shared <- setdiff(check_calls(nested_tune_bayes), "check_objective")
  expect_identical(setdiff(shared, names(fired)), character(0))

  for (nm in names(fired)) {
    cnd <- refusal(fired[[nm]]())
    expect_s3_class(cnd, "error")
    expect_false(inherits(cnd, "nestedtune_sentinel"))
    expect_match(conditionMessage(cnd), patterns[[nm]], info = nm)
    expect_identical(
      conditionCall(cnd)[[1L]],
      as.name("nested_tune_sim_anneal")
    )
  }
})

test_that("`...` accepts `control` and nothing else", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  cnd <- refusal(nested_tune_sim_anneal(wf, folds, nonesuch = 1))
  expect_refused(cnd, "nestedtune_bad_dots", "nonesuch")

  cnd <- refusal(nested_tune_sim_anneal(wf, folds, 3))
  expect_refused(cnd, "nestedtune_bad_dots", "unnamed")

  cnd <- refusal(nested_tune_sim_anneal(wf, folds, call = quote(bogus())))
  expect_refused(cnd, "nestedtune_bad_dots", "`call`")
})

test_that("a refusal leaves the RNG where it found it", {
  skip_if_no_anneal_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- anneal_folds(d)

  set.seed(1)
  before <- .Random.seed
  expect_error(nested_tune_sim_anneal(wf, folds, iter = 0))
  expect_error(nested_tune_sim_anneal(wf, folds, initial = 0))
  expect_error(nested_tune_sim_anneal(
    wf,
    folds,
    control = tune::control_grid()
  ))
  expect_identical(.Random.seed, before)
})
