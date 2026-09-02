# Printing a nested_results object, and summarizing one (M04, split in M39).
#
# The two methods answer different questions and the blocks below are grouped by
# which one they hold to account. print() describes the OBJECT -- the rows, the
# scheme, how much did not run, a pointer onward. summary() says what the run
# MEANS -- the design, the failures and their stages, the selections, the
# estimate. A fact asserted against the wrong one of those would pass today and
# stop meaning anything the moment either method moved.
#
# The snapshots at the bottom pin the shapes that carry meaning. The assertions
# above them pin the facts a snapshot alone would let drift silently: an
# approved snapshot records whatever the code printed, not what it owed, so a
# criterion that must hold is asserted in words as well as recorded in shape.

# The summary's rendered text, for the assertions below. Wrapped because a
# partial run warns by design (AC3) and the warning is asserted where it is the
# subject, not in every block that reads the text.
summary_text <- function(x, width = 200) {
  print_text(suppressWarnings(summary(x)), width = width)
}

# ---- print(): the object ----------------------------------------------------

test_that("printing names the outer scheme and shows the object's own rows", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- print_text(res)

  expect_match(txt, "3-fold cross-validation")

  # The rows themselves, rendered by the tibble underneath: the header line
  # tibble writes, and the fold labels and record columns it puts in the table.
  # This is the whole point of the split -- a user meeting the object is shown
  # what it is rather than only what it concluded.
  expect_match(txt, "A tibble: 3")
  expect_match(txt, "Fold1")
  expect_match(txt, ".completed")

  # And the pointer onward, which is what makes the missing sections findable
  # rather than merely absent.
  expect_match(txt, "summary()", fixed = TRUE)

  # The reading of the run is summary()'s, and printing does not repeat it.
  expect_no_match(txt, "3 requested")
  expect_no_match(txt, "Selected parameters")
  expect_no_match(txt, "Estimate")
})

test_that("an outer scheme the object does not name is left unprinted", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- print_text(as_fold_subset(res, 1:2))

  # Since M36 `[` sheds the class outright on a row subset, so this object is
  # built by the helper rather than by `[` and the test no longer exercises
  # subsetting -- the title says so. What it does assert is unchanged and still
  # worth asserting: a results object carrying no scheme label prints without
  # one rather than reaching for the design it came from (IP4).
  expect_no_match(txt, "3-fold cross-validation")
  expect_no_match(txt, "Outer resamples")
  expect_match(txt, "A tibble: 2")
})

test_that("printing counts the folds that did not complete, and only then", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  txt <- print_text(partial)

  expect_match(txt, "1 of 3 outer folds did not complete", fixed = TRUE)

  # The count only. Which fold failed, and at what stage, is what the run means
  # and is summary()'s to say -- asserted here so the two cannot silently merge
  # back together.
  expect_no_match(txt, "failed during")
  expect_no_match(txt, "what went wrong")

  # The passing control: a whole run says nothing at all rather than "0 of 3",
  # so the line's presence is itself the signal.
  set.seed(2)
  complete <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  expect_no_match(print_text(complete), "did not complete")
})

test_that("printing a partial run neither warns nor errors", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # collect_metrics() and summary() warn here by design; printing is not a
  # summary request, so it reports the same partiality as a count instead.
  expect_warning(collect_metrics(res), class = "nestedtune_partial_summary")
  expect_no_warning(print_text(res))
  expect_match(print_text(res), "1 of 3 outer folds did not complete")
})

test_that("printing a run where nothing completed neither warns nor errors", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # collect_metrics() refuses outright; printing still has to describe the run.
  expect_error(collect_metrics(res))
  expect_no_error(print_text(res))
  expect_no_warning(print_text(res))

  txt <- print_text(res)
  expect_match(txt, "3 of 3 outer folds did not complete", fixed = TRUE)
  expect_match(txt, "A tibble: 3")
})

test_that("print returns its input invisibly and is registered for S3 dispatch", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  cli::cli_fmt(returned <- withVisible(print(res)))
  expect_false(returned$visible)
  expect_identical(returned$value, res)

  expect_false(
    is.null(utils::getS3method("print", "nested_results", optional = TRUE))
  )

  # The rows are shown by stripping this class and letting the tibble
  # underneath render them, which must not leave the caller's object stripped.
  expect_s3_class(res, "nested_results")
})

