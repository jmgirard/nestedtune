# The suite's own files, parsed (M57).
#
# Two tests read the test files as source rather than running them: the
# duplicate-description check in test-hang-trace.R, and the `tibble` skip
# check in test-vctrs-compat.R. Both want the same thing -- every top-level
# `test_that()` call of a file, with its description and its body told apart
# by name rather than by position -- so it is built once here.
#
# One entry per call: `description` is the literal string the call passes
# (`NA` when it is not a literal, which no file does today), `body` the
# unevaluated code block.
test_that_calls <- function(path) {
  exprs <- parse(path, keep.source = FALSE)
  calls <- Filter(
    function(e) is.call(e) && identical(e[[1L]], as.name("test_that")),
    as.list(exprs)
  )
  lapply(calls, function(e) {
    e <- match.call(testthat::test_that, e)
    desc <- e$desc
    list(
      description = if (is.character(desc)) desc else NA_character_,
      body = e$code
    )
  })
}

test_that_descriptions <- function(path) {
  vapply(test_that_calls(path), `[[`, character(1), "description")
}
