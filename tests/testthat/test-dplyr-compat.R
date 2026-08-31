# What a dplyr verb may and may not do to a `nested_results` (#32).
#
# The invariant set is tune's, for `tune_results` (tune#221): rows cannot be
# added or removed, rows may be reordered, columns may be added and reordered.
# An operation that stays inside it gets the class back with the run's record
# intact; anything else gets a bare tibble, because an object that no longer
# holds the rows the run produced cannot answer for the run (IP4).
#
# The whole point is the second branch, so the table below states an expected
# branch per entry rather than accepting either. Every verb the criteria name
# appears by its own literal name, and the verbs with something to say in both
# directions get an entry each way.

# The completed fixture. Constructed identically to the one in
# test-nested-tune-grid-results.R -- same data, same design seed, same tuning
# seed -- so the suite-level cache serves both from a single fit.
compat_results <- function() {
  d <- make_reg_data()
  wf <- det_workflow(d)
  set.seed(1)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(55)
  memoised(nested_tune_grid(
    wf,
    folds,
    grid = det_grid(),
    metrics = reg_metrics()
  ))
}

# The partial fixture, for the one criterion form that needs a fold to be
# missing: `filter(.completed)` removes a row only when a fold failed, and on a
# run where every fold completed it is a no-op that keeps the class. Same
# construction as test-nested-tune-grid-failures.R's, so this is also a cache
# hit rather than a second broken run.
partial_results <- function() {
  d <- make_reg_data()
  nested <- break_fold(det_nested(d), fold = 2L, stage = "inner tuning")
  set.seed(2)
  suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d),
    nested,
    grid = det_grid(),
    metrics = reg_metrics()
  )))
}

# Branch (a): the class is back, the call's record is the source's, and the
# fold counts describe the rows in hand rather than the rows they came from.
expect_kept <- function(out, src) {
  testthat::expect_s3_class(out, "nested_results")
  testthat::expect_identical(attr(out, "outer_label"), attr(src, "outer_label"))
  testthat::expect_identical(attr(out, "grid"), attr(src, "grid"))
  testthat::expect_identical(attr(out, "metrics"), attr(src, "metrics"))
  testthat::expect_identical(attr(out, "folds_attempted"), nrow(out))
  testthat::expect_identical(attr(out, "folds_completed"), sum(out$.completed))
  invisible(out)
}

# Branch (b): no claim to be a results object at all.
expect_bare <- function(out) {
  testthat::expect_false(inherits(out, "nested_results"))
  invisible(out)
}

# One entry per verb-and-direction. `branch` is what the entry must do, not
# what it happens to do.
dplyr_compat_table <- function() {
  list(
    list(name = "filter (rows kept)", branch = "kept", f = function(x) {
      dplyr::filter(x, rlang::.data$.completed)
    }),
    list(name = "slice", branch = "bare", f = function(x) dplyr::slice(x, 1)),
    list(name = "arrange", branch = "kept", f = function(x) {
      dplyr::arrange(x, dplyr::desc(rlang::.data$id))
    }),
    list(name = "mutate (column added)", branch = "kept", f = function(x) {
      dplyr::mutate(x, extra = 1)
    }),
    list(
      name = "mutate (record column overwritten)",
      branch = "bare",
      f = function(x) {
        dplyr::mutate(x, .completed = FALSE)
      }
    ),
    list(name = "select (all columns)", branch = "kept", f = function(x) {
      dplyr::select(x, dplyr::everything())
    }),
    list(
      name = "select (record column dropped)",
      branch = "bare",
      f = function(x) {
        dplyr::select(x, "id")
      }
    ),
    list(name = "rename", branch = "bare", f = function(x) {
      dplyr::rename(x, fold = "id")
    }),
    list(name = "relocate", branch = "kept", f = function(x) {
      dplyr::relocate(x, ".completed")
    }),
    list(name = "group_by", branch = "bare", f = function(x) {
      dplyr::group_by(x, rlang::.data$id)
    }),
    list(name = "ungroup", branch = "bare", f = function(x) {
      dplyr::ungroup(dplyr::group_by(x, rlang::.data$id))
    }),
    list(name = "bind_rows", branch = "bare", f = function(x) {
      dplyr::bind_rows(x, x)
    }),
    list(name = "bind_cols", branch = "kept", f = function(x) {
      dplyr::bind_cols(x, data.frame(extra = seq_len(nrow(x))))
    }),
    list(name = "left_join", branch = "kept", f = function(x) {
      dplyr::left_join(
        x,
        data.frame(id = x$id, extra = seq_len(nrow(x))),
        by = "id"
      )
    }),
    list(name = "[ (all rows)", branch = "kept", f = function(x) {
      x[rep(TRUE, nrow(x)), ]
    }),
    list(name = "[ (one row)", branch = "bare", f = function(x) x[1, ])
  )
}

test_that("every dplyr verb lands in the branch the invariants assign it", {
  skip_if_no_engines()
  res <- compat_results()

  for (case in dplyr_compat_table()) {
    out <- case$f(res)
    if (case$branch == "kept") {
      testthat::expect_s3_class(out, "nested_results")
      expect_kept(out, res)
    } else {
      testthat::expect_false(
        inherits(out, "nested_results"),
        label = paste0(case$name, " keeps the class")
      )
    }
  }
})

# The row-changing forms, one assertion apiece rather than a loop, so a failure
# names the form it was in. `filter(.completed)` is the one form that needs a
# run with a failed fold to remove anything at all.
test_that("filter() dropping a failed fold returns a bare tibble", {
  skip_if_no_engines()
  res <- partial_results()
  expect_false(all(res$.completed))
  expect_bare(dplyr::filter(res, rlang::.data$.completed))
})

test_that("slice() taking one row returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(dplyr::slice(compat_results(), 1))
})

test_that("slice() dropping one row returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(dplyr::slice(compat_results(), -1))
})

test_that("head() taking one row returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(head(compat_results(), 1))
})

test_that("[ with a row index returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(compat_results()[1, ])
})

test_that("[ with a logical row mask returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(compat_results()[c(TRUE, FALSE, FALSE), ])
})

test_that("[ with a negative row index returns a bare tibble", {
  skip_if_no_engines()
  expect_bare(compat_results()[-1, ])
})

test_that("bind_rows() doubling the rows returns a bare tibble", {
  skip_if_no_engines()
  res <- compat_results()
  expect_bare(dplyr::bind_rows(res, res))
})

# None of them may print the outer scheme either. The class check above is the
# mechanism; this is the claim a user actually sees, and it is asserted
# separately so a future object that sheds the class while keeping the print
# method cannot pass silently.
test_that("no row-changing result prints the outer resampling scheme", {
  skip_if_no_engines()
  res <- compat_results()
  partial <- partial_results()

  expect_identical(attr(res, "outer_label"), "3-fold cross-validation")
  expect_match(print_text(res), "Outer resamples: 3-fold cross-validation")

  forms <- list(
    dplyr::filter(partial, rlang::.data$.completed),
    dplyr::slice(res, 1),
    dplyr::slice(res, -1),
    head(res, 1),
    res[1, ],
    res[c(TRUE, FALSE, FALSE), ],
    res[-1, ],
    dplyr::bind_rows(res, res)
  )

  for (out in forms) {
    expect_no_match(print_text(out), "Outer resamples: 3-fold cross-validation")
  }
})
