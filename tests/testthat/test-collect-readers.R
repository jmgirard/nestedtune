# The three readers that stack a per-fold list column with the fold labels
# beside it (M65, D-052): collect_notes(), collect_selections() and
# collect_inner_metrics().
#
# Oracle provenance: every stacked table is compared against the same column
# stacked by hand -- dplyr::bind_rows() or vctrs::vec_rbind() over the list
# column with the fold's label prepended -- so no figure here is the reader's
# own. The selections the fixtures make (num_comp 3, 3, 3 on det_nested()) are
# the ones test-nested-results-print.R and test-nested-results-agreement.R pin.

# A results object over hand-written fold records, for the shapes no fitted
# fixture reaches: folds whose selections or inner tables carry different
# columns, and a repeated design's two label columns. Built through the
# constructor, so the record is the code's and not the fixture's (M38).
stub_results <- function(design, folds) {
  n <- nrow(design)
  stopifnot(length(folds) == n)
  new_nested_results(
    design,
    folds,
    seq_len(2L * n),
    det_grid(),
    reg_metrics(),
    procedure = new_procedure(
      tuner_grid(det_grid()),
      param_info = NULL,
      event_level = "first",
      eval_time = NULL,
      control = effective_control("tune_grid", NULL, "first")
    )
  )
}

stub_fold <- function(
  selected = data.frame(num_comp = 1L),
  inner_metrics = data.frame(num_comp = 1L, mean = 0.5),
  notes = empty_notes(),
  completed = TRUE
) {
  list(
    completed = completed,
    metrics = data.frame(
      .metric = c("rmse", "rsq"),
      .estimator = "standard",
      .estimate = c(1, 0.5)
    ),
    selected = selected,
    inner_metrics = inner_metrics,
    grid = det_grid(),
    notes = notes
  )
}

# The stack made by hand: each fold's table with that fold's label columns
# put first, then bound. Written against the object's columns and never
# against the reader, so a reader that mislabels a row disagrees with it.
hand_stacked <- function(x, column, which = seq_len(nrow(x))) {
  id_cols <- attr(x, "id_columns")
  rows <- lapply(which, function(i) {
    tbl <- x[[column]][[i]]
    labels <- lapply(id_cols, function(nm) rep(x[[nm]][[i]], nrow(tbl)))
    names(labels) <- id_cols
    vctrs::vec_cbind(vctrs::new_data_frame(labels), tbl)
  })
  # A tibble, which the readers promise; the stubs' plain data frames would
  # otherwise stack to a bare one and differ in class alone.
  new_tbl(as.list(vctrs::vec_rbind(!!!rows)))
}

clean_run <- function(d) {
  set.seed(2)
  memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
}

failed_run <- function(d) {
  set.seed(2)
  suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_fold(det_nested(d), 2L, "inner tuning"),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
}

all_failed_run <- function(d) {
  set.seed(2)
  suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    break_every_fold(det_nested(d)),
    grid = det_grid(),
    metrics = reg_metrics()
  )))
}

# How many times a condition of `class` is signalled by `expr`, the
# condition muffled so it never reaches testthat as a stray.
times_warned <- function(expr, class) {
  n <- 0L
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (inherits(w, class)) {
        n <<- n + 1L
      }
      invokeRestart("muffleWarning")
    }
  )
  n
}

# ---- collect_notes() (AC1) --------------------------------------------------

test_that("collect_notes() stacks every fold's notes under its label", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- failed_run(d)
  expect_identical(res$.completed, c(TRUE, FALSE, TRUE))
  expect_true(nrow(res$.notes[[2L]]) > 1L)

  notes <- collect_notes(res)
  expect_s3_class(notes, "tbl_df")
  expect_named(notes, c("id", "location", "type", "note", "trace"))
  expect_identical(nrow(notes), sum(vapply(res$.notes, nrow, integer(1))))
  # The failed fold's rows carry that fold's label and no other's; the
  # completed folds recorded nothing and so contribute nothing.
  expect_identical(unique(notes$id), res$id[[2L]])

  by_hand <- dplyr::bind_rows(lapply(seq_len(nrow(res)), function(i) {
    dplyr::mutate(res$.notes[[i]], id = res$id[[i]], .before = 1L)
  }))
  expect_equal(notes, by_hand, ignore_attr = FALSE)
})

test_that("collect_notes() on a run with no note is zero rows with the same columns", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- clean_run(d)
  expect_identical(vapply(res$.notes, nrow, integer(1)), c(0L, 0L, 0L))

  notes <- collect_notes(res)
  expect_named(notes, c("id", "location", "type", "note", "trace"))
  expect_identical(nrow(notes), 0L)
  expect_type(notes$id, "character")
  expect_type(notes$trace, "list")

  by_hand <- dplyr::bind_rows(lapply(seq_len(nrow(res)), function(i) {
    dplyr::mutate(res$.notes[[i]], id = res$id[[i]], .before = 1L)
  }))
  expect_equal(notes, by_hand)
})

