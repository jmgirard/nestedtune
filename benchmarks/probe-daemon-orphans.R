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

# Only files that have actually been written. `cat(x, file = f)` creates f
# before writing it, so a bare readLines() over every file can hit an empty one
# -- and since this is a `while` condition, a vapply length error there kills
# the probe outright rather than retrying (M14 review F7).
recorded_pids <- function() {
  files <- list.files(ledger, full.names = TRUE)
  files <- files[file.size(files) > 0L]
  if (!length(files)) return(integer(0))
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
# much -- the pair the fixture builds.
#
# The lean one must be the fixture's lean, not an empty directory. `lean_library()`
# (tests/testthat/helper-parallel.R) deliberately keeps `mirai` and `nanonext`,
# for the reason RR03 named and M07 paid 39 minutes of `R CMD check` for: strip
# a daemon's library outright and it cannot load *mirai* either, so it dies
# before it dials and never joins the pool. A daemon that never connected is
# not evidence about whether a connected one is reaped, and the first draft of
# this probe measured exactly that (M14 review F5).
lean <- tempfile("lean-lib-")
dir.create(lean)
for (pkg in c("mirai", "nanonext")) {
  src <- system.file(package = pkg)
  if (nzchar(src)) file.symlink(src, file.path(lean, pkg))
}
spawn("full", character(0))
spawn("lean", sprintf(c("R_LIBS=%s", "R_LIBS_SITE=%s", "R_LIBS_USER=%s"), lean))

# Let them boot far enough to have written their pids AND dialled in. The
# fixture's own gate is two connections (test-parallel-detection.R skips below
# it), so that is the state this probe has to reach before its answer means
# anything.
deadline <- Sys.time() + 30
while ((length(recorded_pids()) < 2L ||
        mirai::status()$connections < 2L) && Sys.time() < deadline) {
  Sys.sleep(0.1)
}
pids <- recorded_pids()
connections <- mirai::status()$connections
cat("spawned pids:", paste(pids, collapse = ", "), "\n")
cat("connections reached:", connections, "\n")

# The failure path: the caller gives up and tears down the host listener. This
# is all the fixture's caller does.
mirai::daemons(0)
cat("host torn down\n")

# Give autoexit its chance before judging.
deadline <- Sys.time() + 15
still_alive <- function() pids[vapply(pids, alive, logical(1))]
while (length(still_alive()) && Sys.time() < deadline) Sys.sleep(0.25)

survivors <- still_alive()
cat("\n--- result ---\n")
cat("mirai:", as.character(packageVersion("mirai")), "\n")
cat("nanonext:", as.character(packageVersion("nanonext")), "\n")
cat("daemons spawned:", length(pids), " connections reached:", connections, "\n")
cat("survivors after teardown:",
    if (length(survivors)) paste(survivors, collapse = ", ") else "none", "\n")

# The verdict is gated on having actually measured what it claims to measure.
# `any(logical(0))` is FALSE, so an unguarded version prints "no orphan" just as
# confidently when both spawns failed and there was nothing to reap at all
# (M14 review F5).
cat("verdict: ", sep = "")
if (length(pids) < 2L || connections < 2L) {
  cat("INCONCLUSIVE -- needed 2 spawned daemons and 2 connections, got ",
      length(pids), " and ", connections,
      ". A daemon that never joined the pool says nothing about whether a ",
      "connected one is reaped; re-run, and check the lean library really ",
      "carries mirai and nanonext.\n", sep = "")
} else if (length(survivors)) {
  cat("ORPHANS -- the fixture must record and kill its pids\n")
} else {
  cat("no orphan -- autoexit reaps them, fixture unchanged\n")
}

for (pid in survivors) tools::pskill(pid)
unlink(c(ledger, lean), recursive = TRUE)