# The rendered text of `print(x, ...)`, at a console width of the test's
# choosing. Distinct from print_text() because the tibble `width` argument and
# the console width are two different things and the M43 tests need both.
print_text_at <- function(x, console, ...) {
  op <- options(width = console, cli.width = console)
  on.exit(options(op), add = TRUE)
  paste(cli::cli_fmt(print(x, ...)), collapse = "\n")
}

# The tibble body's row lines: a row number, then the first cell.
count_row_lines <- function(txt) {
  sum(grepl("^\\s*[0-9]+ <split", strsplit(txt, "\n")[[1L]]))
}

# How many columns the `# i <k> more variables` footer lists, or 0 without one.
footer_variables <- function(txt) {
  m <- regmatches(txt, regexpr("# i [0-9]+ more variable", txt))
  if (length(m) == 0L) {
    return(0L)
  }
  as.integer(regmatches(m, regexpr("[0-9]+", m)))
}

test_that("print() takes `n` and hands it to the row rendering", {
  skip_if_no_engines()

  # More folds than tibble shows by default: a 3-fold design repeated seven
  # times, through the constructor over stand-in records. Stacking the
  # three-fold fixture with rbind() cannot reach this shape -- the stamp rule
  # refuses a row count that differs from the run's, and hands back a bare
  # tibble (M36).
  wide <- repeated_results(v = 3, repeats = 7)
  expect_s3_class(wide, "nested_results")
  expect_identical(nrow(wide), 21L)

  txt <- print_text(wide)
  expect_identical(count_row_lines(txt), 10L)
  expect_match(txt, "# i 11 more rows", fixed = TRUE)

  txt_all <- print_text_at(wide, 200, n = Inf)
  expect_identical(count_row_lines(txt_all), 21L)
  expect_no_match(txt_all, "more row")

  # And on the three-fold fixture, `n` below the row count truncates.
  d <- make_reg_data()
  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt_two <- print_text_at(res, 200, n = 2)
  expect_identical(count_row_lines(txt_two), 2L)
  expect_match(txt_two, "# i 1 more row", fixed = TRUE)
})

test_that("print() takes `width` and hands it to the row rendering", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Both rendered at a console width of 80, so the only difference between the
  # two is the argument: the narrower rendering pushes more columns into the
  # footer that lists what did not fit.
  default_txt <- print_text_at(res, 80)
  narrow_txt <- print_text_at(res, 80, width = 40)
  expect_gt(footer_variables(default_txt), 0L)
  expect_gt(footer_variables(narrow_txt), footer_variables(default_txt))
})

test_that("print() still fences `...`, so a partial spelling is refused", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Written as the real calls a user would make -- `print(res, ...)` through
  # dispatch -- rather than by calling the method directly (M42 lesson). The
  # third is the case the fence exists for: `w` is a prefix of `width`, and
  # because `width` sits after `...` it does not partially match and lands in
  # the dots instead of being taken as `width`.
  probes <- list(
    quote(print(res, foo = 1)),
    quote(print(res, n = 2, foo = 1)),
    quote(print(res, w = 40))
  )
  for (probe in probes) {
    cnd <- rlang::catch_cnd(eval(probe))
    expect_s3_class(cnd, "rlib_error_dots_nonempty")
    expect_identical(rlang::call_name(conditionCall(cnd)), "print")
  }

  # The passing control: the full spellings are accepted by the same path.
  expect_no_error(print_text_at(res, 200, n = 2, width = 40))
})

test_that("a subset missing the per-fold record prints as a plain tibble", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Keeping .completed alone once kept the class, and print() then read
  # columns that were gone: two "unknown or uninitialised column" warnings
  # and an "invalid 'times' argument" error, on a method that promises neither.
  thin <- res[, c("id", ".completed")]
  expect_false(inherits(thin, "nested_results"))
  expect_no_error(utils::capture.output(print(thin)))
  expect_no_warning(utils::capture.output(print(thin)))
})

# ---- summary(): what the run means ------------------------------------------

