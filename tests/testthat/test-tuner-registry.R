# The tuner registry (M50, T1): one entry per inner tuner, read by every site
# that once switched on the tuner's name. Each entry is held to its own
# package: the function it names lives there, and its default control carries
# the class a caller's control is held to.

test_that("every registry entry names a function in its package and a control of its class", {
  # One fact held independently of the enumeration: the five tuners the
  # package offers are all registered.
  expect_setequal(
    names(tuner_registry),
    c(
      "tune_grid",
      "tune_bayes",
      "tune_race_anova",
      "tune_race_win_loss",
      "tune_sim_anneal"
    )
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
  expect_error(tuner_entry(NULL), "Unknown tuner")
  expect_error(tuner_entry(c("tune_grid", "tune_bayes")), "Unknown tuner")
  expect_error(default_control("tune_nonesuch"), "Unknown tuner")
  expect_error(control_class("tune_nonesuch"), "Unknown tuner")
})

test_that("the racers take a grid and do not iterate; the Bayesian and annealing tuners are the reverse", {
  expect_true(tuner_takes_grid("tune_grid"))
  expect_true(tuner_takes_grid("tune_race_anova"))
  expect_true(tuner_takes_grid("tune_race_win_loss"))
  expect_false(tuner_takes_grid("tune_bayes"))
  expect_false(tuner_takes_grid("tune_sim_anneal"))
  expect_true(tuner_registry$tune_bayes$iterates)
  expect_true(tuner_registry$tune_sim_anneal$iterates)
  expect_false(tuner_registry$tune_race_anova$iterates)

  # `tuner_iterates()` is total: a name the registry does not hold, or no
  # name at all, does not iterate rather than aborting, so a final fit built
  # by hand prints its count alone (M51).
  expect_true(tuner_iterates("tune_bayes"))
  expect_true(tuner_iterates("tune_sim_anneal"))
  expect_false(tuner_iterates("tune_grid"))
  expect_false(tuner_iterates("tune_nonesuch"))
  expect_false(tuner_iterates(NULL))

  anneal <- tuner_anneal(iter = 2, initial = 3)
  expect_identical(anneal$tuner, "tune_sim_anneal")
  expect_identical(anneal$args, list(iter = 2, initial = 3))

  desc <- tuner_race("tune_race_anova", data.frame(num_comp = 1:3))
  expect_identical(desc$tuner, "tune_race_anova")
  expect_identical(desc$args, list(grid = data.frame(num_comp = 1:3)))
})

# The `?nested_final_fit` reproducibility recipe carries a branch for every
# tuner the registry names: each tuning function appears as a call inside
# the recipe's code block (M56 AC5). Read from the source tree where `man/`
# is on disk and from the installed help database under `R CMD check`.
test_that("the final-fit reproducibility recipe calls every registry tuner", {
  src <- test_path("..", "..", "man", "nested_final_fit.Rd")
  rd <- if (file.exists(src)) {
    tools::parse_Rd(src)
  } else {
    tools::Rd_db("nestedtune")[["nested_final_fit.Rd"]]
  }
  rd_text <- function(x) {
    if (is.character(x)) {
      return(paste(x, collapse = ""))
    }
    paste(vapply(x, rd_text, character(1)), collapse = "")
  }
  section <- NULL
  for (node in rd) {
    if (
      identical(attr(node, "Rd_tag"), "\\section") &&
        identical(trimws(rd_text(node[[1L]])), "Reproducibility")
    ) {
      section <- node[[2L]]
      break
    }
  }
  expect_false(is.null(section))
  if (is.null(section)) {
    return(invisible())
  }

  # The recipe is the section's one code block, so the domain the calls are
  # looked for in is shown non-empty and to be code rather than prose.
  blocks <- Filter(
    function(node) identical(attr(node, "Rd_tag"), "\\preformatted"),
    section
  )
  expect_length(blocks, 1L)
  recipe <- rd_text(blocks[[1L]])
  expect_true(grepl("set.seed(", recipe, fixed = TRUE))

  for (nm in names(tuner_registry)) {
    expect_true(
      grepl(paste0("\\b", nm, "\\("), recipe),
      label = paste0("recipe calls ", nm, "(")
    )
  }

  # The passing control: the prose around the block -- every node of the
  # section that is not the code block -- calls none of the tuners the
  # recipe branches on, so a match above is the recipe's and not a
  # section-wide one; and a name the registry does not hold is not found,
  # so the pattern can fail. `tune_grid` is left out of the control because
  # the section's closing paragraph cross-references `tune::tune_grid()`
  # as a call, on the repeated-call consequence it states.
  prose <- rd_text(Filter(
    function(node) !identical(attr(node, "Rd_tag"), "\\preformatted"),
    section
  ))
  expect_true(nchar(prose) > 0L)
  expect_true(grepl("\\btune_grid\\(", prose))
  for (nm in setdiff(names(tuner_registry), "tune_grid")) {
    expect_false(
      grepl(paste0("\\b", nm, "\\("), prose),
      label = paste0("prose calls ", nm, "(")
    )
  }
  expect_false(grepl("\\bfit_resamples\\(", recipe))
})
