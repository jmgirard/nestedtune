library(testthat)
library(nestedtune)

# Where a hang stopped.
#
# The check reporter buffers its output, so a job killed inside test_check()
# leaves a testthat.Rout naming no test file at all. That is not hypothetical:
# on 2026-07-27 two CI jobs hung inside this call for 52 and 40 minutes and a
# third was killed at the 20-minute cap, and the surviving log from the third
# held the R banner, this call, and nothing else that located it.
#
# stderr() is unbuffered and lands in testthat.Rout under R CMD check -- it is
# how the fold-failure notes emitted by the code under test survived that same
# kill when the reporter's own output did not. So the marker goes there, and is
# flushed besides.
#
# Scope, stated because the absence is easy to misread: testthat calls
# start_file() for test files only. Helper, setup and teardown files get no
# marker, and helper-parallel.R's daemon fixtures live in one of them. A hang
# there shows up as a `start` line that never arrives rather than as one that
# never closes, which is still enough to tell the two cases apart.
hang_trace_line <- function(event, filename) {
  cat(
    sprintf(
      "[hang-trace] %s %-5s %s\n",
      format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"), event, filename
    ),
    file = stderr()
  )
  flush(stderr())
}

HangTraceReporter <- R6::R6Class(
  "HangTraceReporter",
  inherit = Reporter,
  public = list(
    current_file = NULL,
    start_file = function(filename) {
      self$current_file <- filename
      hang_trace_line("start", filename)
    },
    end_file = function() {
      file <- self$current_file
      hang_trace_line("end", if (is.null(file)) "<unknown>" else file)
      self$current_file <- NULL
    }
  )
)

test_check(
  "nestedtune",
  # CheckReporter$new(), never check_reporter(): the latter returns the string
  # "Check" for test_check() to resolve, and MultiReporter needs the object.
  reporter = MultiReporter$new(
    reporters = list(CheckReporter$new(), HangTraceReporter$new())
  )
)
