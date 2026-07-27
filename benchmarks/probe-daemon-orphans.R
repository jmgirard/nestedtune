# Does a hand-spawned mirai daemon outlive the host that spawned it?
#
# M14 T3 / AC3. `start_mixed_daemons()` (tests/testthat/helper-parallel.R) is
# the only fixture in the suite that starts daemons by hand rather than through
# `mirai::daemons(n)`: the two daemons have to differ in what they can load, and
# `daemons(n)` launches them all alike. It spawns them with
# `system2(..., wait = FALSE)`, which returns an exit status and not a pid, so
# nothing in the suite knows what it started, and the caller's
# `on.exit(mirai::daemons(0))` tears down the host listener only.
#
# That reads like a leak, and the coverage runner on the 2026-07-27 hang did
# report terminating a stray `R` on cleanup. But it is not established, and the
# defaults argue the other way: `mirai::daemon()` takes `asyncdial = FALSE`, so
# one that cannot dial errors out immediately, and `autoexit = TRUE`, so one
# that loses its host exits on its own. If both hold, the fixture needs no
# change and an assertion added on the assumption would pass while proving
# nothing.
#
# So this measures it, over the failure path the fixture actually takes: the
# pool never reaches two connections and `test-parallel-detection.R:75` skips
# out, leaving whatever was spawned behind. Each spawned daemon records its own
# pid before dialling, which the fixture does not do -- the point here is to
# learn the answer, not to mirror the fixture's blindness.
#
# Run: Rscript benchmarks/probe-daemon-orphans.R
# POSIX only (`ps`); the fixture it probes is already skip_on_os("windows").

stopifnot(requireNamespace("mirai", quietly = TRUE))

ledger <- tempfile("orphan-probe-")
dir.create(ledger)

alive <- function(pid) {
  identical(system2("ps", c("-p", pid), stdout = FALSE, stderr = FALSE), 0L)
}

recorded_pids <- function() {
  files <- list.files(ledger, full.names = TRUE)
  as.integer(vapply(files, readLines, character(1), n = 1L, USE.NAMES = FALSE))
}

spawn <- function(tag, env) {
  expr <- sprintf(
    'cat(Sys.getpid(), "\\n", file = "%s"); mirai::daemon("%s")',
    file.path(ledger, tag), url
  )
  system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote(expr)),
    env = env, wait = FALSE, stdout = FALSE, stderr = FALSE
  )
}

# The host, exactly as start_mixed_daemons() raises it.
mirai::daemons(0)
mirai::daemons(n = 0, url = "tcp://127.0.0.1:0", dispatcher = TRUE)
url <- mirai::status()$daemons
cat("host url:", url, "\n")

# One daemon with the full library, one with a library so lean it cannot load
# much -- the pair the fixture builds. The lean one here is deliberately given
# a directory with nothing in it at all, which is the shape RR03 warned about
# and the one most likely to die or wedge at startup.
lean <- tempfile("empty-lib-")
dir.create(lean)
spawn("full", character(0))
spawn("lean", sprintf(c("R_LIBS=%s", "R_LIBS_SITE=%s", "R_LIBS_USER=%s"), lean))

# Let them boot far enough to have written their pids, then read the pool the
# way the fixture does.
deadline <- Sys.time() + 20
while (length(recorded_pids()) < 2L && Sys.time() < deadline) Sys.sleep(0.1)
pids <- recorded_pids()
cat("spawned pids:", paste(pids, collapse = ", "), "\n")
cat("connections reached:", mirai::status()$connections, "\n")

# The failure path: the caller gives up and tears down the host listener. This
# is all the fixture's caller does.
mirai::daemons(0)
cat("host torn down\n")

# Give autoexit its chance before judging.
deadline <- Sys.time() + 15
while (any(vapply(pids, alive, logical(1))) && Sys.time() < deadline) Sys.sleep(0.25)

survivors <- pids[vapply(pids, alive, logical(1))]
cat("\n--- result ---\n")
cat("mirai:", as.character(packageVersion("mirai")), "\n")
cat("nanonext:", as.character(packageVersion("nanonext")), "\n")
cat("survivors after teardown:", if (length(survivors)) paste(survivors, collapse = ", ") else "none", "\n")
cat("verdict:", if (length(survivors)) "ORPHANS -- the fixture must record and kill its pids" else "no orphan -- autoexit reaps them, fixture unchanged", "\n")

for (pid in survivors) tools::pskill(pid)
unlink(c(ledger, lean), recursive = TRUE)
