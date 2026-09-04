# What a vctrs verb, and base `rbind()`, may and may not do to a
# `nested_results` (#32).
#
# The invariants are the ones M36 wrote for dplyr, and they are the same
# invariants: rows may be reordered but never added or removed, columns may be
# added and reordered. What is different here is the door. `vec_slice()`,
# `vec_rbind()`, `vec_c()`, `vec_cbind()`, `vec_ptype()` and `vec_cast()` all
# reach `vec_restore()` and never `dplyr_reconstruct()`; `rbind()` and
# `rename()` reach neither generic and need methods of their own (measured
# 2026-08-31, on a tibble subclass carrying each method set in turn).
#
# A caller cannot see which door a verb uses, so the answer has to be the same
# through all of them, and the assertions below are written per form rather
# than in one loop so a failure says which form regressed.

# The completed fixture, written exactly as test-dplyr-compat.R writes it: same
# function, same arguments, same RNG state, so `memoised()` serves this file
# from that one's build rather than fitting a second time.
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

# Shedding the class sheds the run's record with it. Asserting only the class
# would leave `outer_label` readable on the returned object, which is the
# stale claim one layer down (M36's `bare_results()`). The two private
# carriers a prototype rides on are asserted gone with the rest: a bare table
# still wearing them would be read as a template by the next `vec_restore()`.
expect_no_record <- function(out, name) {
  testthat::expect_false(
    inherits(out, "nested_results"),
    label = paste0(name, " keeps the class")
  )
  for (nm in c(results_attributes(), template_attributes())) {
    testthat::expect_null(attr(out, nm), label = paste0(name, " attr ", nm))
  }
  invisible(out)
}

# The run's record, carried across unchanged. `folds_attempted` and
# `folds_completed` are read off the rows rather than compared to the source,
# because they describe the object in hand.
expect_record_kept <- function(out, src) {
  testthat::expect_s3_class(out, "nested_results")
  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_identical(attr(out, "outer_label"), attr(src, "outer_label"))
  testthat::expect_identical(attr(out, "grid"), attr(src, "grid"))
  testthat::expect_identical(attr(out, "metrics"), attr(src, "metrics"))
  testthat::expect_identical(attr(out, "procedure"), attr(src, "procedure"))
  testthat::expect_identical(attr(out, "inside"), attr(src, "inside"))
  testthat::expect_identical(attr(out, "folds_attempted"), nrow(out))
  testthat::expect_identical(attr(out, "folds_completed"), sum(out$.completed))
  invisible(out)
}

# AC1. Each form one block apiece.

test_that("vec_slice() taking one row keeps neither the class nor the record", {
  skip_if_no_engines()
  expect_no_record(vctrs::vec_slice(compat_results(), 1), "vec_slice(x, 1)")
})

test_that("vec_rbind() doubling the rows keeps neither the class nor the record", {
  skip_if_no_engines()
  res <- compat_results()
  out <- vctrs::vec_rbind(res, res)
  expect_identical(nrow(out), 6L)
  expect_no_record(out, "vec_rbind(x, x)")
})

test_that("vec_c() doubling the rows keeps neither the class nor the record", {
  skip_if_no_engines()
  res <- compat_results()
  out <- vctrs::vec_c(res, res)
  expect_identical(nrow(out), 6L)
  expect_no_record(out, "vec_c(x, x)")
})

test_that("rbind() doubling the rows keeps neither the class nor the record", {
  skip_if_no_engines()
  res <- compat_results()
  out <- rbind(res, res)
  # The gap this milestone closes: six rows still reporting three folds
  # attempted is the untrue record IP4 forbids, and it is what rsample and tune
  # both return here (measured 2026-08-31 on an `rset`).
  expect_identical(nrow(out), 6L)
  expect_no_record(out, "rbind(x, x)")
})

test_that("rename() moving a record column keeps neither the class nor the record", {
  skip_if_no_engines()
  res <- compat_results()
  out <- dplyr::rename(res, fold = "id")
  expect_true("fold" %in% names(out))
  expect_false("id" %in% names(out))
  expect_no_record(out, "rename(x, fold = id)")
})

