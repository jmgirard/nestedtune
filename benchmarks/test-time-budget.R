# Report the daemon tests' declared worst case (M16 T2, AC2).
#
# The ledger itself lives in `tests/testthat/helper-time-budget.R`, not here.
# That is deliberate and not an accident of layout: `benchmarks/` is
# `.Rbuildignore`d, so a ledger kept only in this directory would be invisible
# to the guard in `test-suite-hygiene.R` under `R CMD check` -- which is exactly
# the run where an unbudgeted wait costs a 20-minute job. This file is a
# reporter over that ledger, and holds no figures of its own.
#
# Run:  Rscript benchmarks/test-time-budget.R

repo <- normalizePath(getwd())
if (!dir.exists(file.path(repo, "tests", "testthat"))) {
  stop("run this from the repository root: no tests/testthat under ", repo)
}

# The ledger reads its seconds from helper-parallel.R's named bounds, so both
# files are needed and the order matters.
source(file.path(repo, "tests", "testthat", "helper-parallel.R"))
source(file.path(repo, "tests", "testthat", "helper-time-budget.R"))

ledger <- time_budget_ledger()
totals <- time_budget_totals(ledger)

cat("test-time-budget -- declared worst case per file\n\n")
cat("Convention: each wait contributes its own declared seconds. An enclosing\n")
cat("setTimeLimit() never caps it -- M14 established it does not interrupt a\n")
cat("blocked mirai wait, so it is not a bound on the path that stalls.\n\n")

for (i in seq_len(nrow(totals))) {
  file <- totals$file[[i]]
  rows <- ledger[ledger$file == file & ledger$seconds > 0, , drop = FALSE]
  rows <- rows[order(-rows$seconds), , drop = FALSE]
  cat(sprintf("%-32s %8.1f s\n", file, totals$seconds[[i]]))
  for (j in seq_len(nrow(rows))) {
    cat(sprintf("    %5s:%-4d %-24s %7.1f s%s\n",
                "", rows$line[[j]], rows$call[[j]], rows$seconds[[j]],
                if (rows$times[[j]] > 1L) sprintf("  (x%d)", rows$times[[j]]) else ""))
  }
  zero <- sum(ledger$file == file & ledger$seconds == 0)
  if (zero > 0L) cat(sprintf("    %5s      %d further call(s) classified as no-wait\n", "", zero))
  cat("\n")
}

classify <- totals$seconds[totals$file == "test-parallel-classify.R"]
cat(sprintf("localized file: %.1f s against a %.0f s ceiling and a %.1f s pre-M16 figure\n",
            classify, CLASSIFY_BUDGET_CEILING_S, CLASSIFY_BUDGET_PRE_M16_S))
cat(sprintf("  under ceiling: %s   at most half of pre-M16: %s\n",
            classify < CLASSIFY_BUDGET_CEILING_S,
            classify <= CLASSIFY_BUDGET_PRE_M16_S / 2))
cat(sprintf("\nfor scale: this file typically runs 12.0 s (benchmarks/test-timing-baseline.md),\n"))
cat(sprintf("and M12's CI job cap is 20 minutes (1200 s).\n"))
