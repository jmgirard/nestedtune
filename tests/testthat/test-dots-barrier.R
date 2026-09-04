# The `...` barrier on the exported surface (M34).
#
# Four exports and every registered method now take `...` and refuse anything
# that lands in it. What the tests below have to distinguish is a fence from an
# accident: a method handed `nonesuch = 1` and a stand-in object errors either
# way, so every probe asserts the *class* of the condition -- rlang's
# `rlib_error_dots_nonempty`, or this package's `nestedtune_bad_dots` on the
# two orchestrators, whose `...` admits `control` and nothing else (M48) --
# and never merely that something went wrong.

# AC1 -------------------------------------------------------------------

test_that("AC1: the four entry points carry `...` after their required arguments", {
  # Written out rather than derived, so a signature that drifts has to be
  # re-agreed here. For nested_tune_grid(), `param_info`, `grid`, `metrics` and
  # `event_level` all sit behind the barrier and therefore match by name only,
  # as does `eval_time` (M41).
  expect_identical(
    names(formals(nested_tune_grid)),
    c(
      "object",
      "resamples",
      "...",
      "param_info",
      "grid",
      "metrics",
      "event_level",
      "eval_time"
    )
  )
  # Its sibling (M45) puts its own three arguments behind the same barrier.
  expect_identical(
    names(formals(nested_tune_bayes)),
    c(
      "object",
      "resamples",
      "...",
      "iter",
      "param_info",
      "metrics",
      "initial",
      "objective",
      "event_level",
      "eval_time"
    )
  )
  # nested_final_fit() takes only `object` and `results` now (M46): the
  # procedure that once sat behind its barrier -- `param_info`, `grid`,
  # `metrics`, `event_level`, `eval_time` -- is read off `results` instead.
  expect_identical(
    names(formals(nested_final_fit)),
    c("object", "results", "...")
  )
  # All three of `nested_resamples()`'s arguments are required, so its barrier
  # is last rather than mid-signature.
  expect_identical(
    names(formals(nested_resamples)),
    c("data", "outside", "inside", "...")
  )
})

# AC2 -------------------------------------------------------------------

# The entry points are checked one at a time rather than in a loop: a loop
# over four names would report "one of them" on a failure, and the point of
# the criterion is that each names its own call.
#
# The two orchestrators no longer fence with `rlang::check_dots_empty()`: their
# `...` admits `control` (M48, AC7), so the refusal is this package's own,
# still at entry and still naming the call. `control` itself passes the fence
# and is judged by `check_control()` instead -- test-nested-tune-grid-checks.R
# and its Bayesian sibling hold that contract.

test_that("AC2: nested_tune_grid() refuses an argument it does not know", {
  cnd <- rlang::catch_cnd(nested_tune_grid(1, 2, nonesuch = 1))
  expect_s3_class(cnd, "nestedtune_bad_dots")
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_tune_grid")
  expect_match(conditionMessage(cnd), "nonesuch")
})

test_that("AC2: nested_tune_bayes() refuses an argument it does not know", {
  cnd <- rlang::catch_cnd(nested_tune_bayes(1, 2, nonesuch = 1))
  expect_s3_class(cnd, "nestedtune_bad_dots")
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_tune_bayes")
  expect_match(conditionMessage(cnd), "nonesuch")
})

test_that("AC2: nested_final_fit() refuses an argument it does not know", {
  cnd <- rlang::catch_cnd(nested_final_fit(1, 2, nonesuch = 1))
  expect_s3_class(cnd, "rlib_error_dots_nonempty")
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_final_fit")
})

test_that("AC2: nested_resamples() refuses an argument it does not know", {
  cnd <- rlang::catch_cnd(nested_resamples(1, 2, 3, nonesuch = 1))
  expect_s3_class(cnd, "rlib_error_dots_nonempty")
  expect_identical(rlang::call_name(conditionCall(cnd)), "nested_resamples")
})

# AC5 -------------------------------------------------------------------