# Every record column in turn, through `names<-` directly -- the door
# `rename()` uses -- and a column outside the record, which the record does
# not depend on and whose rename keeps the object whole.
test_that("names<- sheds the record for every record column and keeps it for a column outside it", {
  skip_if_no_engines()
  res <- compat_results()
  record <- which(record_columns(res))
  expect_true(length(record) >= 8L)

  for (i in record) {
    nm <- names(res)[[i]]
    out <- res
    names(out)[[i]] <- "renamed"
    expect_no_record(out, paste0("names<- on ", nm))
    # The passing control: the column really was renamed.
    expect_false(nm %in% names(out), label = paste0(nm, " still present"))
  }

  with_extra <- dplyr::mutate(res, extra = seq_len(dplyr::n()))
  expect_record_kept(with_extra, res)
  out <- with_extra
  names(out)[names(out) == "extra"] <- "renamed"
  expect_record_kept(out, res)
  expect_identical(
    attributes(out)[setdiff(names(attributes(out)), "names")],
    attributes(with_extra)[setdiff(names(attributes(with_extra)), "names")]
  )
  expect_true("renamed" %in% names(out))
  expect_false("extra" %in% names(out))

  # A column outside the record taking a record column's name is a duplicate,
  # and sheds the record like a moved one.
  clash <- with_extra
  names(clash)[names(clash) == "extra"] <- "splits"
  expect_no_record(clash, "names<- duplicating splits")
})

# AC2. Reordering rows is inside the invariants: the folds are a set, and an
# object holding all of them still answers for the run whatever order they sit
# in.

test_that("vec_slice() reordering the rows keeps the class and the record", {
  skip_if_no_engines()
  res <- compat_results()
  out <- vctrs::vec_slice(res, c(2, 1, 3))

  expect_record_kept(out, res)
  expect_identical(out$id, res$id[c(2, 1, 3)])
  # The passing control for the assertion above: the source's own order is not
  # the order asked for, so an implementation that ignored the index and handed
  # back `res` would fail it.
  expect_false(identical(res$id[c(2, 1, 3)], res$id))
})

# AC3. The same operation through either door.

test_that("vec_cbind() and bind_cols() adding a column answer the same way", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  extra <- tibble::tibble(extra = 1:3)

  through_vctrs <- vctrs::vec_cbind(res, extra)
  through_dplyr <- dplyr::bind_cols(res, extra)

  expect_record_kept(through_vctrs, res)
  expect_record_kept(through_dplyr, res)
  expect_identical(class(through_vctrs), class(through_dplyr))
  expect_true("extra" %in% names(through_vctrs))
  expect_true("extra" %in% names(through_dplyr))
})

# The type token vctrs assembles a column-add into. It wears the class, so IP4
# governs what it says about a run: it describes the run it came from and
# claims no rows of its own. The generic is vctrs' own internal-marked surface
# -- calling it directly is the only way to hold the token at all (RR04 Q4).

test_that("the frame prototype carries the run's description and no fold counts", {
  skip_if_no_engines()
  res <- compat_results()

  token <- vctrs::vec_cbind_frame_ptype(res)

  expect_s3_class(token, "nested_results")
  expect_identical(length(token), 0L)
  expect_identical(attr(token, "outer_label"), attr(res, "outer_label"))
  expect_identical(attr(token, "grid"), attr(res, "grid"))
  expect_null(attr(token, "folds_attempted"))
  expect_null(attr(token, "folds_completed"))
})

# Printing the token says only what it holds. The outer-label line would
# describe a run the token has no rows of, and the fold-count line reads a
# column it does not carry: before M56, `print()` wrote the label and then
# errored on the missing `.completed` (measured 2026-09-03).
test_that("printing the frame prototype emits neither the outer label nor a fold count", {
  skip_if_no_engines()
  res <- compat_results()
  token <- vctrs::vec_cbind_frame_ptype(res)

  lines <- NULL
  expect_no_error(lines <- cli::cli_fmt(print(token)))
  expect_false(any(grepl("Outer resamples", lines, fixed = TRUE)))
  # Everything written is the banner and the rows: after the blank line
  # `cli_h1()` opens with, the banner, then the tibble header and nothing
  # after it (a columnless tibble prints no body), so a fold-count line has
  # nowhere to hide. Measured on the fixture 2026-09-03: three lines.
  body <- lines[nzchar(lines)]
  expect_length(body, 2L)
  expect_true(grepl(
    "Nested cross-validation results",
    body[[1L]],
    fixed = TRUE
  ))
  # `×` under cli's unicode output, `x` under testthat's ASCII one.
  expect_true(grepl("^# A tibble: [0-9]+ [×x] 0\\s*$", body[[2L]]))

  # The passing control: the same method on the object the token came from
  # writes the label line, so the two absences above are the token's and not
  # the method's.
  full <- cli::cli_fmt(print(res))
  expect_true(any(grepl("Outer resamples", full, fixed = TRUE)))
})

