# The trace reporter says which test, not just which file (M16 T1, AC1).
#
# M14 shipped file-level markers on the recorded belief that testthat exposes no
# per-test hook. PR #13's hang then named `test-parallel-classify.R` and left 30
# blocks to choose between, which is the cost this file exists to remove. So the
# assertion that matters is not that lines appear -- it is that a per-TEST start
# and end appear, carrying the block's own description.

# The directory is removed when the CALLER's frame exits (M57): the fixture
# hands its path back, so it cannot clean up on its own exit, and every caller
# is a `test_that()` block whose frame is the right lifetime.
fixture_two_blocks <- function(frame = parent.frame()) {
  dir <- tempfile("hang-trace-fixture-")
  dir.create(dir)
  do.call(
    on.exit,
    list(
      substitute(unlink(dir, recursive = TRUE), list(dir = dir)),
      add = TRUE
    ),
    envir = frame
  )
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

test_that("a file's end forgets its unended blocks as well as its ended ones", {
  # M52's review: `end_file()` cleared `seen` and left `open` alone, so a
  # block whose `end` never came stayed open after its file was over. The
  # same wedged reporter as above, inspected rather than read off its lines.
  WedgedReporter <- R6::R6Class(
    "WedgedReporter",
    inherit = HangTraceReporter,
    public = list(end_test = function(context, test) invisible(NULL))
  )
  reporter <- WedgedReporter$new()
  path <- fixture_two_blocks()
  trace_lines(path, reporter = reporter)

  # Both blocks were opened and neither was closed, which is the precondition:
  # without it an empty `open` would prove nothing.
  out <- grep(
    " :: ",
    trace_lines(path, reporter = HangTraceReporter$new()),
    value = TRUE
  )
  expect_length(out, 4L)

  own <- function(record) {
    targets <- ls(record, all.names = TRUE)
    targets[startsWith(targets, basename(path))]
  }
  expect_identical(own(reporter$open), character())
  expect_identical(own(reporter$seen), character())
})

test_that("the two-block fixture's directory is gone once its caller returns", {
  caller <- function() {
    path <- fixture_two_blocks()
    expect_true(file.exists(path))
    dirname(path)
  }
  dir <- caller()
  expect_false(dir.exists(dir))
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
trace_lines_parallel <- function(
  reporter = check_reporter_with_hang_trace(),
  dir = tempfile("hang-trace-parallel-")
) {
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
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
  dir <- tempfile("hang-trace-parallel-")
  out <- grep(
    "^\\[hang-trace\\]",
    trace_lines_parallel(dir = dir),
    value = TRUE
  )
  # The fixture directory is the helper's to remove (M57), asserted on this
  # run rather than on a second one.
  expect_false(dir.exists(dir))

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

# --- Duplicate descriptions (M57) --------------------------------------------
#
# The trace keys a block by `<file> :: <description>`, so two blocks in one file
# sharing a description share one key: the second never prints a `start`, and
# the first `end` closes both. A hang in the second block would then be read
# as a hang in the first. M52's review weighed an occurrence counter in the
# reporter and chose this instead: the suite simply has no such pair, and the
# scan below is what keeps it so.

# Every `<file> :: <description>` that a second block in the same file repeats.
duplicated_descriptions <- function(dir) {
  files <- list.files(dir, pattern = "^test-.*[.]R$")
  unlist(lapply(files, function(file) {
    desc <- test_that_descriptions(file.path(dir, file))
    dup <- unique(desc[!is.na(desc) & duplicated(desc)])
    # `paste()` on an empty vector would answer with a bare `<file> :: `.
    if (length(dup) == 0L) {
      return(character())
    }
    paste(file, "::", dup)
  }))
}

test_that("no two test_that() blocks in one file share a description", {
  dir <- test_path(".")
  files <- list.files(dir, pattern = "^test-.*[.]R$")
  # The scan is worthless over an empty directory, and one that reads no
  # block at all is the same failure one level down.
  expect_gt(length(files), 0L)
  expect_gt(
    length(unlist(lapply(file.path(dir, files), test_that_descriptions))),
    0L
  )

  expect_identical(duplicated_descriptions(dir), character())
})

test_that("the duplicate-description scan reports a planted duplicate", {
  dir <- tempfile("hang-trace-duplicates-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(
    c(
      'test_that("twice", { expect_true(TRUE) })',
      'test_that("once", { expect_true(TRUE) })',
      'test_that("twice", { expect_true(TRUE) })'
    ),
    file.path(dir, "test-planted.R")
  )
  writeLines(
    'test_that("twice", { expect_true(TRUE) })',
    file.path(dir, "test-clean.R")
  )

  # Named, not counted: the same description in a different file is a
  # different key and must not be reported.
  expect_identical(duplicated_descriptions(dir), "test-planted.R :: twice")
})
