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
