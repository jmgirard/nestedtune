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
