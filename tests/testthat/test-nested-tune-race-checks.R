# Every refusal the two racing exports make at entry, fired once (M50 AC5).
# GP3: a provably wrong call is refused before a whole outer loop is paid for.
#
# Two halves. The refusals that are racing's own -- a package the race needs
# that is not installed, a control of another class, a burn-in no fold's
# inner design can meet -- each fire with a class of their own, naming the
# user's call, for both racers. And every check the grid orchestrator makes
# is made here too: the set is read off both function bodies rather than
# listed by hand, so a check added to one and forgotten in the other fails by
# name.

race_folds <- function(d) det_nested(d, v = 3)

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

expect_refused <- function(cnd, class, pattern, fn) {
  testthat::expect_s3_class(cnd, class)
  testthat::expect_false(inherits(cnd, "nestedtune_sentinel"))
  testthat::expect_match(conditionMessage(cnd), pattern)
  testthat::expect_identical(conditionCall(cnd)[[1L]], as.name(fn))
  invisible(cnd)
}

export_name <- function(fn) {
  switch(
    fn,
    tune_race_anova = "nested_tune_race_anova",
    tune_race_win_loss = "nested_tune_race_win_loss"
  )
}

# A call to the racing export by its own name, evaluated in the test's frame:
# a refusal's `conditionCall()` is the call as the user wrote it, so calling
# through a local alias would make every refusal name the alias.
race_call <- function(fn, ...) {
  eval(rlang::call2(export_name(fn), !!!rlang::enexprs(...)), parent.frame())
}

# The absence of one package, seen through the seam the check reads: every
# other package answers as it really is, so the refusal is shown to be about
# the one made absent and not about a mock that says no to everything.
local_absent <- function(pkg, env = parent.frame()) {
  real <- rlang::is_installed
  testthat::local_mocked_bindings(
    is_installed = function(pkg_, ...) {
      if (identical(pkg_, pkg)) FALSE else real(pkg_, ...)
    },
    .package = "rlang",
    .env = env
  )
}

test_that("finetune must be installed, for both racers", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  for (fn in RACERS) {
    local({
      local_absent("finetune")
      cnd <- refusal(race_call(fn, wf, folds, grid = det_grid()))
      expect_refused(
        cnd,
        "nestedtune_pkg_not_installed",
        "finetune",
        export_name(fn)
      )
      expect_match(conditionMessage(cnd), "not installed")
    })
    # The discrimination: with nothing made absent, the same call passes the
    # check and reaches the sentinel.
    cnd <- refusal(race_call(
      fn,
      wf,
      folds,
      grid = det_grid(),
      control = race_control()
    ))
    expect_s3_class(cnd, "nestedtune_sentinel")
  }
})

test_that("each race's own model-fitting package must be installed", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  # lme4 fits the ANOVA; BradleyTerry2 fits the win/loss model. Each refusal
  # names its package, and neither racer refuses on the other's.
  local({
    local_absent("BradleyTerry2")
    cnd <- refusal(nested_tune_race_win_loss(wf, folds, grid = det_grid()))
    expect_refused(
      cnd,
      "nestedtune_pkg_not_installed",
      "BradleyTerry2",
      "nested_tune_race_win_loss"
    )
    cnd <- refusal(nested_tune_race_anova(
      wf,
      folds,
      grid = det_grid(),
      control = race_control()
    ))
    expect_s3_class(cnd, "nestedtune_sentinel")
  })
  local({
    local_absent("lme4")
    cnd <- refusal(nested_tune_race_anova(wf, folds, grid = det_grid()))
    expect_refused(
      cnd,
      "nestedtune_pkg_not_installed",
      "lme4",
      "nested_tune_race_anova"
    )
    cnd <- refusal(nested_tune_race_win_loss(
      wf,
      folds,
      grid = det_grid(),
      control = race_control()
    ))
    expect_s3_class(cnd, "nestedtune_sentinel")
  })
})

test_that("`control` must be what finetune::control_race() returns", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  # The grid control is the one a caller is likeliest to reach for, and
  # finetune itself would accept it (`condense_control()` reads slots by
  # name).
  for (fn in RACERS) {
    for (bad in list(
      tune::control_grid(),
      tune::control_bayes(seed = 1L),
      list(burn_in = 2),
      "no",
      1
    )) {
      cnd <- refusal(race_call(fn, wf, folds, grid = det_grid(), control = bad))
      expect_refused(
        cnd,
        "nestedtune_bad_control",
        "finetune::control_race",
        export_name(fn)
      )
    }
  }
})