test_that("summary() returns a classed object carrying the run's numbers", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  s <- summary(res)

  expect_s3_class(s, "summary.nested_results")
  expect_identical(s$requested, 3L)
  expect_identical(s$completed, 3L)
  expect_identical(s$failures$id, character(0))
  expect_named(s$selection, "num_comp")
  expect_length(s$selection$num_comp, 3L)
  expect_identical(
    s$estimate,
    summarize_folds(collect_metrics(res, summarize = FALSE))
  )
})

test_that("summarizing reports the outer design and how much of it ran", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- summary_text(res)

  expect_match(txt, "3-fold cross-validation")
  expect_match(txt, "3 requested")
  expect_match(txt, "3 completed")
})

test_that("a failed fold is named along with the stage it failed at", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  txt <- summary_text(res)

  expect_match(txt, "Fold2")
  expect_match(txt, "outer fit")
  expect_match(txt, "3 requested")
  expect_match(txt, "2 completed")

  set.seed(2)
  inner <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 1L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  expect_match(summary_text(inner), "inner tuning")
})

test_that("unanimous selection is distinguished from disagreement", {
  skip_if_no_engines()

  d <- make_reg_data()
  set.seed(2)
  agreed <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  agreed_txt <- summary_text(agreed)

  expect_match(agreed_txt, "num_comp")
  expect_match(agreed_txt, "agree")
  expect_no_match(agreed_txt, "disagree")

  u <- unstable_data()
  set.seed(2)
  split <- memoised(nested_tune_grid(
    unstable_workflow(u),
    det_nested(u, v = 4),
    grid = unstable_grid(),
    metrics = reg_metrics()
  ))
  split_txt <- summary_text(split)

  # The fixture's folds land on 4, 4, 4, 3 -- every fold's value is shown, in
  # fold order, so the run that produced the disagreement stays readable.
  expect_identical(
    vapply(split$.selected, function(s) s$num_comp, integer(1)),
    c(4L, 4L, 4L, 3L)
  )
  expect_match(split_txt, "4, 4, 4, 3")
  expect_match(split_txt, "disagree")
})

test_that("summarizing says the estimate describes the procedure, not a model", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  txt <- summary_text(res)

  expect_match(txt, "procedure")
  expect_match(txt, "not a model you can deploy")
})

test_that("summarizing shows the estimate over the folds that contributed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  summarized <- collect_metrics(res)
  txt <- summary_text(res)

  expect_match(txt, "rmse")
  expect_match(txt, "rsq")
  expect_match(txt, format(summarized$mean[[1L]], digits = 3), fixed = TRUE)
  expect_match(txt, "3 of 3 outer folds")
})

test_that("printing the summary carries every section print() used to emit", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  txt <- summary_text(res)

  # The design block, the failure block, the selection block, the estimate
  # block, and the sentence that says what the estimate is a property of.
  expect_match(txt, "3-fold cross-validation")
  expect_match(txt, "3 requested, 2 completed")
  expect_match(txt, "failed during outer fit")
  expect_match(txt, "See the `.notes` column", fixed = TRUE)
  expect_match(txt, "Selected parameters")
  expect_match(txt, "num_comp")
  expect_match(txt, "2 of 3 outer folds")
  expect_match(txt, "rmse")
  expect_match(txt, "describes the tune-and-fit procedure")

  # The one section that did NOT come across: the candidate-set line stays in
  # print(), where it qualifies the object, and is not repeated here.
  expect_no_match(txt, "Candidates searched")
})

test_that("the failure advice names the results object's `.notes` column, never `x$`", {
  skip_if_no_engines()
  d <- make_reg_data()

  # `x` inside the summary's print method is the summary bundle, which has no
  # `.notes`; before M43 the advice read `x$.notes` and named nothing a reader
  # could evaluate. Asserted on both failed fixtures -- one fold down and every
  # fold down -- since the block is reached by each and the line closes both.
  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  set.seed(2)
  nothing <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  for (res in list(partial, nothing)) {
    lines <- strsplit(summary_text(res), "\n")[[1L]]
    advice <- grep("what went wrong", lines, value = TRUE)
    # One advice line, and it is the line that ends the failure block: the
    # previous line is a failure line, the next opens the next section.
    expect_length(advice, 1L)
    expect_match(advice, "`.notes` column of the results object", fixed = TRUE)
    expect_no_match(advice, "x$", fixed = TRUE)
    at <- match(advice, lines)
    expect_match(lines[[at - 1L]], "failed during")
    expect_no_match(lines[[at + 1L]], "failed during")
  }
})

