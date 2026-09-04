# The host's entry check reads the workflow's whole package list (M58, AC4).
#
# Before M58 the check asked `parsnip::required_pkgs()` of the engine alone,
# so a recipe step whose `required_pkgs()` names a package this library lacks
# reached the first fold and failed there, one fit later than the engine's
# refusal. The check now asks `tune::required_pkgs()` of the workflow -- the
# list the daemon pre-flight and the attach step read -- and refuses under the
# class the tuner refusal carries, with an install call the user can paste.
#
# The fixture is a step with no prep or bake of its own: nothing here fits,
# because the refusal fires at entry, and `required_pkgs()` is the only method
# the check consults. The method is registered on the generic's own namespace,
# where S3 dispatch from `recipes:::required_pkgs.recipe()` finds it.

ABSENT_PKG <- "nestedtune.no.such.package"

absent_step_workflow <- function(data) {
  registerS3method(
    "required_pkgs",
    "step_nestedtune_absent",
    function(x, ...) ABSENT_PKG,
    envir = asNamespace("generics")
  )
  step <- recipes::step(
    subclass = "nestedtune_absent",
    role = NA,
    trained = FALSE,
    skip = FALSE,
    id = "absent"
  )
  rec <- recipes::add_step(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = data),
    step
  )
  workflows::workflow(rec, parsnip::linear_reg())
}

test_that("the fixture's package reaches the workflow's list and is not installed", {
  # The precondition, asserted: the step's method is what puts the name on
  # the list, and nothing on this machine answers to it.
  skip_if_no_engines()
  wf <- absent_step_workflow(make_reg_data())
  expect_true(ABSENT_PKG %in% tune::required_pkgs(wf))
  expect_true(ABSENT_PKG %in% workflow_pkgs(wf))
  expect_false(rlang::is_installed(ABSENT_PKG))
})

test_that("a workflow needing a package the host lacks is refused at every entry point", {
  skip_if_no_engines()
  skip_if_not_installed("finetune")
  skip_if_not_installed("lme4")
  skip_if_not_installed("BradleyTerry2")

  d <- make_reg_data()
  wf <- absent_step_workflow(d)
  nested <- det_nested(d, v = 3)
  results <- final_results(d)

  entries <- list(
    nested_tune_grid = function() nested_tune_grid(wf, nested, grid = 3),
    nested_tune_bayes = function() nested_tune_bayes(wf, nested, iter = 1),
    nested_tune_race_anova = function() {
      nested_tune_race_anova(wf, nested, grid = 3, control = race_control())
    },
    nested_tune_race_win_loss = function() {
      nested_tune_race_win_loss(wf, nested, grid = 3, control = race_control())
    },
    nested_tune_sim_anneal = function() {
      nested_tune_sim_anneal(wf, nested, iter = 1)
    },
    nested_final_fit = function() nested_final_fit(wf, results)
  )

  for (name in names(entries)) {
    reset_dispatch_record()
    err <- expect_error(
      entries[[name]](),
      class = "nestedtune_pkg_not_installed"
    )
    msg <- conditionMessage(err)
    expect_match(msg, ABSENT_PKG, fixed = TRUE)
    expect_match(
      msg,
      'install.packages("nestedtune.no.such.package")',
      fixed = TRUE
    )
    # Named for the user's call, as every entry refusal is.
    expect_identical(conditionCall(err)[[1L]], as.name(name))
    # And before any fold: nothing was dispatched, serially or otherwise.
    expect_null(last_dispatch())
  }
})

test_that("the engine's package is still refused, under the same class", {
  # What the check did before M58, kept: the engine's list is part of the
  # workflow's, so the older refusal fires through the widened check.
  skip_if_no_engines()
  skip_if(rlang::is_installed("kknn"))

  d <- make_reg_data()
  missing_engine <- workflows::workflow(
    y ~ x1 + x2 + x3 + x4,
    parsnip::set_mode(
      parsnip::set_engine(parsnip::nearest_neighbor(), "kknn"),
      "regression"
    )
  )
  err <- expect_error(
    nested_tune_grid(missing_engine, det_nested(d)),
    class = "nestedtune_pkg_not_installed"
  )
  expect_match(conditionMessage(err), "kknn")
})

test_that("a workflow whose packages are all installed passes the check silently", {
  # The case a new refusal must stay silent in: the fixture workflow's own
  # list, every name installed.
  skip_if_no_engines()
  wf <- det_workflow(make_reg_data())
  expect_identical(check_workflow_pkgs(wf), workflow_pkgs(wf))
})