test_that("an inner design not larger than the burn-in is refused at entry", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  for (fn in RACERS) {
    # finetune's default `burn_in` is 3 and the design holds 3 inner
    # resamples: the case every racing fixture in this suite sidesteps, and
    # the one a user meets first.
    cnd <- refusal(race_call(fn, wf, folds, grid = det_grid()))
    expect_refused(
      cnd,
      "nestedtune_bad_burn_in",
      "burn_in",
      export_name(fn)
    )
    # The message names the count and the burn-in.
    expect_match(conditionMessage(cnd), "3 inner resamples")
    expect_match(conditionMessage(cnd), "not more than 3")

    # A burn-in above the count, and one fold alone falling short: the
    # refusal names the fold.
    cnd <- refusal(race_call(
      fn,
      wf,
      folds,
      grid = det_grid(),
      control = finetune::control_race(burn_in = 5)
    ))
    expect_refused(cnd, "nestedtune_bad_burn_in", "burn_in", export_name(fn))
    expect_match(conditionMessage(cnd), "not more than 5")

    short <- folds
    set.seed(1)
    short$inner_resamples[[2L]] <- rsample::vfold_cv(
      rsample::analysis(folds$splits[[2L]]),
      v = 2
    )
    cnd <- refusal(race_call(
      fn,
      wf,
      short,
      grid = det_grid(),
      control = race_control()
    ))
    expect_refused(cnd, "nestedtune_bad_burn_in", "burn_in", export_name(fn))
    expect_match(conditionMessage(cnd), "Outer fold 2 holds 2 inner resamples")
    expect_match(conditionMessage(cnd), "not more than 2")
  }
})

# The shared checks. The list is derived, not written: every `check_*()` the
# grid orchestrator's body calls must appear in the racing body -- the grid
# checks included, since the racers take a grid.

check_calls <- function(fn) {
  nms <- all.names(body(fn))
  sort(unique(nms[startsWith(nms, "check_")]))
}

test_that("every check the grid path makes, the racing path makes too", {
  grid_checks <- check_calls(nested_tune_grid)
  race_checks <- check_calls(nested_tune_race)

  # One fact held independently of the derivation: the enumeration cannot
  # silently empty.
  expect_true(all(c("check_workflow", "check_grid") %in% grid_checks))

  expect_identical(setdiff(grid_checks, race_checks), character(0))
  # And the two that are racing's own are there beside them.
  expect_true(all(
    c("check_tuner_installed", "check_race_burn_in") %in% race_checks
  ))
})

test_that("each shared check fires through both racing exports", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)
  ctrl <- race_control()

  for (fn in RACERS) {
    fired <- list(
      check_dots_control = function() {
        race_call(fn, wf, folds, 3, control = ctrl)
      },
      check_control = function() race_call(fn, wf, folds, control = "no"),
      check_workflow = function() {
        race_call(fn, parsnip::linear_reg(), folds, control = ctrl)
      },
      check_nested = function() {
        race_call(fn, wf, rsample::vfold_cv(d, v = 2), control = ctrl)
      },
      check_grid = function() {
        race_call(fn, wf, folds, grid = 0, control = ctrl)
      },
      check_grid_params = function() {
        race_call(
          fn,
          wf,
          folds,
          grid = data.frame(nonesuch = 1:3),
          control = ctrl
        )
      },
      check_metrics = function() {
        race_call(fn, wf, folds, metrics = "rmse", control = ctrl)
      },
      check_param_info = function() {
        race_call(
          fn,
          wf,
          folds,
          param_info = data.frame(num_comp = 1:3),
          control = ctrl
        )
      },
      check_event_level = function() {
        race_call(fn, wf, folds, event_level = "third", control = ctrl)
      },
      check_eval_time = function() {
        race_call(fn, wf, folds, eval_time = -1, control = ctrl)
      }
    )
    patterns <- c(
      check_dots_control = "accepts `control`",
      check_control = "control_race",
      check_workflow = "must be a",
      check_nested = "nested resampling design",
      check_grid = "grid",
      check_grid_params = "not marked for tuning",
      check_metrics = "metric_set",
      check_param_info = "parameters",
      check_event_level = "event_level",
      check_eval_time = "eval_time"
    )

    expect_identical(
      setdiff(check_calls(nested_tune_grid), names(fired)),
      character(0)
    )

    for (nm in names(fired)) {
      cnd <- refusal(fired[[nm]]())
      expect_s3_class(cnd, "error")
      expect_false(inherits(cnd, "nestedtune_sentinel"))
      expect_match(conditionMessage(cnd), patterns[[nm]], info = nm)
      expect_identical(conditionCall(cnd)[[1L]], as.name(export_name(fn)))
    }
  }
})

test_that("a control naming another event level is refused at entry", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  for (fn in RACERS) {
    cnd <- refusal(race_call(
      fn,
      wf,
      folds,
      event_level = "first",
      control = finetune::control_race(burn_in = 2, event_level = "second")
    ))
    expect_refused(
      cnd,
      "nestedtune_bad_control",
      "event_level",
      export_name(fn)
    )

    # A control left at finetune's default takes the argument's level.
    cnd <- refusal(race_call(
      fn,
      wf,
      folds,
      event_level = "second",
      control = race_control()
    ))
    expect_s3_class(cnd, "nestedtune_sentinel")
  }
})

test_that("a refusal leaves the RNG where it found it", {
  skip_if_no_race_fixture()

  d <- make_reg_data()
  wf <- det_workflow(d)
  folds <- race_folds(d)

  set.seed(1)
  before <- .Random.seed
  for (fn in RACERS) {
    expect_error(race_call(fn, wf, folds, grid = det_grid()))
    expect_error(race_call(fn, wf, folds, control = tune::control_grid()))
    expect_error(race_call(fn, wf, folds, grid = 0, control = race_control()))
  }
  expect_identical(.Random.seed, before)
})