test_that("summary() warns on a partial run and still returns its object", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  expect_warning(s <- summary(res), class = "nestedtune_partial_summary")
  expect_s3_class(s, "summary.nested_results")
  expect_identical(s$completed, 2L)
})

test_that("summary() of a run where every fold failed reports it rather than aborting", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # collect_metrics() aborts here; summary() is a description of a failed run,
  # which is exactly what there is to describe.
  expect_error(collect_metrics(res), class = "rlang_error")
  expect_warning(s <- summary(res), class = "nestedtune_partial_summary")
  expect_identical(s$completed, 0L)
  expect_null(s$estimate)

  txt <- print_text(s)
  expect_match(txt, "0 completed")
  expect_match(txt, "nothing was selected")
  expect_match(txt, "no estimate")
})

test_that("summary() of a run where every fold completed signals nothing", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  expect_no_warning(s <- summary(res))
  expect_no_condition(print_text(s))
})

test_that("summary() and its print method reject arguments they do not take", {
  skip_if_no_engines()
  res <- repeated_results()

  expect_error(summary(res, foo = 1), class = "rlib_error_dots_nonempty")
  expect_error(
    print(summary(res), foo = 1),
    class = "rlib_error_dots_nonempty"
  )
})

test_that("a single completed fold reads in the singular", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  expect_match(
    summary_text(as_fold_subset(res, 1L)),
    "Estimate (1 of 1 outer fold)",
    fixed = TRUE
  )
})

test_that("a parameter only some folds chose is not reported as disagreement", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # One fold carries no value for num_comp. The folds that did choose agree,
  # so flagging instability here would be a false alarm about the very thing
  # this method exists to surface.
  partial_param <- res
  partial_param$.selected[[2L]] <-
    partial_param$.selected[[2L]][, ".config", drop = FALSE]
  txt <- summary_text(partial_param)

  expect_no_match(txt, "disagree")
  expect_match(txt, "all 2 folds that chose it agree", fixed = TRUE)
  expect_match(txt, "1 recorded no value", fixed = TRUE)
})

test_that("a fold that selected NA is a value, not an absent one", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  na_selected <- res
  na_selected$.selected[[1L]]$num_comp <- NA_integer_
  txt <- summary_text(na_selected)

  # NA is a choice this fold made and "--" means the fold had no column at
  # all; rendering both the same way would make each unreadable as the other.
  expect_match(txt, "num_comp: NA, 3, 3 (folds disagree)", fixed = TRUE)
})

test_that("a list-valued selection prints instead of aborting", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Not something select_best() produces, but the method promises never to
  # raise and vapply() would abort on a length-2 result before printing at all.
  listy <- res
  listy$.selected[[1L]]$num_comp <- list(1:2)

  expect_no_error(summary_text(listy))
  expect_match(summary_text(listy), "1, 2", fixed = TRUE)
})

# ---- the fold-label record, when it cannot label the rows (AC4) -------------

test_that("an unusable label record names failed folds by row position", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # The three forms the record takes when it cannot label the rows. Before M39
  # the first two made an indexing caller raise and the third pasted what
  # survived into the truncated label "Fold1, " -- wrong, and silently so.
  forms <- list(
    empty = character(0),
    absent = "not_a_column",
    partly_absent = c("id", "not_a_column")
  )

  for (nm in names(forms)) {
    broken <- res
    attr(broken, "id_columns") <- forms[[nm]]

    expect_no_error(print_text(broken))
    expect_no_warning(print_text(broken))

    txt <- summary_text(broken)
    expect_match(txt, "row 2 failed during outer fit", fixed = TRUE, info = nm)
    expect_no_match(txt, "Fold1, ", fixed = TRUE, info = nm)
  }

  # The passing control: with the record the constructor wrote, the fold is
  # named from its label column and not by position -- so the fallback above is
  # reached by the record being unusable and not by every object taking it.
  expect_match(summary_text(res), "Fold2 failed during outer fit", fixed = TRUE)
  expect_no_match(summary_text(res), "row 2")
})