# AC4. A results object casts down to a table; a table does not cast up to a
# results object. The refusal is asserted by the condition class vctrs assigns
# it, not by its message, and `vctrs_error_cast_lossy` is excluded so the
# refusal is distinguished from an ordinary lossy cast.

test_that("a nested_results casts to its own tibble prototype", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  proto <- tibble::as_tibble(vctrs::vec_ptype(res))

  out <- vctrs::vec_cast(res, proto)
  expect_no_record(out, "vec_cast(x, prototype)")
  expect_identical(names(out), names(res))
})

test_that("a tibble does not cast to a nested_results", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  proto <- tibble::as_tibble(vctrs::vec_ptype(res))

  cnd <- expect_error(vctrs::vec_cast(proto, res), class = "vctrs_error_cast")
  expect_false(inherits(cnd, "vctrs_error_cast_lossy"))
})

# AC5. `vec_ptype2()` answers rather than aborting, on every ordered pair of
# the three types a caller can combine here. The common type is asserted only
# as "a prototype" -- what the class of that prototype should be is settled by
# AC3's behavior, not restated here.

test_that("vec_ptype2() returns a prototype for every pair of the three types", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  tbl <- tibble::as_tibble(vctrs::vec_ptype(res))
  df <- as.data.frame(tbl)

  pairs <- list(
    "nested_results, nested_results" = list(res, res),
    "nested_results, tbl_df" = list(res, tbl),
    "tbl_df, nested_results" = list(tbl, res),
    "nested_results, data.frame" = list(res, df),
    "data.frame, nested_results" = list(df, res)
  )

  for (nm in names(pairs)) {
    out <- vctrs::vec_ptype2(pairs[[nm]][[1L]], pairs[[nm]][[2L]])
    expect_true(is.data.frame(out), label = paste0(nm, " is a data frame"))
    expect_identical(nrow(out), 0L, label = paste0(nm, " row count"))
  }
})

# AC6. The three verbs this milestone deliberately leaves alone. Each returns
# an object that no longer claims to be a results object, and the run's
# recorded attributes stay readable on it -- which is what the help page says,
# and what rsample does with its own.

test_that("group_by(), rowwise() and as_tibble() leave the recorded attributes readable", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()

  forms <- list(
    group_by = dplyr::group_by(res, id),
    rowwise = dplyr::rowwise(res),
    as_tibble = tibble::as_tibble(res)
  )

  for (nm in names(forms)) {
    out <- forms[[nm]]
    expect_identical(
      attr(out, "outer_label"),
      attr(res, "outer_label"),
      label = paste0(nm, " outer_label")
    )
    expect_identical(
      attr(out, "folds_attempted"),
      attr(res, "folds_attempted"),
      label = paste0(nm, " folds_attempted")
    )
  }

  # The passing control for the assertions above: the source really does carry
  # the label they compare against, so a run where every attribute was NULL
  # could not pass them for the wrong reason.
  expect_identical(attr(res, "outer_label"), "3-fold cross-validation")
})

# The review's two returns. Neither is an acceptance criterion -- both are
# defects the review found in the methods above -- so each is asserted against
# behavior that already existed somewhere else: what `main` did before these
# methods were registered (T6), and what `dplyr::bind_cols()` does today (T7).

test_that("combining with a table whose columns differ answers rather than raising", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  other <- tibble::tibble(other = 1)

  forms <- list(
    bind_rows = dplyr::bind_rows(res, other),
    vec_rbind = vctrs::vec_rbind(res, other)
  )

  for (nm in names(forms)) {
    out <- forms[[nm]]
    expect_no_record(out, paste0(nm, "() over an unshared column"))
    expect_identical(
      names(out),
      c(names(res), "other"),
      label = paste0(nm, " names")
    )
    expect_identical(nrow(out), nrow(res) + 1L, label = paste0(nm, " rows"))
    # The union is what the answer rests on: the rows the source contributed
    # carry no value for a column it never had.
    expect_identical(out$other, c(NA, NA, NA, 1), label = paste0(nm, " other"))
  }

  # The passing control: the two tables really do differ in their columns, so a
  # run where `other` were already a column of `res` could not pass the above
  # for the wrong reason.
  expect_false("other" %in% names(res))
})

