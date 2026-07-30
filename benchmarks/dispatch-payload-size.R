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
if (requireNamespace("pkgload", quietly = TRUE) &&
    !requireNamespace("nestedtune", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressMessages(library(nestedtune))
}

cat(R.version.string, "|", R.version$platform, "\n")
cat("rsample", as.character(packageVersion("rsample")),
    "| mirai", as.character(packageVersion("mirai")), "\n\n")

# The fixture M23's criteria name. Numeric columns throughout, because R's
# serializer memoises CHARSXPs through the global string cache -- a character
# column would deduplicate across copies and hide the very duplication this
# measures.
fixture_data <- function(n = 5000, p = 20, seed = 1) {
  set.seed(seed)
  d <- data.frame(y = rnorm(n), matrix(rnorm(n * p), n, p))
  names(d)[-1] <- paste0("x", seq_len(p))
  d
}

nbytes <- function(x) length(serialize(x, NULL))

# The wire bytes of a frame's first values, which appear once per copy of that
# frame in a serialized stream. Doubles are written big-endian by R's XDR
# format, so writeBin(endian = "big") reproduces them exactly.
sentinel_of <- function(frame, column = 1L, k = 40L) {
  writeBin(frame[[column]][seq_len(k)], raw(), endian = "big")
}

count_copies <- function(x, sentinel) {
  length(grepRaw(sentinel, serialize(x, NULL), all = TRUE, fixed = TRUE))
}

# The closed form AC2 compares against: index vectors and nothing else. Derived
# from what the payload must hold, never from the payload itself -- an inner
# split lost to a bug would shrink measurement and prediction together if this
# read lengths off the object.
predicted_lean_bytes <- function(n, v, inner_v) {
  outer_analysis <- n * (v - 1) / v
  4 * (outer_analysis + inner_v * outer_analysis)
}

# A formula carries its environment, and R serializes an ordinary environment by
# CONTENTS while globalenv() and namespaces go by reference. A workflow built at
# a user's top level therefore weighs almost nothing, while the same workflow
# built inside a function drags that function's frame -- including the design --
# onto the wire, which measured 26,549,958 B here before this was pinned. The
# formula is given an empty environment so the number describes the package
# rather than this script's own scope.
clean_workflow <- function() {
  env <- new.env(parent = baseenv())
  workflow() |>
    add_formula(stats::as.formula("y ~ .", env = env)) |>
    add_model(linear_reg())
}

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
      payload_bytes = nbytes(payload),
      shared_copies = count_copies(payload, sentinel_shared),
      inner_copies = count_copies(payload, sentinel_of(inner_frame))
    )
  })
  rows <- do.call(rbind, rows)
  print(rows, row.names = FALSE)

  args_bytes <- nbytes(list(object = clean_workflow(), grid = 3, metrics = NULL))
  total <- sum(rows$payload_bytes) + n_folds * args_bytes
  cat("  data serialized      :", nbytes(data), "B\n")
  cat("  .args per fold       :", args_bytes, "B\n")
  cat("  TOTAL WIRE (run)     :", total, "B\n\n")
  invisible(total)
}

d <- fixture_data()

cat("closed-form prediction for a leaned payload (n=5000, v=5, inner_v=5):",
    predicted_lean_bytes(5000, 5, 5), "B\n\n")

set.seed(2)
report("nested_resamples", nested_resamples(d, vfold_cv(v = 5), vfold_cv(v = 5)), d)

set.seed(2)
report("rsample::nested_cv", nested_cv(d, vfold_cv(v = 5), vfold_cv(v = 5)), d)