# The domain is read from what the package actually registers, not from a list
# kept here: a tenth method added next year is in the probe the day it is
# registered, and the only way out is to name it as an exemption below.
DOTS_EXEMPT_METHODS <- c(
  "[.nested_results",
  # Its `...` is forwarded to the trained workflow on purpose (M47): parsnip's
  # `check_pred_type_dots()` refuses any name outside its own short list of
  # predict arguments, so an unknown argument is an error downstream rather
  # than a silent no-op (a listed name the model cannot use is parsnip's to
  # ignore, not this package's to fence). `augment.nested_final_fit` stays probed -- workflows' own
  # method swallows its dots, so the fence there is this package's.
  "predict.nested_final_fit",
  # The compatibility methods M37 registers. Their `...` is not this package's
  # to fence: vctrs passes `x_arg`, `y_arg` and `call` through the `...` of a
  # `vec_ptype2()` or `vec_cast()` method, base `rbind()`'s `...` IS the data
  # being combined, and a fence in any of them would abort a call the generic
  # made correctly. `names<-` is exempt for a different reason -- it is a
  # replacement function with no `...` at all, and the probe below cannot call
  # one without a `value` to assign.
  "vec_restore.nested_results",
  "vec_ptype2.nested_results.nested_results",
  "vec_ptype2.nested_results.tbl_df",
  "vec_ptype2.tbl_df.nested_results",
  "vec_ptype2.nested_results.data.frame",
  "vec_ptype2.data.frame.nested_results",
  "vec_cast.nested_results.nested_results",
  "vec_cast.tbl_df.nested_results",
  "vec_cast.data.frame.nested_results",
  "vec_cast.nested_results.tbl_df",
  "vec_cast.nested_results.data.frame",
  "vec_cbind_frame_ptype.nested_results",
  "rbind.nested_results",
  "names<-.nested_results"
)

# Default methods that refuse the object ahead of the dots (M56).
NO_METHOD_DEFAULTS <- c(
  "extract_tune_results.default",
  "extract_scored_candidates.default"
)

# The registry the package's own NAMESPACE writes, read back from the loaded
# namespace: one row per `S3method()` directive, generic and class.
registered_s3_methods <- function() {
  reg <- getNamespaceInfo(asNamespace("nestedtune"), "S3methods")
  sort(paste0(reg[, 1L], ".", reg[, 2L]))
}

test_that("AC5: every registered method whose `...` is unused fences it", {
  methods <- registered_s3_methods()

  # The exemption has to still exist for the subtraction to mean anything --
  # a renamed `[` method would otherwise silently shrink to no exemption at all
  # while this test went on passing.
  expect_true(all(DOTS_EXEMPT_METHODS %in% methods))

  probed <- setdiff(methods, DOTS_EXEMPT_METHODS)
  expect_gt(length(probed), 0L)

  reg <- getNamespaceInfo(asNamespace("nestedtune"), "S3methods")
  for (i in seq_len(nrow(reg))) {
    name <- paste0(reg[[i, 1L]], ".", reg[[i, 2L]])
    if (name %in% DOTS_EXEMPT_METHODS) {
      next
    }
    method <- getS3method(
      reg[[i, 1L]],
      reg[[i, 2L]],
      envir = asNamespace("nestedtune")
    )
    # A bare list stands in for the object. Every fence runs before the method
    # touches `x`, so the stand-in never reaches anything that would care --
    # and an unfenced method reaches its own body and fails some other way,
    # which is the difference the class assertion detects.
    cnd <- rlang::catch_cnd(method(list(), nonesuch = 1))

    # A method whose generic has no `...` -- dplyr_reconstruct(data, template)
    # is the first -- has no barrier to put up and needs none: R refuses the
    # argument at the call itself. Read from the formals rather than from an
    # exemption list, so such a method is classified the day it is registered.
    # Still asserted to refuse, so "no `...`" can never become "accepts it".
    if (!"..." %in% names(formals(method))) {
      expect_s3_class(cnd, "error")
      expect_match(conditionMessage(cnd), "unused argument")
      next
    }
    # The two `extract_` defaults refuse the object before anything else: a
    # caller holding the wrong object is told so whatever rides in `...`
    # (M56), so the stand-in list is refused as having no method, and the
    # stray argument never reaches a fence. Still a refusal, asserted by its
    # own class; the methods on `nested_final_fit` fence their dots and are
    # probed by test-nested-final-fit-extract.R.
    if (name %in% NO_METHOD_DEFAULTS) {
      expect_s3_class(cnd, "nestedtune_no_extract_method")
      next
    }
    expect_s3_class(cnd, "rlib_error_dots_nonempty")
  }
})

# AC6 -------------------------------------------------------------------

