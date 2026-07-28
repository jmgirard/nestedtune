# The trace reporter says which test, not just which file (M16 T1, AC1).
#
# M14 shipped file-level markers on the recorded belief that testthat exposes no
# per-test hook. PR #13's hang then named `test-parallel-classify.R` and left 30
# blocks to choose between, which is the cost this file exists to remove. So the
# assertion that matters is not that lines appear -- it is that a per-TEST start
# and end appear, carrying the block's own description.

fixture_two_blocks <- function() {
  dir <- tempfile("hang-trace-fixture-")
  dir.create(dir)
  path <- file.path(dir, "test-trace-fixture.R")
  writeLines(
    c(
      'test_that("alpha block", { expect_true(TRUE) })',
      'test_that("beta block", { expect_equal(1, 1) })'
    ),
    path
  )
  path
}

# Run a file through a reporter and return what reached stderr().
#
# type = "message" is what captures stderr; the reporter writes there on
# purpose, because it is unbuffered and survives the kill that loses the check
# reporter's own output.
trace_lines <- function(path, reporter = HangTraceReporter$new()) {
  capture.output(
    testthat::test_file(path, reporter = reporter),
    type = "message"
  )
}

test_that("every test_that() block gets a paired, named start and end line", {
  out <- trace_lines(fixture_two_blocks())

  for (block in c("alpha block", "beta block")) {
    starts <- grep(paste0("start .*:: ", block, "$"), out)
    ends <- grep(paste0("end +.*:: ", block, "$"), out)
    expect_length(starts, 1L)
    expect_length(ends, 1L)
    # Paired and ordered: a start that never closes is the signal the whole
    # mechanism exists to produce, so an end preceding its start would make an
    # unmatched trailing `start` unreadable.
    expect_lt(starts, ends)
  }
})

test_that("the per-file lines M14 ships still bracket the per-test ones", {
  out <- trace_lines(fixture_two_blocks())

  # The file marker is the bare filename with no ` :: `; the test markers carry
  # one. Asserting the bracket rather than a count keeps this from breaking on
  # an added block in the fixture.
  file_start <- grep("start .*test-trace-fixture\\.R$", out)
  file_end <- grep("end +.*test-trace-fixture\\.R$", out)
  test_lines <- grep(" :: ", out)

  expect_length(file_start, 1L)
  expect_length(file_end, 1L)
  expect_true(all(test_lines > file_start & test_lines < file_end))
})

test_that("a block that never ends leaves an unmatched start", {
  # The failure shape itself, since a green pairing test cannot show it: with
  # the `end` line suppressed, the surviving log ends on the start of the block
  # that did not finish -- exactly what a killed job leaves behind and what a
  # reader is meant to act on.
  #
  # Subclassed rather than patched: R6 members are locked, so assigning over
  # `end_test` on a stock instance raises "cannot change value of locked
  # binding" (D-021 established this for `start_file`).
  WedgedReporter <- R6::R6Class(
    "WedgedReporter",
    inherit = HangTraceReporter,
    public = list(end_test = function(context, test) invisible(NULL))
  )

  out <- trace_lines(fixture_two_blocks(), reporter = WedgedReporter$new())

  per_test <- grep(" :: ", out, value = TRUE)
  expect_length(per_test, 2L)
  expect_true(all(grepl("start", per_test)))
})
