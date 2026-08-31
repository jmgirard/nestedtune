# What one outer fold's dispatch actually puts on the wire.
#
# Not a wall-clock benchmark: this measures bytes, which are deterministic, so
# unlike parallel-speedup.R the numbers here are reproducible to the byte on any
# machine running the same R and rsample. It exists so M23's before/after totals
# can be re-derived rather than remembered, and so the same accounting is
# available outside the test suite.
#
#   Rscript benchmarks/dispatch-payload-size.R
#
# Two things are counted for each fold, because either alone is misleading:
#
#   .x    the per-fold payload mirai_map() maps over
#   .args the static list sent WITH each task -- mirai serializes it once per
#         task, not once per run (read from mirai::mirai_map's source), so it is
#         wire cost per fold exactly as the payload is
#
# and two independent oracles are reported for the payload, per GP2:
#
#   size   serialized bytes, comparable against a closed form derived from
#          n / v / inner_v alone
#   copies how many times the data's own wire bytes occur in the stream, found
#          by searching for the big-endian doubles of one column. This is
#          independent of the size arithmetic: it counts copies directly rather
#          than inferring them from a total.

suppressMessages({
  library(rsample)
  library(parsnip)
  library(workflows)
})
if (
  requireNamespace("pkgload", quietly = TRUE) &&
    !requireNamespace("nestedtune", quietly = TRUE)
) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressMessages(library(nestedtune))
}

cat(R.version.string, "|", R.version$platform, "\n")
cat(
  "rsample",
  as.character(packageVersion("rsample")),
  "| mirai",
  as.character(packageVersion("mirai")),
  "\n\n"
)

# The oracles and the fixture are defined ONCE, in the test helper, and sourced
# here. The header of that file says this happens; it has to actually happen, or
# the number a benchmark run prints and the number the suite asserts drift apart
# -- which is the failure M16's ledger lesson is about, and copies of these
# definitions had already diverged by one `stopifnot` before this line existed.
helper <- file.path("tests", "testthat", "helper-payload-size.R")
if (!file.exists(helper)) {
  stop("run this from the repository root: ", helper, " not found")
}
source(helper)

report <- function(label, design, data) {
  sentinel_shared <- sentinel_of(data)
  n_folds <- nrow(design)
  cat("==", label, "--", n_folds, "outer folds ==\n")

  rows <- lapply(seq_len(n_folds), function(i) {
    payload <- list(
      split = design$splits[[i]],
      inner = design$inner_resamples[[i]],
      seeds = c(1L, 2L)
    )
    inner_frame <- design$inner_resamples[[i]]$splits[[1]]$data
    data.frame(
      fold = i,
      payload_bytes = payload_bytes(payload),
      shared_copies = count_data_copies(payload, sentinel_shared),
      inner_copies = count_data_copies(payload, sentinel_of(inner_frame))
    )
  })
  rows <- do.call(rbind, rows)
  print(rows, row.names = FALSE)

  args_bytes <- payload_bytes(list(
    object = payload_fixture_workflow(),
    grid = 3,
    metrics = NULL
  ))
  total <- sum(rows$payload_bytes) + n_folds * args_bytes
  cat("  data serialized      :", payload_bytes(data), "B\n")
  cat("  .args per fold       :", args_bytes, "B\n")
  cat("  TOTAL WIRE (run)     :", total, "B\n")

  # The "after" half. Without this the script re-derives only the number the
  # milestone replaced, and the one it claims cannot be reproduced by running it.
  worker <- nestedtune:::fold_task
  environment(worker) <- globalenv()
  lean <- lapply(rows$fold, function(i) {
    nestedtune:::lean_payload(
      list(
        split = design$splits[[i]],
        inner = design$inner_resamples[[i]],
        seeds = c(1L, 2L)
      ),
      shared = data
    )
  })
  lean_args <- payload_bytes(list(
    object = payload_fixture_workflow(),
    grid = 3,
    metrics = NULL,
    shared = data,
    worker = worker
  ))
  lean_total <- sum(vapply(lean, payload_bytes, numeric(1))) +
    n_folds * lean_args
  cat(
    "  TOTAL WIRE (leaned)  :",
    lean_total,
    "B =",
    sprintf("%.1f%%", 100 * lean_total / total),
    "of the above\n\n"
  )
  invisible(c(before = total, after = lean_total))
}

d <- payload_fixture_data()

cat(
  "closed-form prediction for a leaned payload (n=5000, v=5, inner_v=5):",
  predicted_lean_bytes(5000, 5, 5),
  "B\n\n"
)

set.seed(2)
report(
  "nested_resamples",
  nested_resamples(d, vfold_cv(v = 5), vfold_cv(v = 5)),
  d
)

set.seed(2)
report("rsample::nested_cv", nested_cv(d, vfold_cv(v = 5), vfold_cv(v = 5)), d)
