# Where a hang stopped -- to the test, not just to the file.
#
# The check reporter buffers its output, so a job killed inside test_check()
# leaves a testthat.Rout naming no test file at all. That is not hypothetical:
# on 2026-07-27 two CI jobs hung inside that call for 52 and 40 minutes and a
# third was killed at the 20-minute cap, and the surviving log from the third
# held the R banner, the call, and nothing else that located it.
#
# stderr() is unbuffered and lands in testthat.Rout under R CMD check -- it is
# how the fold-failure notes emitted by the code under test survived that same
# kill when the reporter's own output did not. So the marker goes there, and is
# flushed besides.
#
# M14 traced files only, on the recorded belief that testthat exposes no
# per-test hook a reporter can use. It does: `start_test(context, test)` and
# `end_test(context, test)` fire once per `test_that()` block carrying the
# block's description, verified by execution at M16's plan gate. The file-level
# localization that belief cost is what M16 removes -- PR #13's log named
# test-parallel-classify.R and left 30 blocks to choose between.
#
# This lives in a helper rather than in tests/testthat.R because a test cannot
# see what testthat.R defines: testthat sources helpers, never the runner. The
# runner sources this file so both paths have the class (M16 T1).
#
# Scope, stated because the absence is easy to misread: testthat calls
# start_file() for test files only. Helper, setup and teardown files get no
# marker, and helper-parallel.R's daemon fixtures live in one of them. A hang
# there shows up as a `start` line that never arrives rather than as one that
# never closes, which is still enough to tell the two cases apart.

hang_trace_line <- function(event, target) {
  cat(
    sprintf(
      "[hang-trace] %s %-5s %s\n",
      format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"),
      event,
      target
    ),
    file = stderr()
  )
  flush(stderr())
}

# One grammar for both levels: every `start` has a matching `end`, and the
# target says which level it is -- a bare filename, or `<file> :: <test>`. A
# killed job's last unmatched `start` is therefore the exact block it died in.
hang_trace_target <- function(file, test) {
  if (is.null(file)) {
    file <- "<unknown>"
  }
  if (is.null(test)) {
    return(file)
  }
  paste0(file, " :: ", test)
}

HangTraceReporter <- R6::R6Class(
  "HangTraceReporter",
  inherit = Reporter,
  public = list(
    current_file = NULL,
    start_file = function(filename) {
      self$current_file <- filename
      hang_trace_line("start", hang_trace_target(filename, NULL))
    },
    end_file = function() {
      hang_trace_line("end", hang_trace_target(self$current_file, NULL))
      self$current_file <- NULL
    },
    start_test = function(context, test) {
      hang_trace_line("start", hang_trace_target(self$current_file, test))
    },
    end_test = function(context, test) {
      hang_trace_line("end", hang_trace_target(self$current_file, test))
    }
  )
)
