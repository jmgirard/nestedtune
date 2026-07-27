# Hygiene checks on the test suite's own source.
#
# One rule, and it exists because breaking it costs twenty minutes of silence
# rather than a red test: every wait on a mirai result in this suite goes
# through `collect_bounded()` (helper-parallel.R), which polls to a deadline and
# then reads `$data`. The two idioms that do not are a bare `[` collect --
# `mirai(...)[]`, `map[]` -- and `mirai::collect_mirai()`, both of which block
# until every element resolves and cannot be interrupted from R at all:
# `setTimeLimit(elapsed=)` does not fire inside them, established by execution
# while planning M14.
#
# Checked over parse tokens rather than by grepping text, so a `[]` inside a
# string and the several comments that discuss `map[]` and `collect_mirai()` by
# name are not findings. A comment describing the trap is the opposite of the
# trap.

blocking_collect_sites <- function(path) {
  data <- utils::getParseData(parse(path, keep.source = TRUE))
  data <- data[data$token != "COMMENT", , drop = FALSE]
  data <- data[order(data$line1, data$col1), , drop = FALSE]

  named <- data$token == "SYMBOL_FUNCTION_CALL" & data$text == "collect_mirai"

  # A bare `[` collect is an opening bracket whose very next token closes it.
  # `x[[i]]` tokenises as `'[['`, so it cannot reach here.
  opens <- which(data$token == "'['")
  empty <- opens[opens < nrow(data)][
    data$token[opens[opens < nrow(data)] + 1L] == "']'"
  ]

  sort(unique(c(data$line1[named], data$line1[empty])))
}

test_that("no test waits on a mirai result outside collect_bounded()", {
  files <- list.files(test_path("."), pattern = "\\.R$", full.names = TRUE)
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
