# Daemon fixtures for the parallel tests.
#
# Daemons are separate R processes and load nestedtune from an installed
# library. Under devtools/pkgload there may be no installed copy at all -- and
# worse, there may be a *stale* one, in which case daemons quietly run old code
# while the host runs the code under test (RR03 Q5). Priming the daemons with
# pkgload closes both holes; under R CMD check the package is installed and the
# daemons inherit the library through the environment, so priming is a no-op.

prime_daemons <- function() {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(invisible(FALSE))
  }
  if (!isTRUE(pkgload::is_dev_package("nestedtune"))) {
    return(invisible(FALSE))
  }
  path <- pkgload::pkg_path()
  mirai::everywhere(pkgload::load_all(path, quiet = TRUE), .args = list(path = path))
  invisible(TRUE)
}

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

  spawn <- function(env) {
    system2(
      file.path(R.home("bin"), "Rscript"),
      c("-e", shQuote(sprintf('mirai::daemon("%s")', url))),
      env = env, wait = FALSE, stdout = FALSE, stderr = FALSE
    )
  }
  spawn(character(0))                                     # the full library
  spawn(c(sprintf("R_LIBS_SITE=%s", lean_lib),            # mirai and no more
          sprintf("R_LIBS_USER=%s", lean_lib)))

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
