# The tuner registry (M50, T1): one entry per inner tuner, read by every site
# that once switched on the tuner's name. Each entry is held to its own
# package: the function it names lives there, and its default control carries
# the class a caller's control is held to.

test_that("every registry entry names a function in its package and a control of its class", {
  # One fact held independently of the enumeration: the four tuners the
  # package offers are all registered.
  expect_setequal(
    names(tuner_registry),
    c("tune_grid", "tune_bayes", "tune_race_anova", "tune_race_win_loss")
  )
  for (nm in names(tuner_registry)) {
    entry <- tuner_registry[[nm]]
    expect_true(entry$package %in% entry$requires, info = nm)
    if (!rlang::is_installed(entry$package)) {
      next
    }
    expect_true(
      is.function(getExportedValue(entry$package, nm)),
      info = nm
    )
    expect_s3_class(entry$control(), entry$control_class)
    expect_s3_class(default_control(nm), control_class(nm))
  }
})

test_that("a name the registry does not hold is an internal error", {
  expect_error(tuner_entry("tune_nonesuch"), "Unknown tuner")
  expect_error(default_control("tune_nonesuch"), "Unknown tuner")
  expect_error(control_class("tune_nonesuch"), "Unknown tuner")
})

test_that("the racers take a grid and do not iterate; the Bayesian tuner is the reverse", {
  expect_true(tuner_takes_grid("tune_grid"))
  expect_true(tuner_takes_grid("tune_race_anova"))
  expect_true(tuner_takes_grid("tune_race_win_loss"))
  expect_false(tuner_takes_grid("tune_bayes"))
  expect_true(tuner_registry$tune_bayes$iterates)
  expect_false(tuner_registry$tune_race_anova$iterates)

  desc <- tuner_race("tune_race_anova", data.frame(num_comp = 1:3))
  expect_identical(desc$tuner, "tune_race_anova")
  expect_identical(desc$args, list(grid = data.frame(num_comp = 1:3)))
})