test_that("collect_notes() reads every fold, warning about none", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- failed_run(d)
  expect_no_warning(collect_notes(res))
  expect_error(collect_notes(res, foo = 1), class = "rlib_error_dots_nonempty")
})

# ---- collect_selections() (AC2) ----------------------------------------------

test_that("collect_selections() is one labelled row per completed fold", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- clean_run(d)

  sel <- collect_selections(res)
  expect_s3_class(sel, "tbl_df")
  expect_named(sel, c("id", names(res$.selected[[1L]])))
  expect_identical(nrow(sel), 3L)
  expect_identical(sel$id, res$id)
  expect_identical(sel$num_comp, c(3L, 3L, 3L))
  expect_equal(sel, hand_stacked(res, ".selected"))
})

test_that("collect_selections() warns once on a partial run and stacks the completed folds", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- failed_run(d)

  expect_warning(
    sel <- collect_selections(res),
    class = "nestedtune_partial_summary"
  )
  expect_identical(
    times_warned(collect_selections(res), "nestedtune_partial_summary"),
    1L
  )
  expect_identical(sel$id, res$id[res$.completed])
  expect_identical(nrow(sel), 2L)
  expect_equal(sel, hand_stacked(res, ".selected", which(res$.completed)))

  cnd <- rlang::catch_cnd(collect_selections(res), "nestedtune_partial_summary")
  expect_match(conditionMessage(cnd), "This table covers 2 of 3", fixed = TRUE)
  expect_match(conditionMessage(cnd), res$id[[2L]], fixed = TRUE)
})

test_that("collect_selections() refuses a run in which no fold completed, as collect_metrics() does", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- all_failed_run(d)
  expect_false(any(res$.completed))

  ours <- rlang::catch_cnd(collect_selections(res), "error")
  theirs <- rlang::catch_cnd(collect_metrics(res), "error")
  expect_s3_class(ours, "nestedtune_no_completed_folds")
  expect_identical(class(ours), class(theirs))
  expect_match(conditionMessage(ours), "nothing to collect", fixed = TRUE)
  expect_match(conditionMessage(ours), "no outer fold completed", fixed = TRUE)
})

test_that("collect_selections() stacks over the union of columns, NA where a fold lacks one", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- stub_results(
    det_nested(d),
    list(
      stub_fold(selected = data.frame(num_comp = 2L, .config = "a")),
      stub_fold(selected = data.frame(threshold = 0.5, .config = "b")),
      stub_fold(selected = data.frame(num_comp = 3L, .config = "c"))
    )
  )

  sel <- collect_selections(res)
  expect_named(sel, c("id", "num_comp", ".config", "threshold"))
  expect_identical(sel$num_comp, c(2L, NA, 3L))
  expect_identical(sel$threshold, c(NA, 0.5, NA))
  expect_identical(sel$.config, c("a", "b", "c"))
  expect_equal(sel, hand_stacked(res, ".selected"))
})

# ---- collect_inner_metrics() (AC3) -------------------------------------------

test_that("collect_inner_metrics() stacks each completed fold's inner table under its label", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- clean_run(d)

  inner <- collect_inner_metrics(res)
  expect_s3_class(inner, "tbl_df")
  expect_named(inner, c("id", names(res$.inner_metrics[[1L]])))
  expect_identical(
    nrow(inner),
    sum(vapply(res$.inner_metrics, nrow, integer(1)))
  )
  expect_identical(
    inner$id,
    rep(res$id, times = vapply(res$.inner_metrics, nrow, integer(1)))
  )
  expect_equal(inner, hand_stacked(res, ".inner_metrics"))
  expect_error(
    collect_inner_metrics(res, foo = 1),
    class = "rlib_error_dots_nonempty"
  )
})

test_that("collect_inner_metrics() keeps a fold's own .config beside its rows", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- clean_run(d)

  inner <- collect_inner_metrics(res)
  expect_true(".config" %in% names(inner))
  # Each fold's `.config` labels a row in that fold's own inner table: the
  # selected candidate's label is found among that same fold's rows.
  sel <- collect_selections(res)
  for (i in seq_len(nrow(sel))) {
    expect_true(sel$.config[[i]] %in% inner$.config[inner$id == sel$id[[i]]])
  }
})

