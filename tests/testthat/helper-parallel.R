# Daemon fixtures for the parallel tests.
#
# Daemons are separate R processes and load nestedtune from an installed
# library. Under devtools/pkgload there may be no installed copy at all -- and
# worse, there may be a *stale* one, in which case daemons quietly run old code
# while the host runs the code under test (RR03 Q5). Priming the daemons with
# pkgload closes both holes; under R CMD check the package is installed and the
# daemons inherit the library through the environment, so priming is a no-op.

# Collect a mirai, or a whole mirai_map, with a deadline -- never open-endedly.
#
# A bare `[` collect blocks until every element resolves, so one wedged daemon
# hangs the suite -- the failure AC4 exists to make impossible. Polling to a
# deadline and then reading `$data` (which yields `unresolvedValue` rather than
# waiting) cannot block at all. Same shape as the production probe in
# R/parallel.R, for the same reason.
#
# It takes both shapes because the suite has both, and one bounded idiom is
# what `test-suite-hygiene.R` can check for mechanically: a single mirai reads
# its own `$data`, a map reads one element at a time. `unresolved()` and
# `stop_mirai()` accept either, so only the read differs (M14 T2).
collect_bounded <- function(map, seconds = 60) {
  deadline <- Sys.time() + seconds
  while (mirai::unresolved(map) && Sys.time() < deadline) {
    Sys.sleep(0.05)
  }
  if (mirai::unresolved(map)) {
    mirai::stop_mirai(map)
  }
  if (inherits(map, "mirai")) {
    return(map$data)
  }
  lapply(seq_along(map), function(i) map[[i]]$data)
}

prime_daemons <- function() {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(invisible(FALSE))
  }
  if (!isTRUE(pkgload::is_dev_package("nestedtune"))) {
    return(invisible(FALSE))
  }
  path <- pkgload::pkg_path()
  # Collected, not fired and forgotten. load_all() in a cold daemon is slow, and
  # returning before it finishes leaves the daemons still priming: the pre-flight
  # probe then queues behind it on every daemon and can ride out its whole bound.
  # M07's probe hid this by asking a single daemon, so whichever one was free
  # answered; asking all of them is what surfaced it.
  collect_bounded(mirai::everywhere(
    pkgload::load_all(path, quiet = TRUE),
    .args = list(path = path)
  ), seconds = 120)
  invisible(TRUE)
}

# Take the cold load out of the measurement.
#
# Under `R CMD check` the package is installed rather than primed, so the first
# pre-flight probe is what pays to load nestedtune and its whole dependency
# stack on every daemon at once -- tune alone measured 6.5 s cold (RR03). M07's
# probe never saw that bill because a single task went to whichever daemon was
# free; asking every daemon means the slowest cold load sets the time, and on a
# loaded check machine that exceeded the 30 s default.
#
# That is a real property of the fix, documented in the roxygen and settable
# through the option. Warming here keeps tests about dispatch from failing over
# it, and the bound below covers the case where warming itself is slow.
warm_daemons <- function() {
  collect_bounded(
    mirai::everywhere(requireNamespace("nestedtune", quietly = TRUE)),
    seconds = 180
  )
  invisible(TRUE)
}

# The suite runs on machines under load, where `R CMD check` is doing everything
# else at the same time. The pre-flight bound is infrastructure, never anything
# statistical, so the tests that merely need dispatch to get going are given
# room. The tests that exercise the bound itself pass an explicit `timeout` or
# set the option locally, so none of them reads this value.
options(nestedtune.preflight_timeout = 300000L)

# Start `n` primed daemons from a clean pool. Callers pair this with
# `on.exit(mirai::daemons(0), add = TRUE)`; cleanup is left to the caller rather
# than deferred here so the helpers need no dependency beyond mirai itself.
#
# Always starts from zero: daemons persist session state between tasks, so a
# pool left over from an earlier test is not a fresh measurement -- the trap
# that made an early probe read one answer off another's residue.
start_daemons <- function(n) {
  mirai::daemons(0)
  mirai::daemons(n)
  prime_daemons()
  warm_daemons()
  invisible(n)
}

skip_if_no_daemons <- function() {
  testthat::skip_if_not_installed("mirai")
  testthat::skip_on_cran()
}

# A library a daemon can start from but cannot load much out of.
#
# The trap RR03 named and M07 paid for: strip a daemon's library outright and it
# cannot load *mirai* either, so it dies at startup, is still counted as a
# connection, and hangs the very probe under test -- 39 minutes of `R CMD
# check`. So the scratch library keeps mirai and nanonext, and drops everything
# else.
lean_library <- function(keep = c("mirai", "nanonext")) {
  lib <- tempfile("nestedtune-lean-")
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  linked <- vapply(keep, function(pkg) {
    src <- system.file(package = pkg)
    nzchar(src) && isTRUE(file.symlink(src, file.path(lib, pkg)))
  }, logical(1))
  if (!all(linked)) NULL else lib
}

# Two daemons that genuinely differ in what they can load (M10 T5, AC1).
#
# RR03 Q5 recorded the mechanism as `R_LIBS`; M10 T1 verified that insufficient
# wherever packages live in the SITE library, because R_LIBS only prepends --
# the target stayed reachable and both daemons answered TRUE. Setting
# R_LIBS_SITE *and* R_LIBS_USER does restrict it, leaving `.libPaths()` at the
# scratch library plus base R's own.
#
# The daemons are spawned by hand against a host URL rather than by daemons(n),
# because the environment has to differ per daemon and daemons(n) launches them
# all alike. Returns the connection count actually reached.
start_mixed_daemons <- function(lean_lib, timeout = 60) {
  mirai::daemons(0)
  mirai::daemons(n = 0, url = "tcp://127.0.0.1:0", dispatcher = TRUE)
  url <- mirai::status()$daemons

  # --vanilla so no user .Rprofile or .Renviron can put a library back that the
  # env vars below deliberately withhold, and all three library variables
  # because R_LIBS alone only PREPENDS -- it cannot take the site library away.
  spawn <- function(env) {
    system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", "-e", shQuote(sprintf('mirai::daemon("%s")', url))),
      env = env, wait = FALSE, stdout = FALSE, stderr = FALSE
    )
  }
  spawn(character(0))                                     # the full library
  spawn(sprintf(c("R_LIBS=%s", "R_LIBS_SITE=%s", "R_LIBS_USER=%s"), lean_lib))

  deadline <- Sys.time() + timeout
  while (mirai::status()$connections < 2 && Sys.time() < deadline) {
    Sys.sleep(0.1)
  }
  mirai::status()$connections
}

# Muffle the one warning that is an artifact of testing under pkgload, and
# nothing else.
#
# Serializing a task from a session where load_all() has attached
# `package:nestedtune` makes R warn that the package "may not be available when
# loading" -- once per fold. Verified absent when the package is installed,
# which is how users and R CMD check run it. A blanket suppressWarnings() here
# would also hide the failed-fold warnings these tests exist to check, so the
# filter is by message.
without_pkgload_warning <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (grepl("may not be available when loading", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    }
  )
}
