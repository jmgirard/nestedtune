# Extracted from test-dplyr-compat.R:439

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "nestedtune", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
compat_results <- function() {
  d <- make_reg_data()
  set.seed(2)
  memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = det_grid(),
    metrics = reg_metrics()
  ))
}
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
expect_kept <- function(out, src) {
  testthat::expect_s3_class(out, "nested_results")
  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_identical(attr(out, "outer_label"), attr(src, "outer_label"))
  testthat::expect_identical(attr(out, "grid"), attr(src, "grid"))
  testthat::expect_identical(attr(out, "metrics"), attr(src, "metrics"))
  testthat::expect_identical(attr(out, "folds_attempted"), nrow(out))
  testthat::expect_identical(attr(out, "folds_completed"), sum(out$.completed))
  invisible(out)
}
expect_bare <- function(out, name = NULL) {
  what <- if (is.null(name)) "the result" else name
  testthat::expect_false(
    inherits(out, "nested_results"),
    label = paste0(what, " keeps the class")
  )
  testthat::expect_true(
    inherits(out, "tbl_df"),
    label = paste0(what, " is a tibble")
  )
  invisible(out)
}
dplyr_compat_table <- function() {
  list(
    list(name = "filter (rows kept)", branch = "kept", f = function(x) {
      dplyr::filter(x, .completed)
    }),
    list(name = "slice", branch = "bare", f = function(x) dplyr::slice(x, 1)),
    list(name = "arrange", branch = "kept", f = function(x) {
      dplyr::arrange(x, dplyr::desc(id))
    }),
    list(name = "mutate (column added)", branch = "kept", f = function(x) {
      dplyr::mutate(x, extra = 1)
    }),
    # An id-prefixed name is what a caller joins in to label folds with, and
    # the record's own id columns are found by grepping `^id`, so an added one
    # lands in the same set. "Columns may be added" has to hold for it too
    # (M36 review F2).
    list(name = "mutate (id-prefixed column added)", branch = "kept", f = function(x) {
      dplyr::mutate(x, id_extra = 1)
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
    # `rename()` is the one verb in the set that never asks. dplyr implements it
    # as `set_names()`, so it reaches the class through `names<-` and vctrs
    # rather than through `dplyr_reconstruct()`, and this package registers no
    # vctrs methods (M36 Out; tune ships them, which is why the same call on a
    # `tune_results` sheds the class -- measured 2026-08-31). What comes back is
    # still self-consistent -- same rows, same counts, same scheme -- so it is a
    # legitimate first branch rather than the stale claim this file exists to
    # stop, and the criterion is asserted as the disjunction it is written as.
    list(name = "rename", branch = "either", f = function(x) {
      dplyr::rename(x, fold = "id")
    }),
    list(name = "relocate", branch = "kept", f = function(x) {
      dplyr::relocate(x, ".completed")
    }),
    list(name = "group_by", branch = "bare", f = function(x) {
      dplyr::group_by(x, id)
    }),
    list(name = "ungroup", branch = "bare", f = function(x) {
      dplyr::ungroup(dplyr::group_by(x, id))
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
printed_all <- function(x) {
  paste(c(utils::capture.output(print(x)), print_text(x)), collapse = "\n")
}
doc_sources <- function() {
  list(
    roxygen = test_path("..", "..", "R", "nested-tune-grid.R"),
    rd = test_path("..", "..", "man", "nested_tune_grid.Rd")
  )
}
doc_text <- function(path) {
  gsub("\\s+", " ", paste(readLines(path, warn = FALSE), collapse = " "))
}
repeated_shape <- function(res) {
  out <- res
  out$id <- c("Repeat1", "Repeat1", "Repeat2")
  out$id2 <- c("Fold1", "Fold2", "Fold1")
  out
}

# test -------------------------------------------------------------------------
skip_if_no_engines()
res <- compat_results()
changed <- res
changed$.tuning_seed <- changed$.tuning_seed + 1L
template <- res
names(template)[names(template) == "id"] <- "fold"
expect_true(nestedtune:::can_reconstruct_results(res, res))
expect_false(nestedtune:::can_reconstruct_results(changed, res))
expect_false(nestedtune:::can_reconstruct_results(changed, template))