# ---- the candidate-set line, which stays in print() (AC1) -------------------

test_that("folds that searched different candidate sets are said to have", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  # A continuous parameter with a grid SIZE: tune expands it per fold, under
  # each fold's own seed, and the expansions differ (measured in
  # test-nested-tune-grid-oracles.R). The disagreement is checked here rather
  # than assumed, so a fixture that quietly stopped disagreeing could not go on
  # recording a valid-looking snapshot of a line it no longer earns.
  set.seed(20)
  differing <- nested_tune_grid(
    cont_workflow(d),
    folds,
    grid = 5,
    metrics = reg_metrics()
  )
  expect_false(same_candidates(differing$.grid))

  # The branch this line lives on is reached by no other fixture in the file,
  # so the method's "never raises, never warns" promise is re-asserted here
  # rather than assumed from the partial-run and nothing-completed tests above.
  expect_no_error(print_text(differing))
  expect_no_warning(print_text(differing))

  txt <- print_text(differing)
  expect_match(txt, "Candidates searched: 5, 5, 5")
  expect_match(txt, "did not search the\\s+same grid")

  # A data-frame grid is handed to every fold unchanged, so there is nothing to
  # disagree about and the line stays away. Asserted because a line that fires
  # unconditionally would look identical in the snapshot above.
  set.seed(20)
  agreeing <- nested_tune_grid(
    det_workflow(d),
    folds,
    grid = det_grid(),
    metrics = reg_metrics()
  )
  expect_true(same_candidates(agreeing$.grid))
  expect_no_match(print_text(agreeing), "Candidates searched")
})

test_that("the candidate-set comparison ignores order and tune's config labels", {
  # `.config` is positional, so two folds that searched the same candidates in a
  # different order carry different labels for them -- comparing on the label
  # would report every such pair as a disagreement.
  a <- data.frame(cost = c(1, 2, 3), .config = c("pre1", "pre2", "pre3"))
  b <- data.frame(cost = c(3, 1, 2), .config = c("pre9", "pre8", "pre7"))
  expect_true(same_candidates(list(a, b)))

  # And a difference below print precision is still a difference: the comparison
  # runs on the values, not on what they format to.
  c1 <- data.frame(
    cost = c(1, 2, 3 + 1e-12),
    .config = c("pre1", "pre2", "pre3")
  )
  expect_false(same_candidates(list(a, c1)))

  # A fold carrying a different parameter entirely is a difference too, rather
  # than a coincidence of values.
  d1 <- data.frame(penalty = c(1, 2, 3), .config = c("pre1", "pre2", "pre3"))
  expect_false(same_candidates(list(a, d1)))
})

test_that("printing survives a list-valued parameter column (M21 review F1)", {
  # Regression. `candidate_key()` normalised row order with
  # `do.call(order, values)`, and order() RAISES on a list column
  # ("unimplemented type 'list' in 'orderVector1'") -- so a `.grid` carrying one
  # aborted a method whose header promises it never raises. The shape is
  # producible: test-nested-tune-grid-failures.R asserts scored_candidates()
  # returns exactly such a record.
  #
  # Asserted on same_candidates() rather than only through print(), because the
  # raise is in the comparison and a print-only test would pass the day the
  # call moved.
  listy <- data.frame(.config = c("pre1", "pre2"))
  listy$cost <- list(1:2, 3:4)

  expect_no_error(same_candidates(list(listy, listy)))
  expect_true(same_candidates(list(listy, listy)))

  # Two folds whose list-valued candidates genuinely differ are a difference,
  # not an error and not a false agreement.
  other <- data.frame(.config = c("pre1", "pre2"))
  other$cost <- list(1:2, 5:6)
  expect_no_error(same_candidates(list(listy, other)))
  expect_false(same_candidates(list(listy, other)))

  # Row order still normalises away for a list column, as it does for an atomic
  # one -- the rendering that replaced order() must not lose that.
  reordered <- data.frame(.config = c("pre9", "pre8"))
  reordered$cost <- list(3:4, 1:2)
  expect_true(same_candidates(list(listy, reordered)))
})

# ---- shape ------------------------------------------------------------------

