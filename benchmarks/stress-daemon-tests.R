# Try to reproduce the intermittent hang, by running the daemon-using tests
# over and over in the configuration that actually hangs.
#
# M14 T5 / AC5. The hang has been seen three times, always inside
# test_check("nestedtune") on CI, never locally, and never twice on the same
# tree -- a re-run of the identical commit passed in normal time. So there is
# nothing to attach a debugger to and no failing test to write. What is left is
# volume: run the daemon tests enough times that an intermittent wedge has a
# chance to show, and record what happened either way.
#
# **Shape matters, and the first draft got it wrong** (M14 review F2). It ran
# `test_local()` on one file per process: a pkgload-loaded package, and each
# file starting from a clean slate. Neither is how the hang arrives. Under
# `R CMD check` the package is *installed*, which `helper-parallel.R` records as
# a materially different daemon path -- `prime_daemons()` does real work under
# pkgload and is a no-op against an installed copy -- and all the test files run
# in *one* process, so each daemon-using file inherits whatever pool state the
# files before it left. This version installs the package once and then runs all
# three daemon files together in a single process per iteration, against that
# installed copy. That is what AC5 asks for ("a fresh R process per iteration")
# and what `test_check()` does.
#
# Every iteration carries a kill deadline. That deadline is the whole point and
# not a nicety: a true hang never returns, so a harness that merely timed its
# iterations would itself wedge on the first one it was built to catch, and
# write nothing. Killing at the deadline turns the event into a recorded row.
#
# The deadline may be generous without weakening anything -- it separates
# "wedged" from "slow".
#
# An iteration is only ever recorded as clean when the child said so. The child
# writes a `done` sentinel as its last act; an iteration that neither finished
# nor hit the deadline is an ERROR row, not a quiet pass, and the summary counts
# errors separately and exits non-zero on any (M14 review F4 -- a run in which
# every iteration aborted in five seconds previously reported "0 hangs").
#
# This lives in benchmarks/ and is .Rbuildignore'd: it is emphatically not part
# of R CMD check.
#
# Run:  Rscript benchmarks/stress-daemon-tests.R [iterations] [deadline_seconds]
# POSIX only (`ps`).

args <- commandArgs(trailingOnly = TRUE)
iterations <- if (length(args) >= 1L) as.integer(args[[1]]) else 50L
deadline_s <- if (length(args) >= 2L) as.numeric(args[[2]]) else 600

# One regex covering the three daemon-using files, run together in one process.
filter <- "parallel-(identity|classify|detection)"

# The floor an iteration must clear to count as having tested anything. The
# three files together assert far more than this; the number only has to be
# high enough that a run which skipped everything cannot clear it.
MIN_PASSES <- 50L

# Run from the repo root; `Rscript` sets no path to the script being run that
# is reachable here, and guessing one silently stresses the wrong tree.
repo <- normalizePath(getwd())
if (!dir.exists(file.path(repo, "tests", "testthat"))) {
  stop("run this from the repository root: no tests/testthat under ", repo)
}

alive <- function(pid) {
  identical(system2("ps", c("-p", pid), stdout = FALSE, stderr = FALSE), 0L)
}

# Wait for a file to exist AND have content. `cat(x, file = f)` creates f before
# it writes to it, so polling on existence alone can read an empty file and take
# `character(0)` for a pid -- which then makes `alive()` FALSE and abandons a
# live child unmonitored (M14 review F3/F7).
wait_for_content <- function(path, seconds) {
  limit <- Sys.time() + seconds
  while (Sys.time() < limit) {
    if (file.exists(path) && file.size(path) > 0L) {
      return(TRUE)
    }
    Sys.sleep(0.05)
  }
  FALSE
}

# Install the package once, into a library the children will use. The daemons
# load nestedtune out of a library like any other R process, so this is also
# what makes them run the code under test rather than a stale installed copy.
lib <- tempfile("stress-lib-")
dir.create(lib)
cat("installing the package into", lib, "...\n")
install_status <- system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "--no-multiarch", "-l", shQuote(lib), shQuote(repo)),
  stdout = FALSE,
  stderr = FALSE
)
if (!identical(install_status, 0L)) {
  stop("R CMD INSTALL failed (status ", install_status, "); nothing to stress")
}

