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

# The completed fixture: the suite's most-requested three-fold run, written the
# way test-nested-results-print.R and test-nested-results-plot.R write it, so
# the cache serves this file without a further fit. A first attempt copied
# test-nested-tune-grid-results.R's builder instead and keyed separately from
# it, which the run-wide cache report caught as a fixture built twice.
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

# The partial fixture, for the one criterion form that needs a fold to be
# missing: `filter(.completed)` removes a row only when a fold failed, and on a
# run where every fold completed it is a no-op that keeps the class. Written as
# test-nested-tune-grid-failures.R writes it, so this is a cache hit too rather
# than a second broken run.
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
#
# `tbl_df` is asserted in both branches because dplyr hands
# `dplyr_reconstruct()` a bare data frame for several verbs, so a rule that
# only adds the class back returns a `nested_results` that is not a tibble --
# and the class is documented as a tibble subclass (M36 review F1).
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

# Branch (b): no claim to be a results object at all -- and still a tibble,
# which is not a downgrade the caller asked for.
# `name` is carried because the compat table calls this from a loop, where
# every entry shares one source line: without it a failure says only that some
# entry in the table went wrong (M36 review O7).
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

# One entry per verb-and-direction. `branch` is what the entry must do, not
# what it happens to do -- "kept" and "bare" each name one branch, and "either"
# is the criterion's own disjunction for the one verb that does not reach this
# package's rule at all (see `rename` below).
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
    # the record's own id columns were once found by matching a name pattern,
    # so an added one landed in the same set. `id_columns()` reads the
    # constructor's record instead, which no name can join. "Columns may be
    # added" has to hold for this one either way (M36 review F2, M38).
    list(
      name = "mutate (id-prefixed column added)",
      branch = "kept",
      f = function(x) {
        dplyr::mutate(x, id_extra = 1)
      }
    ),
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

test_that("every dplyr verb lands in the branch the invariants assign it", {
  skip_if_no_engines()
  res <- compat_results()

  for (case in dplyr_compat_table()) {
    out <- case$f(res)
    if (case$branch == "either") {
      if (inherits(out, "nested_results")) {
        expect_kept(out, res)
      } else {
        testthat::succeed()
      }
    } else if (case$branch == "kept") {
      testthat::expect_s3_class(out, "nested_results")
      expect_kept(out, res)
    } else {
      # The same assertion the standalone AC3 blocks make, `tbl_df` included:
      # asserting only the class absence here would let a table-only bare verb
      # lose its tibble classes silently (M36 review O7).
      expect_bare(out, case$name)
    }
  }
})

# The five verbs dplyr hands `dplyr_reconstruct()` a bare data frame for, named
# literally so a regression says which one lost its tibble classes rather than
# only that the table entry failed.
test_that("a verb that keeps the class returns a tibble, not a bare data frame", {
  skip_if_no_engines()
  res <- compat_results()

  forms <- list(
    filter = dplyr::filter(res, .completed),
    mutate = dplyr::mutate(res, extra = 1),
    arrange = dplyr::arrange(res, dplyr::desc(id)),
    bind_cols = dplyr::bind_cols(res, data.frame(extra = seq_len(nrow(res)))),
    left_join = dplyr::left_join(
      res,
      data.frame(id = res$id, extra = seq_len(nrow(res))),
      by = "id"
    )
  )

  for (nm in names(forms)) {
    expect_s3_class(forms[[nm]], "nested_results")
    expect_s3_class(forms[[nm]], "tbl_df")
  }

  # What the missing tibble classes cost a caller: `[.data.frame` drops to a
  # vector where `[.tbl_df` returns a one-column tibble.
  expect_s3_class(dplyr::mutate(res, extra = 1)[, "id"], "tbl_df")
})

# An added column is the caller's, whatever it is named. `id_extra` and `ideal`
# both matched the bare `^id` grep the record's own id columns were once found
# with, and `id2` matched the anchored pattern that replaced it. None of them
# reaches the constructor's record, which is what decides now (M38); the `id2`
# case has its own block below.
test_that("an id-prefixed column added by the caller keeps the class", {
  skip_if_no_engines()
  res <- compat_results()

  for (nm in c("id_extra", "ideal", "extra")) {
    out <- dplyr::mutate(res, !!nm := 1)
    expect_kept(out, res)
    expect_true(nm %in% names(out))
  }
})

