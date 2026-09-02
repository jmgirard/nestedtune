# A recipe selector the caller left unqualified has to resolve on a daemon too.
#
# THE DEFECT (issue #37). `tune` loads a workflow's `required_pkgs()` as
# NAMESPACES and only ATTACHES them on its own parallel path -- `attach_pkgs()`
# is a no-op whenever the strategy is sequential (tune 2.1.0). The inner tuning
# run here is sequential by construction (`control_grid(allow_par = FALSE)`),
# so nothing attaches anything inside a daemon. A selector a user types
# unqualified -- `all_numeric_predictors()`, as in the reprex on #37 -- is a
# quosure whose environment leads out to the search path, and a daemon's search
# path carries base R and nothing else. Every outer fold failed with
# `could not find function "all_numeric_predictors"`, while the same call ran
# clean serially off the caller's own attached packages.
#
# WHY THE EXISTING PARALLEL FILES NEVER CAUGHT IT. Every recipe fixture in
# `helper-orchestration.R` qualifies its selectors -- `recipes::all_predictors()`
# at `unstable_workflow()` -- so the name resolves through the namespace and
# never touches a search path at all. The bug lives entirely in the unqualified
# form, which is the form users write.
#
# WHAT THE TWO SEARCH-PATH PROBES ARE FOR. The completion assertion alone would
# also pass if something else in the stack happened to attach recipes. Asking
# every daemon before and after pins WHICH mechanism made the fold work: absent
# beforehand, present afterwards, so the attach is this package's doing.

test_that("a recipe selector the caller left unqualified resolves on a daemon", {
  skip_if_no_daemons()
  skip_if_not_installed("recipes")

  # The caller's own search path is what resolves the bare selector serially --
  # `library(tidymodels)` in the reprex. Attached here for the same reason, and
  # dropped again so no other file inherits it.
  if (!"package:recipes" %in% search()) {
    library(recipes)
    on.exit(detach("package:recipes"), add = TRUE)
  }

  d <- sep_data()
  # Unqualified on purpose: `recipes::all_predictors()` is what every other
  # fixture writes, and it cannot reproduce this.
  rec <- recipes::step_pca(
    recipes::recipe(y ~ ., data = d),
    all_predictors(),
    num_comp = tune::tune()
  )
  wf <- workflows::workflow(rec, parsnip::linear_reg())
  nested <- sep_nested(d)

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  attached <- function() {
    # An explicit bound rather than the default constant, so the ledger's
    # seconds can be re-read from this line (test-suite-hygiene.R). The pool is
    # warm by now and this probe reads `search()`, so 30 s is a worst case with
    # nothing cold in it.
    answers <- collect_bounded(
      mirai::everywhere("package:recipes" %in% search()),
      seconds = 30
    )
    vapply(answers, isTRUE, logical(1))
  }

  expect_false(any(attached()))

  set.seed(20)
  res <- without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = data.frame(num_comp = 1:2))
  )

  expect_identical(last_dispatch(), "parallel")
  expect_true(all(res$.completed))
  expect_true(all(attached()))
})

# The tuner's package rides beside the workflow's (M50, T4): a racing run
# attaches finetune in every daemon before the first fold is sent, by the same
# mechanism, and the two search-path probes pin that it was this package's
# doing.

test_that("a racing run attaches finetune in every daemon", {
  skip_if_no_daemons()
  skip_if_no_race_fixture("tune_race_anova")

  d <- make_reg_data()
  wf <- det_workflow(d)
  nested <- det_nested(d)

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  attached <- function() {
    answers <- collect_bounded(
      mirai::everywhere("package:finetune" %in% search()),
      seconds = 30
    )
    vapply(answers, isTRUE, logical(1))
  }

  expect_false(any(attached()))

  set.seed(20)
  res <- without_pkgload_warning(
    nested_tune_race_anova(
      wf,
      nested,
      grid = det_grid(),
      metrics = reg_metrics(),
      control = race_control()
    )
  )

  expect_identical(last_dispatch(), "parallel")
  expect_true(all(res$.completed))
  expect_true(all(attached()))
})
