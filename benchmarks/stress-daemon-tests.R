# Try to reproduce the intermittent hang, by running the daemon-using test
# files over and over in fresh processes.
#
# M14 T5 / AC5. The hang has been seen three times, always inside
# test_check("nestedtune") on CI, never locally, and never twice on the same
# tree -- a re-run of the identical commit passed in normal time. So there is
# nothing to attach a debugger to and no failing test to write. What is left is
# volume: run the three files that touch daemons enough times that an
# intermittent wedge has a chance to show, and record what happened either way.
#
# Every iteration runs in its own R process and carries a kill deadline. That
# deadline is the whole point and not a nicety: a true hang never returns, so a
# harness that merely times its iterations would itself wedge on the first one
# it was built to catch, and write nothing. Killing at the deadline turns the
# event into a recorded row.
#
# The deadline may be generous without weakening anything -- it separates
# "wedged" from "slow", and the slowest of these files is 40.5 s.
#
# This lives in benchmarks/ and is .Rbuildignore'd: it is emphatically not part
# of R CMD check, where 50 iterations of three files would blow the 20-minute
# job cap many times over.
#
# Run:  Rscript benchmarks/stress-daemon-tests.R [iterations] [deadline_seconds]
# POSIX only (`ps`).

args <- commandArgs(trailingOnly = TRUE)
iterations <- if (length(args) >= 1L) as.integer(args[[1]]) else 50L
deadline_s <- if (length(args) >= 2L) as.numeric(args[[2]]) else 300

files <- c("parallel-identity", "parallel-classify", "parallel-detection")

# Run from the repo root; `Rscript` sets no path to the script being run that
# is reachable here, and guessing one silently stresses the wrong tree.
repo <- normalizePath(getwd())
if (!dir.exists(file.path(repo, "tests", "testthat"))) {
  stop("run this from the repository root: no tests/testthat under ", repo)
}

alive <- function(pid) {
  identical(system2("ps", c("-p", pid), stdout = FALSE, stderr = FALSE), 0L)
}

# Run one test file in a fresh R process, bounded. Returns the elapsed seconds
# and whether the deadline killed it.
run_bounded <- function(pattern, seconds) {
  pidfile <- tempfile("stress-pid-")
  logfile <- tempfile("stress-log-")
  expr <- sprintf(
    'cat(Sys.getpid(), file = "%s"); testthat::test_local(filter = "%s", reporter = "summary")',
    pidfile, pattern
  )
  started <- Sys.time()
  system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote(expr)),
    wait = FALSE, stdout = logfile, stderr = logfile
  )

  boot <- Sys.time() + 30
  while (!file.exists(pidfile) && Sys.time() < boot) Sys.sleep(0.05)
  if (!file.exists(pidfile)) {
    return(list(elapsed = NA_real_, killed = NA, log = logfile))
  }
  pid <- as.integer(readLines(pidfile, n = 1L, warn = FALSE))

  limit <- started + seconds
  while (alive(pid) && Sys.time() < limit) Sys.sleep(0.25)
  killed <- alive(pid)
  if (killed) {
    tools::pskill(pid)
    Sys.sleep(0.5)
    if (alive(pid)) tools::pskill(pid, tools::SIGKILL)
  }
  unlink(pidfile)
  list(
    elapsed = as.numeric(difftime(Sys.time(), started, units = "secs")),
    killed = killed,
    log = logfile
  )
}

setwd(repo)
cat("stress-daemon-tests --", format(Sys.time(), "%Y-%m-%dT%H:%M:%OS0", tz = "UTC"), "\n")
cat("repo:", repo, "\n")
cat("iterations:", iterations, " deadline:", deadline_s, "s\n")
cat("mirai:", as.character(packageVersion("mirai")),
    " nanonext:", as.character(packageVersion("nanonext")),
    " R:", as.character(getRversion()), "\n")
cat("platform:", R.version$platform, "\n\n")
cat(sprintf("%-5s %-20s %10s %8s\n", "iter", "file", "elapsed_s", "killed"))

rows <- list()
for (i in seq_len(iterations)) {
  for (pattern in files) {
    res <- run_bounded(pattern, deadline_s)
    cat(sprintf("%-5d %-20s %10.1f %8s\n", i, pattern, res$elapsed,
                if (isTRUE(res$killed)) "HANG" else "no"))
    flush(stdout())
    if (isTRUE(res$killed)) {
      cat("  --- killed at the deadline; last output ---\n")
      cat(paste0("  ", utils::tail(readLines(res$log, warn = FALSE), 30)),
          sep = "\n")
      cat("  ------------------------------------------\n")
    }
    unlink(res$log)
    rows[[length(rows) + 1L]] <- data.frame(
      iteration = i, file = pattern, elapsed = res$elapsed,
      killed = isTRUE(res$killed)
    )
  }
}

ledger <- do.call(rbind, rows)
cat("\n--- summary ---\n")
for (pattern in files) {
  sub <- ledger[ledger$file == pattern & !is.na(ledger$elapsed), ]
  cat(sprintf("%-20s n=%d median=%.1fs max=%.1fs hangs=%d\n", pattern, nrow(sub),
              stats::median(sub$elapsed), max(sub$elapsed), sum(sub$killed)))
}
cat("total hangs:", sum(ledger$killed), "of", nrow(ledger), "runs\n")