# The row-changing forms, one assertion apiece rather than a loop, so a failure
# names the form it was in. `filter(.completed)` is the one form that needs a
# run with a failed fold to remove anything at all.
test_that("filter() dropping a failed fold returns a bare tibble", {
  skip_if_no_engines()
  res <- partial_results()
  expect_false(all(res$.completed))
  expect_bare(dplyr::filter(res, .completed))
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

# Everything an object puts on the screen, whichever way it gets there.
#
# `print_text()` captures cli output and nothing else, so it returns "" for a
# bare tibble -- and an assertion that "" does not contain the scheme line would
# pass for the wrong reason on every form below. `capture.output()` covers the
# other half. Each form's text is asserted non-empty before it is searched, so
# the negative assertions are known to have run over something.
printed_all <- function(x) {
  paste(c(utils::capture.output(print(x)), print_text(x)), collapse = "\n")
}

# None of them may print the outer scheme either. The class check above is the
# mechanism; this is the claim a user actually sees, and it is asserted
# separately so a future object that sheds the class while keeping the print
# method cannot pass silently.
test_that("no row-changing result prints the outer resampling scheme", {
  skip_if_no_engines()
  res <- compat_results()
  partial <- partial_results()

  # The passing control: the same helper, on the object that does say it.
  expect_identical(attr(res, "outer_label"), "3-fold cross-validation")
  expect_match(printed_all(res), "Outer resamples: 3-fold cross-validation")

  forms <- list(
    dplyr::filter(partial, .completed),
    dplyr::slice(res, 1),
    dplyr::slice(res, -1),
    head(res, 1),
    res[1, ],
    res[c(TRUE, FALSE, FALSE), ],
    res[-1, ],
    dplyr::bind_rows(res, res)
  )

  for (out in forms) {
    text <- printed_all(out)
    expect_true(nzchar(text))
    expect_no_match(text, "Outer resamples: 3-fold cross-validation")
  }
})

# The help page may not still promise the behavior this rule replaced (M36
# review O1).
#
# The behavioral half is already covered: test-nested-tune-grid-failures.R
# asserts that a row subset comes back with all five attributes NULL. What was
# missing is a guard on the prose, which went on promising the opposite in a
# `@details` paragraph that AC1's own grep was scoped away from. Both the
# roxygen source and the generated `.Rd` are read, because the sentence has to
# leave both.
#
# `test_path("..", "..", ...)` resolves outside the source tree under
# `R CMD check`, so this skips there and fires where the documentation is
# actually edited -- the same layout note test-vignette-citations.R records.
# Each file is asserted non-empty and shown to still carry the sentence that
# replaced the claim, so a mistyped path or an empty read cannot pass the
# negatives for the wrong reason.
doc_sources <- function() {
  list(
    roxygen = test_path("..", "..", "R", "nested-tune-grid.R"),
    rd = test_path("..", "..", "man", "nested_tune_grid.Rd")
  )
}

# One whitespace-normalized string per file, so a claim that happens to wrap
# across two lines is still found.
doc_text <- function(path) {
  gsub("\\s+", " ", paste(readLines(path, warn = FALSE), collapse = " "))
}

test_that("the help page makes no promise about what subsetting rows keeps", {
  paths <- doc_sources()
  skip_if_not(all(vapply(paths, file.exists, logical(1))), "sources absent")

  # Each claim is asserted by name, so a failure says which promise survived.
  claims <- c(
    "Subsetting rows recomputes",
    "Subsetting rows carries",
    "counts always describe the object in hand"
  )

  for (nm in names(paths)) {
    text <- doc_text(paths[[nm]])
    expect_gt(nchar(text), 1000L)
    # The passing control: the sentence that replaced the claim is present, so
    # the file being read is the one the claims would be in.
    expect_match(text, "returns a bare tibble", fixed = TRUE)
    for (claim in claims) {
      expect_no_match(text, claim, fixed = TRUE)
    }
  }
})

# How the object tells its own fold-label columns from ones a caller added.
#
# rsample names them `id`, and `id2`, `id3`... for a repeated design, which is
# exactly what the constructor takes off the rset -- and, since M38, records.
# Matching a name pattern instead also caught `ideal` and `id_extra` -- names a
# caller can perfectly well add -- and the three tests below are what that cost
# (M36 review O2, O3, O5).

# dplyr calls `dplyr_reconstruct()` a second time with the modified frame as
# the template, so an added column matching the id pattern joins the id columns
# and becomes a key in the `order()` call that puts both sides in id order
# before their values are compared. A list column is not orderable: the call
# died with `unimplemented type 'list' in 'listgreater'`, raised from inside the
# rule and naming no function the caller had heard of (M36 review O2). Reading
# the constructor's record closes it for any name at all, this one included: the
# added column is not in the record, so it is never a key (M38).
#
# The key is only reached where it is actually compared -- `id` has to tie, and
# the added column has to sort ahead of `id2` -- and that second condition is a
# question about collation rather than about the data. `id_junk`, the name the
# review measured it with, sorts before `id2` under this machine's locale and
# after it under the C collation `R CMD check` runs in, so the test would have
# been green on CI for a reason having nothing to do with the fix. `id0_junk`
# sorts ahead of `id2` in both, which is the point: whether a caller's column
# becomes an ordering key is not something the rule may depend on.
test_that("an added id-prefixed list column survives two verbs on a repeated design", {
  skip_if_no_engines()
  rep_res <- repeated_results()

  out <- dplyr::mutate(rep_res, id0_junk = as.list(seq_len(nrow(rep_res))))
  expect_kept(out, rep_res)

  out2 <- dplyr::arrange(out, dplyr::desc(id2))
  expect_kept(out2, rep_res)
  expect_true("id0_junk" %in% names(out2))
})

# "Columns may be added" implies the caller may take one away again. The record
# is read off the template, so a column the rule mistook for one of the design's
# own was protected as if the constructor had written it: the same round trip
# kept the class for `extra` and lost it for `ideal` under the bare `^id` grep,
# and for `id2` under the anchored pattern that replaced it. The `id2` case has
# its own block below.
test_that("a column the caller added can be removed again, whatever it is named", {
  skip_if_no_engines()
  res <- compat_results()

  for (nm in c("ideal", "id_extra", "extra")) {
    out <- dplyr::select(dplyr::mutate(res, !!nm := 1), -dplyr::all_of(nm))
    expect_kept(out, res)
    expect_false(nm %in% names(out))
  }
})

# The value comparison must not be able to go vacuous. Both sides are put in id
# order before their record columns are compared, so a template whose record
# holds no id column at all gives an empty ordering, zero-length columns on
# both sides, and `identical()` for any two objects. Not reachable through a
# verb -- an object whose id column was renamed fails the `data`-side column
# gate first -- so the rule is called directly.
test_that("a template with no id column of its own cannot be reconstructed onto", {
  skip_if_no_engines()
  res <- compat_results()

  changed <- res
  changed$.tuning_seed <- changed$.tuning_seed + 1L
  template <- res
  names(template)[names(template) == "id"] <- "fold"

  # Passing controls: the same pair is accepted when nothing differs and
  # rejected, for the seeds, when the template does carry its id column.
  expect_true(nestedtune:::can_reconstruct_results(res, res))
  expect_false(nestedtune:::can_reconstruct_results(changed, res))

  expect_false(nestedtune:::can_reconstruct_results(changed, template))
})

# The fold labels are found the same way, so an added `id_extra` was pasted
# into every one of them: `collect_metrics(summarize = FALSE)` reported the
# folds as "Fold1, x" and so on. This one predates the milestone -- reproduced
# on the default branch -- and goes with the same helper.
test_that("a column the caller added is not pasted into the fold labels", {
  skip_if_no_engines()
  res <- compat_results()

  labels <- collect_metrics(res, summarize = FALSE)$id
  expect_setequal(labels, c("Fold1", "Fold2", "Fold3"))

  out <- dplyr::mutate(res, id_extra = "x")
  expect_s3_class(out, "nested_results")
  expect_identical(collect_metrics(out, summarize = FALSE)$id, labels)
})

# The four forms that survived M36, all of them the same fault: the design's own
# label columns were found by matching `^id[0-9]*$` against whatever names the
# object happened to carry, so a caller's column landed in the set whenever its
# name fell inside the pattern -- and a design column the caller replaced fell
# out of it. Since M38 the constructor records the names it took off the rset
# and every reader asks that record, so no name decides anything.

# `id2` is what rsample calls the second label column of a REPEATED design, so
# on a plain three-fold run it is a name a caller may use and the pattern caught
# it anyway. Measured on the default branch 2026-08-31:
# `unique(collect_metrics(dplyr::mutate(res, id2 = "x"), summarize = FALSE)$id)`
# was `c("Fold1, x", "Fold2, x", "Fold3, x")`.
test_that("a column named `id2` on a plain design is not pasted into the fold labels", {
  skip_if_no_engines()
  res <- compat_results()

  # The passing control: the same call on the object with nothing added.
  expect_identical(
    unique(collect_metrics(res, summarize = FALSE)$id),
    c("Fold1", "Fold2", "Fold3")
  )

  out <- dplyr::mutate(res, id2 = "x")
  expect_identical(
    unique(collect_metrics(out, summarize = FALSE)$id),
    c("Fold1", "Fold2", "Fold3")
  )
})

# "Columns may be added" implies the caller may take one away again, and the
# answer cannot depend on the spelling. Measured on the default branch
# 2026-08-31: `dplyr::select(dplyr::mutate(res, id2 = 1), -id2)` was a `tbl_df`
# where the same round trip on `extra` was a `nested_results`.
test_that("a column named `id2` on a plain design can be removed again", {
  skip_if_no_engines()
  res <- compat_results()

  # The passing control: the same round trip under a name no pattern matched.
  expect_kept(dplyr::select(dplyr::mutate(res, extra = 1), -extra), res)

  out <- dplyr::select(dplyr::mutate(res, id2 = 1), -id2)
  expect_kept(out, res)
  expect_false("id2" %in% names(out))
})

# A caller's list column becomes an ordering key only where the rule mistakes it
# for one of the design's own. It takes a repeated design to reach: `id` ties
# across a repeat, so the second key is actually compared. Measured on the
# default branch 2026-08-31:
# `dplyr::mutate(rep_res, id0 = as.list(seq_len(nrow(rep_res))))` aborted with
# `unimplemented type 'list' in 'listgreater'`, raised from inside the rule.
test_that("a list column named `id0` survives a verb on a repeated design", {
  skip_if_no_engines()
  rep_res <- repeated_results()

  # The passing control: the same list column under a name no pattern matched.
  expect_kept(
    dplyr::mutate(rep_res, extra = as.list(seq_len(nrow(rep_res)))),
    rep_res
  )

  out <- dplyr::mutate(rep_res, id0 = as.list(seq_len(nrow(rep_res))))
  expect_kept(out, rep_res)
  expect_true("id0" %in% names(out))
})

# The other direction: a label column the design DID name, replaced by something
# `order()` cannot take. The record no longer matches, so the honest answer is a
# bare tibble -- and the rule has to reach that answer rather than die on the
# way to it. Measured on the default branch 2026-08-31:
# `dplyr::mutate(res, id = list(c(1, 2), 3, 4))` aborted with
# `unimplemented type 'list' in 'orderVector1'`, naming no function the caller
# had heard of.
test_that("replacing a fold-label column with an unorderable value returns a bare tibble", {
  skip_if_no_engines()
  res <- compat_results()

  expect_no_condition(out <- dplyr::mutate(res, id = list(c(1, 2), 3, 4)))
  expect_bare(out)
})

# The same answer for a label column `order()` takes but cannot compare under.
# A matrix is atomic, so `is.atomic()` alone let it through; `order()` then reads
# it column by column and hands back a permutation twice the object's length,
# which indexes both sides out to the same NA padding and made identical() vouch
# for a record it never compared. Measured before the guard learned about `dim`:
# `dplyr::mutate(m, extra = 1)` on a results object whose `id` is a 3x2 matrix
# returned a `nested_results` (2026-08-31, M38 review O4).
test_that("a fold-label column with a dim is refused rather than compared", {
  skip_if_no_engines()
  res <- compat_results()
  res$id <- matrix(seq_len(2L * nrow(res)), nrow = nrow(res))

  expect_true(is.atomic(res$id))
  expect_no_condition(out <- dplyr::mutate(res, extra = 1))
  expect_bare(out)
})
