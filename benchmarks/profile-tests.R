# Where the test suite spends its time, per file.
#
# Run this, not `system.time(devtools::test())`: the number that matters is the
# per-file breakdown, and a single wall-clock total hides which file is worth
# converting. Usage, from the package root:
#
#   Rscript benchmarks/profile-tests.R [runs]
#
# The measurement conditions are deliberately those of `devtools::test()` and
# not of `R CMD check`: the package is loaded ONCE with pkgload::load_all(),
# the helper files are sourced ONCE, and every test file then runs in a child
# of that one environment. That is the condition a suite-level fixture cache
# lives in -- run each file in its own session instead and every cache starts
# empty, which measures a different thing.
#
# NOT_CRAN is set to "true" for the same reason devtools does: tests that skip
# on CRAN are part of what a developer waits for.

runs <- {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) >= 1L) as.integer(a[[1L]]) else 3L
}
stopifnot(!is.na(runs), runs >= 1L)

Sys.setenv(NOT_CRAN = "true")
suppressMessages(pkgload::load_all(".", quiet = TRUE))

# One pass over the suite. `load_package = "none"` because load_all() above
# already did it -- reloading per run would time the package build, not the
# tests.
one_run <- function() {
  started <- proc.time()[["elapsed"]]
  res <- testthat::test_dir(
    "tests/testthat",
    package = "nestedtune",
    load_package = "none",
    reporter = "silent",
    stop_on_failure = FALSE
  )
  df <- as.data.frame(res)
  list(
    per_file = tapply(df$real, df$file, sum),
    counts = c(
      pass = sum(df$nb) - sum(df$failed) - sum(df$skipped) - sum(df$error),
      fail = sum(df$failed) + sum(df$error),
      skip = sum(df$skipped)
    ),
    total = sum(df$real),
    wall = proc.time()[["elapsed"]] - started
  )
}

passes <- vector("list", runs)
for (i in seq_len(runs)) {
  cat(sprintf("run %d/%d ...\n", i, runs))
  passes[[i]] <- one_run()
}

files <- sort(unique(unlist(lapply(passes, function(p) names(p$per_file)))))
med <- function(f) {
  stats::median(
    vapply(
      passes,
      function(p) {
        # Single-bracket, deliberately: `per_file` is a tapply result, and `[[` on a
        # name it does not carry raises "subscript out of bounds" rather than
        # returning NULL -- so a run whose file set differs from the union above (a
        # file that failed to source, a file added between runs) would kill the
        # profiler after it had already paid for every run.
        unname(p$per_file[f])
      },
      numeric(1)
    ),
    na.rm = TRUE
  )
}
elapsed <- vapply(files, med, numeric(1))
ord <- order(elapsed, decreasing = TRUE)

total <- stats::median(vapply(passes, function(p) p$total, numeric(1)))
wall <- stats::median(vapply(passes, function(p) p$wall, numeric(1)))

cat("\n")
cat(sprintf("R:        %s\n", R.version.string))
cat(sprintf("OS:       %s\n", sessionInfo()$running))
cat(sprintf("testthat: %s\n", as.character(utils::packageVersion("testthat"))))
cat(sprintf(
  "commit:   %s\n",
  system("git rev-parse --short HEAD", intern = TRUE)
))
cat(sprintf("NOT_CRAN: %s\n", Sys.getenv("NOT_CRAN")))
cat(sprintf(
  "loading:  package loaded once for all files (pkgload::load_all)\n"
))
cat(sprintf("runs:     %d (all figures are medians)\n\n", runs))

cat(sprintf("%-42s %8s %6s\n", "file", "seconds", "share"))
for (f in files[ord]) {
  cat(sprintf(
    "%-42s %8.1f %5.1f%%\n",
    f,
    elapsed[[f]],
    100 * elapsed[[f]] / total
  ))
}
cat(sprintf("%-42s %8.1f\n", "SUITE TOTAL (sum of test times)", total))
cat(sprintf("%-42s %8.1f\n", "wall clock for the run", wall))

counts <- passes[[1L]]$counts
cat(sprintf(
  "\npass %d | fail %d | skip %d\n",
  counts[["pass"]],
  counts[["fail"]],
  counts[["skip"]]
))

installed <- vapply(
  c("lobstr", "mlbench", "ranger", "vdiffr"),
  function(p) requireNamespace(p, quietly = TRUE),
  logical(1)
)
cat(sprintf(
  "optional packages: %s\n",
  paste(
    sprintf("%s=%s", names(installed), ifelse(installed, "yes", "no")),
    collapse = ", "
  )
))