# The tibble body is a dependency's rendering and not this package's to pin:
# its column-type row, cell text and `# i <k> more variables` footer have all
# changed wording across pillar releases. The four print snapshots keep the
# `# A tibble: <n> x <k>` header and every cli line, and stand one marker in
# for the body -- everything between the header and the first cli bullet
# (M43). The rows themselves are asserted in words above (n, width, Fold1).
scrub_tibble_body <- function(lines) {
  header <- grep("^\\s*# A tibble: ", lines)
  if (length(header) != 1L) {
    return(lines)
  }
  # testthat hands the transform each cli message on its own, and the tibble
  # block is one message, so usually nothing follows the body here; the bullet
  # search is kept so the scrub is right about a block that does carry one.
  after <- seq.int(header + 1L, length.out = length(lines) - header)
  bullets <- after[grepl("^\\s*[xiv!] ", lines[after])]
  keep <- if (length(bullets) == 0L) integer(0) else bullets[[1L]]:length(lines)
  c(
    lines[seq_len(header)],
    "<tibble body: column types, rows and the more-variables footer>",
    lines[keep]
  )
}

test_that("the tibble-body scrub keeps the header and every cli line", {
  # Discrimination for the transform: what it removes and what it keeps,
  # asserted on a shape written here, so a scrub that swallowed a cli line or
  # left a cell row behind could not go on recording a valid-looking snapshot.
  lines <- c(
    "-- Nested cross-validation results ----",
    "Outer resamples: 3-fold cross-validation",
    "# A tibble: 3 x 9",
    "  splits id",
    "  <list> <chr>",
    "1 <split [60/30]> Fold1",
    "# i 2 more variables: .tuning_seed <int>",
    "x 1 of 3 outer folds did not complete.",
    "i Use `summary()` for what the run means."
  )
  expect_identical(
    scrub_tibble_body(lines),
    c(
      lines[1:3],
      "<tibble body: column types, rows and the more-variables footer>",
      lines[8:9]
    )
  )
  # The shape the transform meets in practice: the tibble message alone.
  expect_identical(
    scrub_tibble_body(lines[3:7]),
    c(
      lines[[3L]],
      "<tibble body: column types, rows and the more-variables footer>"
    )
  )
  # A summary's output carries no tibble and passes through untouched.
  expect_identical(scrub_tibble_body(lines[-(3:7)]), lines[-(3:7)])
})

test_that("printed output holds its shape", {
  skip_if_no_engines()
  d <- make_reg_data()
  u <- unstable_data()

  set.seed(2)
  complete <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  # Unanimity has to be checked, not assumed: the same design on the smaller
  # frame splits 3, 3, 2, 3, 3, so a fixture labelled unanimous that quietly
  # stopped being unanimous would still record a perfectly valid snapshot.
  big <- make_reg_data(n = 150)
  set.seed(2)
  unanimous <- memoised(nested_tune_grid(
    det_workflow(big),
    det_nested(big, v = 5),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  expect_identical(
    vapply(unanimous$.selected, function(s) s$num_comp, integer(1)),
    rep(3L, 5L)
  )
  set.seed(2)
  divergent <- memoised(nested_tune_grid(
    unstable_workflow(u),
    det_nested(u, v = 4),
    grid = unstable_grid(),
    metrics = reg_metrics()
  ))
  set.seed(2)
  nothing <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))

  # The candidate-set line's own shape, snapshot beside the rest (M21). Built
  # from a grid SIZE rather than a frame, which is the only way folds come to
  # search different candidates.
  set.seed(11)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(20)
  differing <- nested_tune_grid(
    cont_workflow(d),
    folds,
    grid = 5,
    metrics = reg_metrics()
  )

  expect_snapshot(print(complete), transform = scrub_tibble_body)
  expect_snapshot(print(partial), transform = scrub_tibble_body)
  expect_snapshot(print(nothing), transform = scrub_tibble_body)
  expect_snapshot(print(differing), transform = scrub_tibble_body)

  expect_snapshot(print(summary(complete)))
  expect_snapshot(print(summary(unanimous)))
  expect_snapshot(print(summary(divergent)))
  expect_snapshot(print(suppressWarnings(summary(partial))))
  expect_snapshot(print(suppressWarnings(summary(nothing))))
})