test_that("collect_inner_metrics() warns once on a partial run and refuses an all-failed one", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- failed_run(d)

  expect_warning(
    inner <- collect_inner_metrics(res),
    class = "nestedtune_partial_summary"
  )
  expect_identical(
    times_warned(collect_inner_metrics(res), "nestedtune_partial_summary"),
    1L
  )
  expect_setequal(unique(inner$id), res$id[res$.completed])
  expect_equal(
    inner,
    hand_stacked(res, ".inner_metrics", which(res$.completed))
  )

  none <- all_failed_run(d)
  ours <- rlang::catch_cnd(collect_inner_metrics(none), "error")
  theirs <- rlang::catch_cnd(collect_metrics(none), "error")
  expect_s3_class(ours, "nestedtune_no_completed_folds")
  expect_identical(class(ours), class(theirs))
  expect_match(conditionMessage(ours), "nothing to collect", fixed = TRUE)
})

test_that("collect_inner_metrics() stacks over the union of columns, NA where a fold lacks one", {
  skip_if_no_engines()
  d <- make_reg_data()
  res <- stub_results(
    det_nested(d),
    list(
      stub_fold(inner_metrics = data.frame(num_comp = 1:2, mean = c(1, 2))),
      stub_fold(
        inner_metrics = data.frame(num_comp = 1L, mean = 3, .iter = 0L)
      ),
      stub_fold(inner_metrics = data.frame(num_comp = 2L, mean = 4))
    )
  )

  inner <- collect_inner_metrics(res)
  expect_named(inner, c("id", "num_comp", "mean", ".iter"))
  expect_identical(nrow(inner), 4L)
  expect_identical(inner$id, rep(res$id, times = c(2L, 1L, 1L)))
  expect_identical(inner$.iter, c(NA, NA, 0L, NA))
  expect_equal(inner, hand_stacked(res, ".inner_metrics"))
})

# ---- the label columns come from the record (AC4) ---------------------------

test_that("every reader carries the recorded label columns, id and id2 on a repeated design", {
  skip_if_no_engines()
  note <- new_tbl(list(
    location = "inner tuning",
    type = "warning",
    note = "a note",
    trace = list(NULL)
  ))
  fold <- function() stub_fold(notes = note)

  repeated <- repeated_design(v = 2, repeats = 2)
  expect_identical(attr(repeated, "id_columns"), NULL)
  res <- stub_results(repeated, replicate(4L, fold(), simplify = FALSE))
  expect_identical(attr(res, "id_columns"), c("id", "id2"))

  for (reader in list(
    collect_notes,
    collect_selections,
    collect_inner_metrics
  )) {
    out <- reader(res)
    expect_identical(names(out)[1:2], c("id", "id2"))
    expect_identical(out$id, res$id)
    expect_identical(out$id2, res$id2)
  }
  expect_equal(collect_notes(res), hand_stacked(res, ".notes"))
  expect_equal(collect_selections(res), hand_stacked(res, ".selected"))
  expect_equal(
    collect_inner_metrics(res),
    hand_stacked(res, ".inner_metrics")
  )

  single <- stub_results(
    det_nested(make_reg_data()),
    replicate(3L, fold(), simplify = FALSE)
  )
  expect_identical(attr(single, "id_columns"), "id")
  for (reader in list(
    collect_notes,
    collect_selections,
    collect_inner_metrics
  )) {
    out <- reader(single)
    expect_identical(names(out)[[1L]], "id")
    expect_false("id2" %in% names(out))
    expect_identical(out$id, single$id)
  }
})

# ---- the generics and their defaults (AC5) -----------------------------------

test_that("collect_selections() and collect_inner_metrics() refuse other objects, naming both", {
  for (obj in list(data.frame(a = 1), list(a = 1), 1:3)) {
    cnd <- rlang::catch_cnd(
      collect_selections(obj),
      "nestedtune_no_collect_method"
    )
    expect_s3_class(cnd, "nestedtune_no_collect_method")
    expect_match(conditionMessage(cnd), "collect_selections", fixed = TRUE)
    expect_match(conditionMessage(cnd), "has no method for", fixed = TRUE)
    expect_match(conditionMessage(cnd), "nested_results", fixed = TRUE)
    expect_no_match(conditionMessage(cnd), "applicable method")
    expect_identical(conditionCall(cnd)[[1L]], as.name("collect_selections"))

    cnd <- rlang::catch_cnd(
      collect_inner_metrics(obj),
      "nestedtune_no_collect_method"
    )
    expect_s3_class(cnd, "nestedtune_no_collect_method")
    expect_match(conditionMessage(cnd), "collect_inner_metrics", fixed = TRUE)
    expect_match(conditionMessage(cnd), "has no method for", fixed = TRUE)
    expect_identical(
      conditionCall(cnd)[[1L]],
      as.name("collect_inner_metrics")
    )
  }
  expect_error(
    collect_selections(data.frame(a = 1), foo = 1),
    class = "rlib_error_dots_nonempty"
  )
})

test_that("collect_notes() is tune's generic, re-exported", {
  expect_identical(collect_notes, tune::collect_notes)
})
