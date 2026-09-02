# agreement(): how often each candidate was selected across the outer folds
# (M44, issue #36).
#
# Oracle provenance: the counts asserted below are read off the fixtures'
# `.selected` columns by hand -- `det_nested(d)` selects num_comp 3, 3, 3 and
# the unstable four-fold design selects 4, 4, 4, 3, both pinned in
# test-nested-results-print.R -- and the sum-of-`n` invariant (every completed
# fold is counted exactly once) is asserted on every fixture beside them. No
# statistic is computed here that an oracle would need to confirm.

# ---- the generic and its refusals (AC1) --------------------------------------

test_that("agreement() refuses objects that are not nested results, naming both", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # A tune_results is the object a user coming from tune is most likely to be
  # holding by mistake; a data frame and a list are the other two shapes the
  # results object could be confused with.
  set.seed(3)
  tuned <- tune::tune_grid(
    det_workflow(d),
    rsample::vfold_cv(d, v = 2),
    grid = det_grid(),
    metrics = reg_metrics()
  )
  expect_s3_class(tuned, "tune_results")

  for (obj in list(tuned, data.frame(a = 1), list(a = 1))) {
    cnd <- rlang::catch_cnd(agreement(obj), "nestedtune_no_agreement_method")
    expect_s3_class(cnd, "nestedtune_no_agreement_method")
    expect_match(conditionMessage(cnd), "has no method for", fixed = TRUE)
    expect_match(conditionMessage(cnd), "nested_results", fixed = TRUE)
    expect_no_match(conditionMessage(cnd), "applicable method")
    expect_identical(conditionCall(cnd)[[1L]], as.name("agreement"))
  }

  # The refusal describes the object in the same form the extract accessors
  # use, so the two families cannot drift apart.
  agreement_msg <- conditionMessage(rlang::catch_cnd(agreement(tuned)))
  extract_msg <- conditionMessage(rlang::catch_cnd(extract_tune_results(tuned)))
  expect_match(agreement_msg, "a <tune_results> object", fixed = TRUE)
  expect_match(extract_msg, "a <tune_results> object", fixed = TRUE)

  expect_error(agreement(res, foo = 1), class = "rlib_error_dots_nonempty")
})

# ---- the table (AC2) --------------------------------------------------------

test_that("a unanimous run is one row counting every completed fold", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
  expect_identical(
    vapply(res$.selected, function(s) s$num_comp, integer(1)),
    c(3L, 3L, 3L)
  )

  tab <- agreement(res)
  expect_s3_class(tab, "tbl_df")
  expect_named(tab, c("num_comp", "n", "prop"))
  expect_identical(nrow(tab), 1L)
  expect_identical(tab$num_comp, 3L)
  expect_identical(tab$n, 3L)
  expect_identical(tab$prop, 1)
  expect_identical(sum(tab$n), sum(res$.completed))
})

test_that("folds that disagree are counted per combination, most frequent first", {
  skip_if_no_engines()
  u <- unstable_data()

  set.seed(2)
  split <- memoised(nested_tune_grid(
    unstable_workflow(u),
    det_nested(u, v = 4),
    grid = unstable_grid(),
    metrics = reg_metrics()
  ))
  # The fixture's folds land on 4, 4, 4, 3 (test-nested-results-print.R pins
  # the same fact); the table below is that vector tallied.
  expect_identical(
    vapply(split$.selected, function(s) s$num_comp, integer(1)),
    c(4L, 4L, 4L, 3L)
  )

  tab <- agreement(split)
  expect_named(tab, c("num_comp", "n", "prop"))
  expect_identical(tab$num_comp, c(4L, 3L))
  expect_identical(tab$n, c(3L, 1L))
  expect_identical(tab$prop, c(0.75, 0.25))
  expect_identical(sum(tab$n), sum(split$.completed))
})

# ---- identity is the whole tuple, order follows the rows (AC3) --------------

