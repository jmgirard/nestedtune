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

# --- Parallel test files (M52) ----------------------------------------------
#
# With `Config/testthat/parallel: true` the reporter runs in the parent and
# testthat forwards each worker's events to it. Which way it forwards them is
# the reporter's choice, and the choice is the whole difference between a log
# that names the block a killed job died in and one that names nothing: without
# live updates a file's events are replayed in one burst when the file
# finishes, so a file that hangs prints no line at all. So the assertions here
# are on the mode, not merely on the lines.

# A fixture directory of two files, one holding a block that sleeps, run under
# the runner's own composite reporter with two workers. `package = "testthat"`
# because a worker must `library()` something and the fixture is not a
# package; nothing else about the run depends on which package that is.
trace_lines_parallel <- function(reporter = check_reporter_with_hang_trace()) {
  dir <- tempfile("hang-trace-parallel-")
  dir.create(dir)
  writeLines(
    c(
      'test_that("sleeping block", { Sys.sleep(0.5); expect_true(TRUE) })',
      'test_that("quick block", { expect_equal(1, 1) })'
    ),
    file.path(dir, "test-sleeper.R")
  )
  writeLines(
    'test_that("other block", { expect_true(TRUE) })',
    file.path(dir, "test-other.R")
  )
  # Base R rather than withr, which is not a dependency of this package: the
  # variables are forced on so the fixture runs parallel whatever the caller's
  # environment says, and restored on exit so nothing leaks into the next file.
  old <- Sys.getenv(c("TESTTHAT_PARALLEL", "TESTTHAT_CPUS"), unset = NA)
  on.exit(restore_envvar(old), add = TRUE)
  Sys.setenv(TESTTHAT_PARALLEL = "TRUE", TESTTHAT_CPUS = "2")
  capture.output(
    testthat::test_dir(
      dir,
      package = "testthat",
      load_package = "installed",
      reporter = reporter,
      stop_on_failure = FALSE
    ),
    type = "message"
  )
}

restore_envvar <- function(old) {
  for (name in names(old)) {
    if (is.na(old[[name]])) {
      Sys.unsetenv(name)
    } else {
      do.call(Sys.setenv, as.list(stats::setNames(old[[name]], name)))
    }
  }
}

trace_stamp <- function(line) {
  as.POSIXct(
    sub("^\\[hang-trace\\] (\\S+) .*$", "\\1", line),
    format = "%Y-%m-%dT%H:%M:%OS",
    tz = "UTC"
  )
}

test_that("the reporter and the runner's composite both declare live updates", {
  # Both capabilities on the reporter itself, so a bare HangTraceReporter
  # handed to test_dir() runs parallel rather than silently serial.
  caps <- HangTraceReporter$new()$capabilities
  expect_true(caps$parallel_support)
  expect_true(caps$parallel_updates)

  # And on the composite tests/testthat.R hands to test_check(), which is the
  # object testthat actually reads: MultiReporter sets parallel_support on
  # itself and leaves parallel_updates at the base default of FALSE, so the
  # member's declaration alone would leave the suite in burst replay.
  composite <- check_reporter_with_hang_trace()
  expect_true(composite$capabilities$parallel_support)
  expect_true(composite$capabilities$parallel_updates)
  expect_true(any(vapply(
    composite$reporters,
    inherits,
    logical(1),
    what = "HangTraceReporter"
  )))
  expect_true(any(vapply(
    composite$reporters,
    inherits,
    logical(1),
    what = "CheckReporter"
  )))
})

test_that("under parallel files every file and block gets exactly one live pair", {
  out <- grep("^\\[hang-trace\\]", trace_lines_parallel(), value = TRUE)

  # One start and one end per file and per block: live mode re-announces the
  # file and the block before every forwarded event, and without the
  # reporter's bookkeeping each block printed four to five starts.
  for (target in c(
    "test-sleeper\\.R",
    "test-other\\.R",
    "test-sleeper\\.R :: sleeping block",
    "test-sleeper\\.R :: quick block",
    "test-other\\.R :: other block"
  )) {
    starts <- grep(paste0("start ", target, "$"), out)
    ends <- grep(paste0("end +", target, "$"), out)
    expect_length(starts, 1L)
    expect_length(ends, 1L)
    expect_lt(starts, ends)
  }

  # Live, not replayed: the sleeping block's end is stamped after its sleep,
  # where burst replay stamps a file's every line within a millisecond.
  start <- grep("start test-sleeper\\.R :: sleeping block$", out, value = TRUE)
  end <- grep("end +test-sleeper\\.R :: sleeping block$", out, value = TRUE)
  expect_gte(
    as.numeric(trace_stamp(end) - trace_stamp(start), units = "secs"),
    0.4
  )
})