test_that("AC6: collect_metrics() puts `summarize` behind the barrier", {
  expect_identical(
    names(formals(getS3method("collect_metrics", "nested_results"))),
    c("x", "...", "summarize")
  )
})

# Every argument text of every `collect_metrics(` call in a file, one string
# per argument. Text, not parsed code, because the corpus includes roxygen
# examples and vignette chunks -- the call sites a parser of `R/` alone would
# walk straight past.
collect_metrics_call_args <- function(path) {
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  starts <- gregexpr("collect_metrics\\(", text, perl = TRUE)[[1]]
  if (identical(as.integer(starts), -1L)) {
    return(list())
  }
  chars <- strsplit(text, "")[[1]]
  out <- list()
  for (s in starts) {
    open <- s + attr(starts, "match.length")[which(starts == s)] - 1L
    depth <- 1L
    args <- character()
    current <- ""
    i <- open + 1L
    while (i <= length(chars) && depth > 0L) {
      ch <- chars[[i]]
      # `[` and `{` count too: `collect_metrics(res[1L, ])` has a comma that
      # belongs to the subscript, and a splitter blind to it reports a second
      # positional argument that was never written.
      if (ch %in% c("(", "[", "{")) {
        depth <- depth + 1L
      }
      if (ch %in% c(")", "]", "}")) {
        depth <- depth - 1L
      }
      if (depth == 0L) {
        break
      }
      if (ch == "," && depth == 1L) {
        args <- c(args, current)
        current <- ""
      } else {
        current <- paste0(current, ch)
      }
      i <- i + 1L
    }
    args <- c(args, current)
    args <- trimws(args)
    out[[length(out) + 1L]] <- args[nzchar(args)]
  }
  out
}

test_that("AC6: no in-repo call passes `summarize` positionally", {
  root <- test_path("..", "..")
  # Under `R CMD check` the suite runs from `<pkg>.Rcheck/tests/testthat`, so
  # `root` is `<pkg>.Rcheck`: `R/` and `vignettes/` are not there and their
  # `list.files()` calls return nothing. The two non-empty guards below are
  # satisfied by `tests/` alone (45 files, 47 calls), so without this the scan
  # would narrow to a third of its domain and still report green -- exactly the
  # silently-empty domain M14 taught. Skipping says so; the same anchor and the
  # same reasoning are in test-vignette-citations.R.
  skip_if_not(
    dir.exists(file.path(root, "R")) &&
      dir.exists(file.path(root, "vignettes")),
    "not the source tree: R/ and vignettes/ are absent, so the scan is partial"
  )
  files <- c(
    list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(
      file.path(root, "tests"),
      pattern = "[.]R$",
      full.names = TRUE,
      recursive = TRUE
    ),
    list.files(
      file.path(root, "vignettes"),
      pattern = "[.]Rmd$",
      full.names = TRUE
    )
  )
  files <- files[file.exists(files)]

  # The scan is worthless if it reads nothing, and a `test_path()` that lands
  # somewhere unexpected reads nothing while passing (M14's lesson).
  expect_gt(length(files), 20L)

  calls <- unlist(lapply(files, collect_metrics_call_args), recursive = FALSE)
  expect_gt(length(calls), 10L)

  positional <- Filter(
    function(args) length(args) > 1L && !any(grepl("=", args[-1L])),
    calls
  )
  expect_identical(
    lapply(positional, paste, collapse = ", "),
    list()
  )
})

test_that("AC6: the positional-argument scan can see a positional argument", {
  # Discrimination: the scan above reports nothing, which is also what a broken
  # scan reports. Planting the defect in a temporary file proves it is the
  # absence of positional calls being reported and not the absence of a scan.
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path), add = TRUE)
  # Assembled rather than written whole, so the scan above -- which reads this
  # file along with every other -- does not find the planted defect here and
  # report it against the repo.
  writeLines(
    c(
      paste0("collect_", "metrics(res, FALSE)"),
      paste0("collect_", "metrics(res, summarize = FALSE)")
    ),
    path
  )
  calls <- collect_metrics_call_args(path)
  expect_length(calls, 2L)
  positional <- Filter(
    function(args) length(args) > 1L && !any(grepl("=", args[-1L])),
    calls
  )
  expect_length(positional, 1L)
  expect_identical(positional[[1L]], c("res", "FALSE"))
})