test_that("two folds agree only when every selected parameter agrees", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # A second parameter the fixture does not tune, added to every selection so
  # folds 1 and 3 carry the same pair and fold 2 differs in the second
  # parameter only. Keyed per parameter, num_comp would read as unanimous.
  paired <- res
  mixture <- c(0.5, 0.1, 0.5)
  for (i in seq_len(nrow(paired))) {
    paired$.selected[[i]]$mixture <- mixture[[i]]
  }

  tab <- agreement(paired)
  expect_named(tab, c("num_comp", "mixture", "n", "prop"))
  expect_identical(tab$num_comp, c(3L, 3L))
  expect_identical(tab$mixture, c(0.5, 0.1))
  expect_identical(tab$n, c(2L, 1L))
  expect_identical(sum(tab$n), sum(paired$.completed))

  # Ties are broken by first appearance among the object's own rows, not the
  # design's fold labels: reordered, fold 2 comes first and leads the table.
  reordered <- paired[c(2L, 1L, 3L), ]
  reordered$.selected[[3L]]$mixture <- 0.9
  expect_s3_class(reordered, "nested_results")
  expect_identical(
    vapply(reordered$.selected, function(s) s$mixture, double(1)),
    c(0.1, 0.5, 0.9)
  )

  tab <- agreement(reordered)
  expect_identical(tab$mixture, c(0.1, 0.5, 0.9))
  expect_identical(tab$n, c(1L, 1L, 1L))
  expect_identical(tab$prop, c(1, 1, 1) / 3)
})

test_that("tune's .config label neither splits a row nor becomes a column", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # `.config` labels a candidate within one fold's own tuning run, and folds
  # can search different grids (M21), so two folds choosing the same values
  # under different labels still chose the same thing.
  relabelled <- res
  relabelled$.selected[[1L]]$.config <- "Preprocessor7_Model1"
  relabelled$.selected[[3L]]$.config <- "Preprocessor9_Model1"
  expect_length(
    unique(vapply(relabelled$.selected, function(s) s$.config, character(1))),
    3L
  )

  tab <- agreement(relabelled)
  expect_named(tab, c("num_comp", "n", "prop"))
  expect_identical(tab$n, 3L)
})

# ---- a fold with no value, and a fold that chose NA (AC4) -------------------

test_that("a fold that recorded no value is its own row, under NA", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # The shape summary() reports as "1 recorded no value": the fold completed,
  # so it is counted, but it chose nothing the others can agree with.
  partial_param <- res
  partial_param$.selected[[2L]] <-
    partial_param$.selected[[2L]][, ".config", drop = FALSE]

  tab <- agreement(partial_param)
  expect_named(tab, c("num_comp", "n", "prop"))
  expect_identical(tab$num_comp, c(3L, NA_integer_))
  expect_identical(tab$n, c(2L, 1L))
  expect_identical(sum(tab$n), sum(partial_param$.completed))
})

test_that("a fold that selected NA is counted as a value", {
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

  tab <- agreement(na_selected)
  expect_identical(tab$num_comp, c(3L, NA_integer_))
  expect_identical(tab$n, c(2L, 1L))
  expect_identical(sum(tab$n), sum(na_selected$.completed))
})

# ---- runs that fell short of their design (AC5) -----------------------------

test_that("a partial run is tabulated over the folds that completed, with a warning", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  expect_identical(res$.completed, c(TRUE, FALSE, TRUE))

  cnd <- rlang::catch_cnd(agreement(res), "nestedtune_partial_summary")
  expect_s3_class(cnd, "nestedtune_partial_summary")
  expect_match(
    conditionMessage(cnd),
    "This table covers 2 of 3 outer folds",
    fixed = TRUE
  )
  expect_identical(conditionCall(cnd)[[1L]], as.name("agreement"))

  tab <- suppressWarnings(agreement(res))
  expect_identical(sum(tab$n), 2L)
  expect_identical(tab$prop, tab$n / 2L)
})

test_that("a run where every fold failed is refused the way collect_metrics() refuses", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
  expect_false(any(res$.completed))

  ours <- rlang::catch_cnd(agreement(res), "error")
  theirs <- rlang::catch_cnd(collect_metrics(res), "error")
  expect_identical(class(ours), class(theirs))
  expect_match(conditionMessage(ours), "nothing to tabulate", fixed = TRUE)
  expect_match(conditionMessage(ours), "no outer fold completed", fixed = TRUE)
  expect_match(
    conditionMessage(theirs),
    "no outer fold completed",
    fixed = TRUE
  )
})

test_that("a run with nothing tuned is a table with no rows and no warning", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))

  # Every completed fold's selection carries tune's label and nothing else,
  # which is what select_best() hands back for a workflow with no tune() marks.
  untuned <- res
  for (i in seq_len(nrow(untuned))) {
    untuned$.selected[[i]] <- untuned$.selected[[i]][, ".config", drop = FALSE]
  }

  expect_no_condition(agreement(untuned), class = "nestedtune_partial_summary")
  tab <- agreement(untuned)
  expect_s3_class(tab, "tbl_df")
  expect_named(tab, c("n", "prop"))
  expect_identical(nrow(tab), 0L)
})
