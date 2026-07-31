# Hygiene checks on the test suite's own source.
#
# One rule, and it exists because breaking it costs twenty minutes of silence
# rather than a red test: every wait on a mirai result in this suite goes
# through `collect_bounded()` (helper-parallel.R), which polls to a deadline and
# then reads `$data`. Everything else mirai offers for getting a value out
# blocks until it resolves and cannot be interrupted from R at all --
# `setTimeLimit(elapsed=)` does not fire inside any of them, established by
# execution while planning M14.
#
# Three shapes are matched, and the list is the enumeration this check is only
# as good as (M14 review F1, which found the first draft matched one of them):
#   * `collect_mirai(x)` -- collects a whole map.
#   * `call_mirai(x)` -- mirai's canonical blocking wait; `x[]` is sugar for it.
#   * a `[` collect, empty (`mirai(...)[]`, `map[]`) or carrying one of mirai's
#     collect options (`map[.flat]`, `map[.progress]`, `map[.stop]`), which
#     block just as hard as the empty form.
#
# Checked over parse tokens rather than by grepping text, so a `[]` inside a
# string and the several comments that discuss `map[]` and `collect_mirai()` by
# name are not findings. A comment describing the trap is the opposite of the
# trap.

# mirai's collect options, as of 2.7.2. A new one added upstream is invisible
# to this check until it is named here -- which is the honest limit of an
# allowlist, and preferable to flagging every `x[.anything]` in the suite.
MIRAI_COLLECT_OPTIONS <- c(".flat", ".progress", ".progress_data", ".stop")

blocking_collect_sites <- function(path) {
  data <- utils::getParseData(parse(path, keep.source = TRUE))
  data <- data[data$token != "COMMENT", , drop = FALSE]
  data <- data[order(data$line1, data$col1), , drop = FALSE]

  named <- data$token == "SYMBOL_FUNCTION_CALL" &
    data$text %in% c("collect_mirai", "call_mirai")

  # A blocking `[` collect is an opening bracket whose next token either closes
  # it immediately or is one of mirai's collect options. `x[[i]]` tokenises as
  # `'[['`, so it cannot reach here, and `df[, 1]` has a `','` next.
  opens <- which(data$token == "'['")
  opens <- opens[opens < nrow(data)]
  nxt_token <- data$token[opens + 1L]
  nxt_text <- data$text[opens + 1L]
  blocking <- opens[
    nxt_token == "']'" | (nxt_token == "SYMBOL" & nxt_text %in% MIRAI_COLLECT_OPTIONS)
  ]

  sort(unique(c(data$line1[named], data$line1[blocking])))
}

# The second rule (M16 T3, AC3): every wait-shaped call in the daemon files is
# accounted for in the time budget. `collect_bounded()` made the waits bounded;
# this makes the SUM of those bounds visible, which is the part that killed a CI
# job -- 1008.7 s of legal waiting in a file that normally takes 12.0 s, against
# a 20-minute cap.
#
# Accounted for is not the same as small. A call that waits for nothing carries a
# 0-second row saying why, and that is the point: adding a new call forces a
# conscious classification instead of letting it hide among the harmless ones.
BUDGETED_WAIT_CALLS <- c(
  "collect_bounded", "daemons_load_status", "setTimeLimit",
  "check_daemons_can_load", "start_daemons", "start_mixed_daemons"
)

BUDGETED_FILES <- c(
  "test-parallel-classify.R", "test-parallel-detection.R",
  "test-parallel-identity.R", "test-parallel-interrupt.R",
  "test-parallel-metrics.R", "test-parallel-payload.R", "helper-parallel.R"
)

wait_call_sites <- function(path) {
  data <- utils::getParseData(parse(path, keep.source = TRUE))
  data <- data[data$token == "SYMBOL_FUNCTION_CALL" &
                 data$text %in% BUDGETED_WAIT_CALLS, , drop = FALSE]
  if (!nrow(data)) return(character(0))
  paste0(basename(path), ":", data$line1)
}

test_that("every wait-shaped call in the daemon files carries a budget row", {
  ledger <- time_budget_ledger()
  budgeted <- paste0(ledger$file, ":", ledger$line)

  found <- unlist(lapply(BUDGETED_FILES, function(f) {
    wait_call_sites(test_path(f))
  }), use.names = FALSE)

  # The check is only as good as its reaching the files at all -- a typo in a
  # name would otherwise pass by finding nothing (M14's "a run that tested
  # nothing reported clean").
  expect_gt(length(found), 20L)

  unbudgeted <- setdiff(found, budgeted)
  expect_identical(
    unbudgeted, character(0),
    info = paste0(
      "wait-shaped call with no row in helper-time-budget.R at: ",
      paste(unbudgeted, collapse = ", "),
      " -- add a row giving its worst-case seconds, or 0 with a note saying ",
      "why it waits for nothing."
    )
  )
})