test_that("vec_cbind() sheds the class when name repair moves a record column", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  clash <- tibble::tibble(splits = 1:3)

  through_vctrs <- suppressMessages(vctrs::vec_cbind(res, clash))
  through_dplyr <- suppressMessages(dplyr::bind_cols(res, clash))

  expect_no_record(through_vctrs, "vec_cbind() over a record column")
  expect_identical(class(through_vctrs), class(through_dplyr))
  expect_identical(names(through_vctrs), names(through_dplyr))

  # The passing control: name repair really did move the record column, so the
  # assertions above cannot pass on a call that left `splits` where it was.
  expect_false("splits" %in% names(through_vctrs))
  expect_true("splits" %in% names(res))
})

# The same clash with the repair switched off: both `splits` columns keep the
# name, every record name is still present, and `$splits` answers with the
# first. Before M56 the class survived and `attr(out, "folds_completed")` was
# stamped on a table whose record can no longer be found by name (measured
# 2026-09-03).
test_that("vec_cbind() sheds the class when minimal name repair duplicates a record column", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  clash <- tibble::tibble(splits = seq_len(nrow(res)))

  through_vctrs <- vctrs::vec_cbind(res, clash, .name_repair = "minimal")
  through_dplyr <- dplyr::bind_cols(res, clash, .name_repair = "minimal")

  expect_no_record(
    through_vctrs,
    "vec_cbind(.name_repair = \"minimal\") over a record column"
  )
  expect_no_record(
    through_dplyr,
    "bind_cols(.name_repair = \"minimal\") over a record column"
  )
  expect_identical(class(through_vctrs), class(through_dplyr))
  expect_identical(names(through_vctrs), names(through_dplyr))

  # The passing control: the name really is duplicated, so the shed above is
  # the duplicate's and not a moved column's.
  expect_identical(sum(names(through_vctrs) == "splits"), 2L)
})

# The duplicate rule is the record's, not every name's: two caller-added
# columns coming to share a name touch nothing the record is read from, so
# the object keeps its class and attributes through the column-add doors and
# through `names<-` alike. Before M56's return, all three doors counted
# duplicates over every name and shed the record here (measured 2026-09-03;
# M56 review F1).
test_that("a name shared by two columns outside the record keeps the object through every door", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  with_extra <- dplyr::mutate(res, extra = seq_len(dplyr::n()))
  expect_record_kept(with_extra, res)
  clash <- tibble::tibble(extra = seq_len(nrow(res)) + 10L)

  through_vctrs <- vctrs::vec_cbind(with_extra, clash, .name_repair = "minimal")
  through_dplyr <- dplyr::bind_cols(with_extra, clash, .name_repair = "minimal")
  expect_record_kept(through_vctrs, res)
  expect_record_kept(through_dplyr, res)
  expect_identical(class(through_vctrs), class(through_dplyr))

  two <- dplyr::mutate(with_extra, other = seq_len(dplyr::n()) + 20L)
  renamed <- two
  names(renamed)[names(renamed) == "other"] <- "extra"
  expect_record_kept(renamed, res)
  expect_identical(
    attributes(renamed)[setdiff(names(attributes(renamed)), "names")],
    attributes(two)[setdiff(names(attributes(two)), "names")]
  )

  # The passing control: the name really is duplicated on every door, so the
  # object kept above is one the duplicate reached and not one it missed.
  expect_identical(sum(names(through_vctrs) == "extra"), 2L)
  expect_identical(sum(names(through_dplyr) == "extra"), 2L)
  expect_identical(sum(names(renamed) == "extra"), 2L)
})

test_that("a column add answers the same through either door with the results object second", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  extra <- tibble::tibble(extra = 1:3)

  through_vctrs <- vctrs::vec_cbind(extra, res)
  through_dplyr <- dplyr::bind_cols(extra, res)

  expect_no_record(through_vctrs, "vec_cbind() with the results object second")
  expect_identical(class(through_vctrs), class(through_dplyr))
  expect_identical(names(through_vctrs), names(through_dplyr))

  # The passing control: the results object leading is the case that keeps the
  # class (AC3), so the shedding above is a property of the position and not of
  # the verb refusing every column add.
  expect_s3_class(vctrs::vec_cbind(res, extra), "nested_results")
})