# Run every daemon-using test file once, in one fresh process, against the
# installed package. Returns elapsed seconds and one of "ok" / "HANG" / "ERROR".
run_bounded <- function(seconds) {
  pidfile <- tempfile("stress-pid-")
  donefile <- tempfile("stress-done-")
  logfile <- tempfile("stress-log-")
  expr <- sprintf(
    paste0(
      '.libPaths(c("%s", .libPaths())); ',
      'cat(Sys.getpid(), "\\n", file = "%s"); ',
      'res <- testthat::test_dir("tests/testthat", filter = "%s", ',
      'package = "nestedtune", load_package = "installed", ',
      'reporter = "summary", stop_on_failure = FALSE); ',
      'df <- as.data.frame(res); ',
      'cat(sum(df$passed), sum(df$skipped), sum(df$failed), "\\n", file = "%s")'
    ),
    lib,
    pidfile,
    filter,
    donefile
  )
  started <- Sys.time()
  system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote(expr)),
    # NOT_CRAN is what `skip_on_cran()` reads, and every daemon test is gated on
    # it. Without it a bare Rscript skips all of them and the iteration finishes
    # clean in three seconds having tested nothing -- which is how the first
    # draft of this harness "passed" (M14 review F4, found by running it).
    env = "NOT_CRAN=true",
    wait = FALSE,
    stdout = logfile,
    stderr = logfile
  )

  if (!wait_for_content(pidfile, 60)) {
    return(list(
      elapsed = as.numeric(difftime(Sys.time(), started, units = "secs")),
      status = "ERROR",
      log = logfile,
      why = "child never wrote its pid"
    ))
  }
  pid <- as.integer(readLines(pidfile, n = 1L, warn = FALSE))

  limit <- started + seconds
  while (alive(pid) && Sys.time() < limit) {
    Sys.sleep(0.25)
  }
  killed <- alive(pid)
  if (killed) {
    tools::pskill(pid)
    Sys.sleep(0.5)
    if (alive(pid)) tools::pskill(pid, tools::SIGKILL)
  }
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  finished <- file.exists(donefile) && file.size(donefile) > 0L
  counts <- if (finished) {
    as.integer(strsplit(
      trimws(readLines(donefile, n = 1L, warn = FALSE)),
      " +"
    )[[1]])
  } else {
    c(NA_integer_, NA_integer_, NA_integer_)
  }
  unlink(c(pidfile, donefile))

  # Finishing is not the same as having tested anything: every daemon test is
  # behind `skip_on_cran()`, so a run with the wrong environment completes in
  # seconds with everything skipped. An iteration that asserted nothing is an
  # ERROR, never a clean row.
  status <- if (killed) {
    "HANG"
  } else if (!finished) {
    "ERROR"
  } else if (is.na(counts[[1]]) || counts[[1]] < MIN_PASSES) {
    "ERROR"
  } else {
    "ok"
  }
  why <- if (!finished) {
    "child exited without finishing"
  } else if (identical(status, "ERROR")) {
    sprintf(
      "only %s passing assertions (need >= %d); skipped %s",
      counts[[1]],
      MIN_PASSES,
      counts[[2]]
    )
  } else {
    ""
  }
  list(
    elapsed = elapsed,
    status = status,
    log = logfile,
    why = why,
    passed = counts[[1]],
    skipped = counts[[2]],
    failed = counts[[3]]
  )
}

cat(
  "stress-daemon-tests --",
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS0", tz = "UTC"),
  "\n"
)
cat("repo:", repo, "\n")
cat("iterations:", iterations, " deadline:", deadline_s, "s\n")
cat(
  "shape: all of",
  filter,
  "in ONE process per iteration, installed package\n"
)
cat(
  "mirai:",
  as.character(packageVersion("mirai")),
  " nanonext:",
  as.character(packageVersion("nanonext")),
  " R:",
  as.character(getRversion()),
  "\n"
)
cat("platform:", R.version$platform, "\n\n")
cat(sprintf(
  "%-5s %10s %8s %7s %7s\n",
  "iter",
  "elapsed_s",
  "status",
  "passed",
  "skipped"
))

rows <- list()
for (i in seq_len(iterations)) {
  res <- run_bounded(deadline_s)
  cat(sprintf(
    "%-5d %10.1f %8s %7s %7s\n",
    i,
    res$elapsed,
    res$status,
    res$passed,
    res$skipped
  ))
  flush(stdout())
  if (!identical(res$status, "ok")) {
    cat("  --- ", res$status, ": ", res$why, "; last output ---\n", sep = "")
    cat(
      paste0("  ", utils::tail(readLines(res$log, warn = FALSE), 30)),
      sep = "\n"
    )
    cat("  ------------------------------------------\n")
    flush(stdout())
  }
  unlink(res$log)
  rows[[length(rows) + 1L]] <- data.frame(
    iteration = i,
    elapsed = res$elapsed,
    status = res$status,
    passed = res$passed,
    skipped = res$skipped,
    failed = res$failed
  )
}

ledger <- do.call(rbind, rows)
ok <- ledger[ledger$status == "ok", ]
hangs <- sum(ledger$status == "HANG")
errors <- sum(ledger$status == "ERROR")

cat("\n--- summary ---\n")
if (nrow(ok) > 0L) {
  cat(sprintf(
    "completed  n=%d median=%.1fs min=%.1fs max=%.1fs (%d assertions each)\n",
    nrow(ok),
    stats::median(ok$elapsed),
    min(ok$elapsed),
    max(ok$elapsed),
    stats::median(ok$passed)
  ))
} else {
  cat("completed  n=0 -- NOTHING RAN TO COMPLETION\n")
}
cat("hangs:", hangs, " errors:", errors, " of", nrow(ledger), "iterations\n")
unlink(lib, recursive = TRUE)

# A run where nothing completed is not a clean run. Exit non-zero so a CI job
# cannot go green on a hunt that never happened.
if (hangs > 0L || errors > 0L || nrow(ok) == 0L) {
  quit(status = 1L)
}