test_that("the budget ledger has no rows for calls that are gone", {
  # The other direction, which keeps the ledger honest as lines move: a row
  # pointing at a `file:line` that no longer holds a wait call is stale, and a
  # stale row silently excuses the live call that took its place.
  ledger <- time_budget_ledger()
  # Scoped to rows describing an actual call. The ledger may also carry a wait
  # that is not a function call at all -- the `while (... && Sys.time() <
  # deadline)` poll in test-parallel-interrupt.R -- which is real budget but has
  # no token to match, so it is exempt from this direction only.
  ledger <- ledger[ledger$call %in% BUDGETED_WAIT_CALLS, , drop = FALSE]
  budgeted <- paste0(ledger$file, ":", ledger$line)

  found <- unlist(lapply(BUDGETED_FILES, function(f) {
    wait_call_sites(test_path(f))
  }), use.names = FALSE)

  stale <- setdiff(budgeted, found)
  expect_identical(
    stale, character(0),
    info = paste0(
      "budget row pointing at no wait call (line moved or call removed?): ",
      paste(stale, collapse = ", ")
    )
  )
})

# Re-read a bound from the call site itself, in seconds.
#
# A ledger row whose seconds were COPIED from an explicit argument can drift from
# that argument silently -- raising `timeout = 60000` to `600000` would leave both
# accounting guards green and the printed total unchanged, while the real worst
# case grew by nine minutes (M16 review F3). Rows whose bound comes from a named
# constant in helper-parallel.R cannot drift that way and need no check.
#
# NA means the line carries no explicit bound of its own: the option-set-elsewhere
# case and the deadline poll, both named in helper-time-budget.R's header.
call_site_bound_s <- function(path, line) {
  txt <- readLines(path, warn = FALSE)[[line]]
  ms <- regmatches(txt, regexpr("timeout\\s*=\\s*[0-9.]+", txt))
  if (length(ms)) return(as.numeric(sub(".*=\\s*", "", ms)) / 1000)
  sec <- regmatches(txt, regexpr("seconds\\s*=\\s*[0-9.]+", txt))
  if (length(sec)) return(as.numeric(sub(".*=\\s*", "", sec)))
  NA_real_
}

test_that("a copied bound still matches the argument it was copied from", {
  ledger <- time_budget_ledger()
  # Only rows that actually declare a wait, and only the two calls that take an
  # explicit bound. A `check_daemons_can_load()` row carrying a fabricated
  # `preflight_outcome(..., timeout = 300000)` on its line waits for nothing --
  # its number is message content, not budget.
  ledger <- ledger[ledger$call %in% c("daemons_load_status", "collect_bounded") &
                     ledger$seconds > 0, , drop = FALSE]

  checked <- 0L
  for (i in seq_len(nrow(ledger))) {
    at <- call_site_bound_s(test_path(ledger$file[[i]]), ledger$line[[i]])
    if (is.na(at)) next
    checked <- checked + 1L
    expect_equal(
      ledger$seconds[[i]], at * ledger$times[[i]],
      info = paste0(ledger$file[[i]], ":", ledger$line[[i]],
                    " declares ", ledger$seconds[[i]],
                    " s but the call site says ", at * ledger$times[[i]], " s")
    )
  }
  # Without this the test passes by checking nothing the moment the filter or the
  # regex stops matching -- the failure M14's review found in a harness that
  # reported clean having asserted nothing.
  expect_gt(checked, 4L)
})

test_that("the localized file's declared worst case fits the CI budget", {
  # AC4. The number this milestone exists to move: what test-parallel-classify.R
  # is ALLOWED to wait for, which on 2026-07-27 was 1008.7 s against a 1200 s
  # job cap, in a file that typically runs 12.0 s.
  totals <- time_budget_totals()
  classify <- totals$seconds[totals$file == "test-parallel-classify.R"]

  expect_length(classify, 1L)
  expect_lt(classify, CLASSIFY_BUDGET_CEILING_S)
  expect_lte(classify, CLASSIFY_BUDGET_PRE_M16_S / 2)
})

test_that("the metrics-delivery file stays inside its own ceiling", {
  # M20 AC2. The file was born with a ceiling rather than given one later,
  # which is the difference between holding a bound and measuring a regression.
  totals <- time_budget_totals()
  metrics <- totals$seconds[totals$file == "test-parallel-metrics.R"]

  expect_length(metrics, 1L)
  expect_lt(metrics, METRICS_BUDGET_CEILING_S)
})

test_that("no test waits on a mirai result outside collect_bounded()", {
  # Everything under tests/, not just this directory -- AC2 says "under
  # `tests/`", and `tests/testthat.R` is R code that could acquire a wait too.
  # `.r` as well as `.R`, since R does not care about the case. Deliberately
  # NOT the repo root: `R/parallel.R:91` holds the production `collect_mirai()`
  # that M07 put there on purpose, and this rule is about the suite.
  files <- list.files(
    test_path(".."), pattern = "\\.[Rr]$", full.names = TRUE, recursive = TRUE
  )
  files <- files[!grepl("/_snaps/", files)]
  expect_gt(length(files), 0L)

  found <- lapply(files, function(path) {
    lines <- blocking_collect_sites(path)
    if (!length(lines)) NULL else paste0(basename(path), ":", lines)
  })
  found <- unlist(found, use.names = FALSE)

  expect_identical(
    found,
    NULL,
    info = paste0(
      "blocking mirai collect outside collect_bounded() at: ",
      paste(found, collapse = ", ")
    )
  )
})
