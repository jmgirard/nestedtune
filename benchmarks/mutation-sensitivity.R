# Do the memoised test files still fail when the code they test is wrong?
#
# Sharing one fixture across many tests buys speed, and the thing it could
# plausibly cost is sensitivity: a file that reads a cached object rather than
# running the code could keep passing over a real defect. This script settles
# that by breaking the code on purpose.
#
# For each converted file it makes one named single-line mutation to a function
# that file's own assertions target, then runs two files: the target, which must
# FAIL, and a control, which must PASS. The control is what separates "the
# mutation broke something" from "the mutation broke everything" -- a change
# that reddened the whole suite would prove nothing about the target file.
#
# Every mutation is reverted whether or not the run succeeded. Usage:
#
#   Rscript benchmarks/mutation-sensitivity.R

mutations <- list(
  list(
    target = "test-nested-results-plot.R",
    control = "test-nested-final-fit-print.R",
    source = "R/nested-results-plot.R",
    fn = "from_folds()",
    old = '  paste0("from ", k, " fold", ifelse(k == 1L, "", "s"))',
    new = '  paste0("from ", k + 1L, " fold", ifelse(k == 1L, "", "s"))'
  ),
  list(
    target = "test-nested-results-print.R",
    control = "test-nested-results-plot.R",
    source = "R/nested-results-print.R",
    fn = "selection_values()",
    old = "    value <- s[[param]][[1L]]",
    new = "    value <- NA"
  ),
  list(
    target = "test-nested-tune-grid-failures.R",
    control = "test-nested-final-fit-results.R",
    source = "R/nested-tune-grid.R",
    fn = "own_note()",
    old = '    type = "error",',
    new = '    type = "failure",'
  ),
  list(
    target = "test-nested-tune-grid-results.R",
    control = "test-nested-final-fit-print.R",
    source = "R/nested-results.R",
    fn = "collect_metrics.nested_results()",
    old = "collect_metrics.nested_results <- function(x, summarize = TRUE, ...) {",
    new = "collect_metrics.nested_results <- function(x, summarize = FALSE, ...) {"
  ),
  list(
    target = "test-nested-final-fit-print.R",
    control = "test-nested-final-fit-results.R",
    source = "R/nested-final-fit-print.R",
    fn = "selected_label()",
    old = '  paste0(keep, " = ", vapply(keep, function(nm) {',
    new = '  paste0(keep, ": ", vapply(keep, function(nm) {'
  ),
  list(
    target = "test-nested-final-fit-results.R",
    control = "test-nested-tune-grid-results.R",
    source = "R/nested-final-fit.R",
    fn = "new_nested_final_fit()",
    old = "      fit_seed = seeds[[2L]]",
    new = "      fit_seed = seeds[[1L]]"
  )
)

# A fresh session per mutation: the package has to be reloaded from the mutated
# source, and load_all() into this one would leave the mutation live for the
# next mutation's control run.
run_files <- function(files) {
  script <- sprintf('
    Sys.setenv(NOT_CRAN = "true")
    suppressMessages(pkgload::load_all(".", quiet = TRUE))
    for (f in c(%s)) {
      r <- testthat::test_file(file.path("tests/testthat", f), package = "nestedtune",
                               reporter = "silent", stop_on_failure = FALSE)
      df <- as.data.frame(r)
      bad <- sum(df$failed) + sum(df$error)
      broke <- df$test[df$failed > 0 | df$error > 0]
      cat(sprintf("RESULT\t%%s\t%%s\t%%d\t%%s\n", f, if (bad > 0) "FAIL" else "PASS",
                  bad, if (length(broke)) broke[[1L]] else "-"))
    }', paste(sprintf('"%s"', files), collapse = ", "))
  out <- system2("Rscript", c("-e", shQuote(script)), stdout = TRUE, stderr = FALSE)
  lines <- grep("^RESULT\t", out, value = TRUE)
  parsed <- do.call(rbind, strsplit(lines, "\t", fixed = TRUE))
  # Keyed by file, one row each. Not `split()` + `setNames()`: split() returns
  # its groups in sorted order, so renaming them with the unsorted file column
  # relabels every row with another row's verdict.
  out <- lapply(seq_len(nrow(parsed)), function(i) as.character(parsed[i, 3:5]))
  names(out) <- parsed[, 2]
  out
}

results <- list()
for (m in mutations) {
  original <- readLines(m$source)
  stopifnot(sum(original == m$old) == 1L)
  on.exit(writeLines(original, m$source), add = TRUE)
  writeLines(replace(original, original == m$old, m$new), m$source)
  got <- tryCatch(run_files(c(m$target, m$control)), error = function(e) NULL)
  writeLines(original, m$source)

  target <- got[[m$target]]
  control <- got[[m$control]]
  results[[length(results) + 1L]] <- data.frame(
    file = m$target,
    mutation = sprintf("%s in %s: `%s` -> `%s`", m$fn, m$source,
                       trimws(m$old), trimws(m$new)),
    verdict = target[[1L]],
    failures = target[[2L]],
    first_failing_test = target[[3L]],
    control = sprintf("%s: %s", m$control, control[[1L]]),
    stringsAsFactors = FALSE
  )
  cat(sprintf("%-38s %s (%s failures) | control %s: %s\n", m$target,
              target[[1L]], target[[2L]], m$control, control[[1L]]))
}

report <- do.call(rbind, results)
cat("\n")
for (i in seq_len(nrow(report))) {
  cat(sprintf("%s\n  mutation: %s\n  verdict: %s, %s failure(s), first: %s\n  %s\n\n",
              report$file[[i]], report$mutation[[i]], report$verdict[[i]],
              report$failures[[i]], report$first_failing_test[[i]],
              report$control[[i]]))
}

passed <- all(report$verdict == "FAIL") &&
  all(grepl("PASS$", report$control))
cat(if (passed) {
  "ALL SENSITIVE: every converted file failed its own mutation; every control passed.\n"
} else {
  "NOT SENSITIVE: see the rows above.\n"
})
