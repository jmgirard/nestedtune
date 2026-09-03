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

# Under parallel test files (M52) the reporter runs in the PARENT process:
# each worker forwards its events over a pipe, and testthat replays them into
# whatever reporter `tests/testthat.R` passed. Two consequences, both verified
# by execution at M52's gate rather than read off the docs.
#
# First, the parent has two replay modes, chosen by the reporter's
# `parallel_updates` capability. Without it testthat holds a file's events
# until the file finishes and replays them in one burst, so every line of a
# file carries one timestamp and a file that hangs prints nothing -- not even
# its `start`. With it, events arrive as they happen, which is the only mode in
# which a killed job's log still ends on the unmatched `start` of the block
# that hung. So this reporter declares it.
#
# Second, in that live mode testthat re-announces the file and the test before
# EVERY event it forwards -- `start_file(f)` and `start_test(ctx, t)` precede
# an `add_result`, an `end_test`, and even the file's own `end_file` -- so a
# reporter that printed on each call wrote four to five `start` lines per
# block, and a fresh `start` for a block already ended. The bookkeeping below
# prints a `start` only on first sight of a file or of a block, and an `end`
# only for one currently open; a block once ended stays remembered until its
# file ends, so the re-announcement that precedes `end_file` cannot reopen it.
# In serial mode every event arrives exactly once and the bookkeeping is inert.
HangTraceReporter <- R6::R6Class(
  "HangTraceReporter",
  inherit = Reporter,
  public = list(
    capabilities = list(parallel_support = TRUE, parallel_updates = TRUE),
    current_file = NULL,
    # Targets announced so far, per file: the file's own name plus every
    # `<file> :: <test>` it has started. Cleared when the file ends.
    seen = NULL,
    # Targets whose `start` has printed and whose `end` has not.
    open = NULL,
    initialize = function(...) {
      super$initialize(...)
      self$seen <- new.env(parent = emptyenv())
      self$open <- new.env(parent = emptyenv())
    },
    start_file = function(filename) {
      self$current_file <- filename
      private$announce(hang_trace_target(filename, NULL))
    },
    end_file = function() {
      private$close(hang_trace_target(self$current_file, NULL))
      # Forget the file's blocks so a same-named block in a later file starts
      # afresh; the file name itself is keyed with them.
      targets <- ls(self$seen, all.names = TRUE)
      own <- targets == self$current_file |
        startsWith(targets, paste0(self$current_file, " :: "))
      rm(list = targets[own], envir = self$seen)
      self$current_file <- NULL
    },
    start_test = function(context, test) {
      private$announce(hang_trace_target(self$current_file, test))
    },
    end_test = function(context, test) {
      private$close(hang_trace_target(self$current_file, test))
    }
  ),
  private = list(
    announce = function(target) {
      if (exists(target, envir = self$seen, inherits = FALSE)) {
        return(invisible(FALSE))
      }
      assign(target, TRUE, envir = self$seen)
      assign(target, TRUE, envir = self$open)
      hang_trace_line("start", target)
      invisible(TRUE)
    },
    close = function(target) {
      if (!exists(target, envir = self$open, inherits = FALSE)) {
        return(invisible(FALSE))
      }
      rm(list = target, envir = self$open)
      hang_trace_line("end", target)
      invisible(TRUE)
    }
  )
)

# The reporter `tests/testthat.R` runs the suite under, built here so a test
# can assert its shape -- the runner itself is invisible to every test file.
#
# `CheckReporter$new()`, never `check_reporter()`: the latter returns the
# string "Check" for test_check() to resolve, and MultiReporter needs the
# object. `MultiReporter` declares `parallel_support` for itself whatever its
# members say, but not `parallel_updates`, and testthat reads BOTH off the
# reporter it is handed rather than off the members -- so the live mode the
# trace depends on is declared on the composite, where testthat looks.
# `CheckReporter` keeps no per-file state, so interleaved events from several
# workers cannot confuse it.
check_reporter_with_hang_trace <- function() {
  reporter <- MultiReporter$new(
    reporters = list(CheckReporter$new(), HangTraceReporter$new())
  )
  reporter$capabilities$parallel_updates <- TRUE
  reporter
}