# The one place the doors do not answer alike, pinned so the help page's
# paragraph on it cannot drift: `vec_rbind()` and `vec_c()` ask for the common
# type before they ask the rule anything, and the common type of one results
# object is a plain table, so a single-argument call sheds where
# `dplyr::bind_rows()` keeps. Recorded as R2 of M37's review.
test_that("vec_rbind() and vec_c() shed on one argument where bind_rows() keeps", {
  skip_if_no_engines()
  res <- compat_results()

  expect_no_record(vctrs::vec_rbind(res), "vec_rbind() on one argument")
  expect_no_record(vctrs::vec_c(res), "vec_c() on one argument")
  expect_s3_class(vctrs::vec_ptype(res), "tbl_df")
  expect_false(inherits(vctrs::vec_ptype(res), "nested_results"))

  # The passing control: the dplyr door keeps the class on the same call, so
  # the assertions above are about which door was used and not about a rule
  # that sheds on every combination verb.
  expect_s3_class(dplyr::bind_rows(res), "nested_results")

  # And neither door keeps it once there is something to combine with.
  expect_no_record(vctrs::vec_rbind(res, res), "vec_rbind() on two")
  expect_no_record(dplyr::bind_rows(res, res), "bind_rows() on two")
})

# M49, AC5: `.inner_metrics` through the vctrs doors. `vec_restore()` takes
# the original as template and refuses a frame lacking the column or carrying
# one fold's table changed; `rbind()` takes its first argument as template, so
# what it can refuse is the removal -- an object whose column was dropped
# under the class, which `$<-` leaves wearing it.

test_that(".inner_metrics is in the record vec_restore() and rbind() check", {
  skip_if_not_installed("tibble")
  skip_if_no_engines()
  res <- compat_results()
  bare <- tibble::as_tibble(res)

  without <- bare[setdiff(names(bare), ".inner_metrics")]
  expect_no_record(
    vctrs::vec_restore(without, res),
    "vec_restore() without .inner_metrics"
  )

  zeroed <- bare
  zeroed$.inner_metrics[[2L]] <- zeroed$.inner_metrics[[2L]][0, ]
  expect_no_record(
    vctrs::vec_restore(zeroed, res),
    "vec_restore() with fold 2's .inner_metrics zero-row"
  )
  shortened <- bare
  shortened$.inner_metrics[[2L]] <- shortened$.inner_metrics[[2L]][-1L, ]
  expect_no_record(
    vctrs::vec_restore(shortened, res),
    "vec_restore() with one row dropped from fold 2's .inner_metrics"
  )

  # `$<-` on a tibble reattaches the class without asking the rule, so this
  # object still wears it with the column gone; `rbind()` is the door that
  # then asks, against the object itself as template, and refuses.
  dropped <- res
  dropped$.inner_metrics <- NULL
  expect_s3_class(dropped, "nested_results")
  expect_no_record(rbind(dropped), "rbind() without .inner_metrics")

  # The passing controls: the unaltered frame restores, and the whole object
  # survives a one-argument rbind().
  expect_record_kept(vctrs::vec_restore(bare, res), res)
  expect_record_kept(rbind(res), res)
})

# --- tibble is a Suggest (M57) ----------------------------------------------
#
# `R-CMD-check-hard.yaml` installs no Suggests, and every block above that
# builds a `tibble::` value would fail there rather than skip. The check reads
# the blocks as code, so a block that acquires a `tibble::` call later is
# caught the day it does, and a skip in the wrong position -- after a line
# that already needs tibble -- counts as no skip at all.

# Whether `x` contains a `pkg::` call, walked as code rather than searched as
# text, so a string that happens to say `tibble::` -- this block's own
# description -- is not a use.
calls_namespace <- function(x, pkg) {
  if (!is.call(x)) {
    return(FALSE)
  }
  if (identical(x[[1L]], as.name("::")) && identical(x[[2L]], as.name(pkg))) {
    return(TRUE)
  }
  # Every element, the function position included: `tibble::tibble(...)` is a
  # call whose function is itself the `::` call.
  any(vapply(as.list(x), calls_namespace, logical(1), pkg = pkg))
}

test_that("every block that calls tibble:: opens with the tibble skip", {
  calls <- test_that_calls(test_path("test-vctrs-compat.R"))
  uses_tibble <- vapply(
    calls,
    function(call) calls_namespace(call$body, "tibble"),
    logical(1)
  )
  # The check is empty if nothing here calls tibble, which is not this file.
  expect_gt(sum(uses_tibble), 0L)

  opens_with_skip <- vapply(
    calls,
    function(call) {
      body <- call$body
      is.call(body) &&
        identical(body[[1L]], as.name("{")) &&
        length(body) > 1L &&
        identical(body[[2L]], quote(skip_if_not_installed("tibble")))
    },
    logical(1)
  )
  descriptions <- vapply(calls, `[[`, character(1), "description")
  expect_identical(
    descriptions[uses_tibble & !opens_with_skip],
    character()
  )
})
