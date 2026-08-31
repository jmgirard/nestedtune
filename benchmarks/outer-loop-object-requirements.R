# The two size axes behind the resampling-object requirements note (M27):
# what the object costs to HOLD, and what one fold costs to SEND.
#
#   Rscript benchmarks/outer-loop-object-requirements.R
#
# A sibling of rsample-283-reprex.R rather than an extension of it, so the
# committed recipe behind the figures already quoted to rsample's maintainers
# stays byte-stable. The closed-form models here are the same two that script
# derives and documents; its header carries the term-by-term derivation.
#
# Nothing here is asserted. Results are recorded in
# cairn/references/outer-loop-object-requirements.md; a later rsample release
# that changes an answer is caught by running this again.
#
# Two independent oracle types back each axis (GP2):
#
#   axis 1 (in-process size)  live `lobstr::obj_size()` against a closed form
#                             computed from n / v / inner_v alone
#   axis 2 (per-fold wire)    serialized bytes against a closed form, PLUS the
#                             copy-count oracle from helper-payload-size.R --
#                             occurrences of the data's own wire bytes in the
#                             stream, which counts copies rather than inferring
#                             them from a total
#
# Axis 1 runs on mlbench::LetterRecognition, M13's data, at two (v, inner_v)
# settings M13 did not cover -- 5x5 and 20x5 (its script covers 10x5, 10x10,
# 5x2) -- so the models are tested at a practical scheme and at a high outer
# count that stresses the v-scaling data term, which is the term rsample#283
# is about. Axis 2 runs on the M23 payload fixture (5000x21 doubles), the
# frame every wire figure in this repo is quoted on, at the same two settings,
# so its numbers compose with M23's and M26's rather than starting a second
# baseline.

stopifnot(
  requireNamespace("rsample", quietly = TRUE),
  requireNamespace("mlbench", quietly = TRUE),
  requireNamespace("lobstr", quietly = TRUE)
)
if (
  requireNamespace("pkgload", quietly = TRUE) &&
    !requireNamespace("nestedtune", quietly = TRUE)
) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressMessages(library(nestedtune))
}

# The wire oracles and the fixture, defined once in the test helper and sourced
# here (the anti-drift discipline dispatch-payload-size.R states).
helper <- file.path("tests", "testthat", "helper-payload-size.R")
if (!file.exists(helper)) {
  stop("run this from the repository root: ", helper, " not found")
}
source(helper)

SEED <- 35222 # the seed rsample-283-reprex.R fixes, kept for comparability

cat(R.version.string, "|", R.version$platform, "\n")
cat(
  "rsample",
  as.character(packageVersion("rsample")),
  "| nestedtune",
  as.character(packageVersion("nestedtune")),
  "| mlbench",
  as.character(packageVersion("mlbench")),
  "| lobstr",
  as.character(packageVersion("lobstr")),
  "| seed",
  SEED,
  "\n\n"
)

# ---- the closed-form models (derived in rsample-283-reprex.R) ---------------
#
# rsample::nested_cv() materializes each outer fold's analysis frame, so its
# data term scales with v; nested_resamples() keeps one frame and pays an extra
# explicit out_id per inner split instead. R stores an integer in 4 bytes.
rsample_size <- function(data_bytes, n, v, inner_v) {
  data_bytes * v + 4 * n * (v - 1) * inner_v
}
lean_size <- function(data_bytes, n, v, inner_v) {
  data_bytes + 4 * n * (v - 1) * (inner_v + 1)
}

# ==== axis 1: in-process object size =========================================

env <- new.env(parent = emptyenv())
utils::data("LetterRecognition", package = "mlbench", envir = env)
d <- env$LetterRecognition
n <- nrow(d)
data_bytes <- as.numeric(lobstr::obj_size(d))

cat(sprintf(
  "LetterRecognition: %d x %d, %s B\n\n",
  n,
  ncol(d),
  format(data_bytes, big.mark = ",")
))

measure_size <- function(v, inner_v) {
  set.seed(SEED)
  ncv <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = inner_v)
  )
  set.seed(SEED)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = inner_v)
  )
  ncv_bytes <- as.numeric(lobstr::obj_size(ncv))
  lean_bytes <- as.numeric(lobstr::obj_size(lean))
  ncv_model <- rsample_size(data_bytes, n, v, inner_v)
  lean_model <- lean_size(data_bytes, n, v, inner_v)
  data.frame(
    scheme = sprintf("%dx%d", v, inner_v),
    ncv_bytes = ncv_bytes,
    ncv_model_resid_pct = 100 * (ncv_model / ncv_bytes - 1),
    lean_bytes = lean_bytes,
    lean_model_resid_pct = 100 * (lean_model / lean_bytes - 1),
    ratio_ncv_over_lean = ncv_bytes / lean_bytes,
    model_ratio = ncv_model / lean_model
  )
}

sizes <- rbind(measure_size(5, 5), measure_size(20, 5))

cat("== axis 1: obj_size(), nested_cv vs nested_resamples ==\n")
cat("scheme        ncv bytes  resid%      lean bytes  resid%   ratio  model\n")
for (i in seq_len(nrow(sizes))) {
  r <- sizes[i, ]
  cat(sprintf(
    "%-6s  %13s  %+6.2f%%  %12s  %+6.2f%%  %6.3f  %6.3f\n",
    r$scheme,
    format(round(r$ncv_bytes), big.mark = ","),
    r$ncv_model_resid_pct,
    format(round(r$lean_bytes), big.mark = ","),
    r$lean_model_resid_pct,
    r$ratio_ncv_over_lean,
    r$model_ratio
  ))
}

# ==== axis 2: per-fold wire bytes under the current dispatch path ============
#
# The path dispatch_folds() takes today (R/parallel.R): payloads are built as
# nested_tune_grid() builds them (split, inner, seeds), every payload passes
# is_fold_payload(), and lean_payload() blanks whatever a fold shares with
# `shared` -- the first payload's outer frame. What crosses the wire per fold
# is then the leaned payload (mirai_map's .x) plus `shared` riding in .args,
# which mirai serializes once per task, not once per run. The workflow, grid
# and metrics also ride in .args; they are the user's objects, independent of
# the constructor choice, and were measured at M23 -- not counted here.
#
# Closed forms, per fold, from scalars alone. m = n(v-1)/v is the outer
# analysis size; the fixture is n rows by p+1 double columns, 8 bytes each:
#
#   shared frame                 8 n (p+1)
#   nested_resamples payload     4 m (inner_v + 1)      indices only: outer
#                                in_id (m), inner in_id + explicit out_id
#                                (m per split, inner_v splits)
#   nested_cv payload            8 m (p+1) + 4 m inner_v  the fold's own
#                                materialized analysis frame travels with it,
#                                plus outer in_id (m) and inner in_id
#                                (m(inner_v-1)/inner_v per split, out_id NA)
#
# Copy-count oracle: a leaned nested_resamples payload carries 0 frames; a
# leaned nested_cv payload carries 0 copies of the shared frame and exactly 1
# of its own analysis frame; `shared` itself serializes to 1 copy in .args.
FIXTURE_N <- 5000
FIXTURE_P <- 20

wire_models <- function(n, p, v, inner_v) {
  m <- n * (v - 1) / v
  list(
    shared = 8 * n * (p + 1),
    lean_payload = 4 * m * (inner_v + 1),
    ncv_payload = 8 * m * (p + 1) + 4 * m * inner_v
  )
}

measure_wire <- function(constructor, label, v, inner_v) {
  fx <- fixture_design(
    constructor,
    v = v,
    inner_v = inner_v,
    n = FIXTURE_N,
    p = FIXTURE_P
  )
  design <- fx$design
  payloads <- lapply(seq_len(nrow(design)), function(i) {
    list(
      split = design$splits[[i]],
      inner = design$inner_resamples[[i]],
      seeds = c(1L, 2L)
    )
  })
  stopifnot(all(vapply(payloads, nestedtune:::is_fold_payload, logical(1))))
  shared <- payloads[[1L]]$split$data
  lean <- lapply(payloads, nestedtune:::lean_payload, shared = shared)

  shared_bytes <- payload_bytes(shared)
  fold_bytes <- vapply(lean, payload_bytes, numeric(1))
  shared_sentinel <- sentinel_of(shared)
  # Net of the fold's own frame. An analysis frame that happens to keep the
  # sentinel's 40 source rows contiguous reproduces their bytes without being
  # a copy of the shared frame -- at 20x5 a fold's 250 held-out rows miss all
  # of rows 1-40 with probability ~e^-2, so a few folds carry the coincidence.
  # Subtracting the occurrences inside the fold's own frame makes the count
  # answer "copies of the shared frame", not "occurrences of its first bytes".
  shared_copies <- vapply(
    seq_along(lean),
    function(i) {
      raw <- count_data_copies(lean[[i]], shared_sentinel)
      inner_frame <- design$inner_resamples[[i]]$splits[[1L]]$data
      if (identical(inner_frame, shared)) {
        return(raw)
      }
      raw - count_data_copies(inner_frame, shared_sentinel)
    },
    integer(1)
  )
  own_copies <- vapply(
    seq_along(lean),
    function(i) {
      inner_frame <- design$inner_resamples[[i]]$splits[[1L]]$data
      if (identical(inner_frame, shared)) {
        return(NA_integer_) # nothing of its own to count: the frame IS shared
      }
      count_data_copies(lean[[i]], sentinel_of(inner_frame))
    },
    integer(1)
  )

  models <- wire_models(FIXTURE_N, FIXTURE_P, v, inner_v)
  payload_model <- if (identical(label, "nested_resamples")) {
    models$lean_payload
  } else {
    models$ncv_payload
  }
  data.frame(
    scheme = sprintf("%dx%d", v, inner_v),
    constructor = label,
    folds = length(lean),
    payload_mean = mean(fold_bytes),
    payload_model_resid_pct = 100 * (payload_model / mean(fold_bytes) - 1),
    wire_per_fold = mean(fold_bytes) + shared_bytes,
    wire_model = payload_model + models$shared,
    shared_copies = sum(shared_copies),
    own_frame_copies_per_fold = if (all(is.na(own_copies))) {
      0L
    } else {
      as.integer(unique(own_copies))
    }
  )
}

cat(
  "\n== axis 2: per-fold wire bytes, fixture",
  FIXTURE_N,
  "x",
  FIXTURE_P + 1,
  "==\n"
)
shared_ref <- payload_bytes(payload_fixture_data(n = FIXTURE_N, p = FIXTURE_P))
cat(
  "shared frame serialized:",
  format(shared_ref, big.mark = ","),
  "B",
  sprintf(
    "(model %s B, %+.2f%%)\n\n",
    format(8 * FIXTURE_N * (FIXTURE_P + 1), big.mark = ","),
    100 * (8 * FIXTURE_N * (FIXTURE_P + 1) / shared_ref - 1)
  )
)

wire <- rbind(
  measure_wire(nested_resamples, "nested_resamples", 5, 5),
  measure_wire(rsample::nested_cv, "nested_cv", 5, 5),
  measure_wire(nested_resamples, "nested_resamples", 20, 5),
  measure_wire(rsample::nested_cv, "nested_cv", 20, 5)
)

cat(
  "scheme  constructor       payload/fold  resid%   wire/fold      model",
  "  shared-copies  own-frame\n"
)
for (i in seq_len(nrow(wire))) {
  r <- wire[i, ]
  cat(sprintf(
    "%-6s  %-16s %12s  %+6.2f%%  %12s  %12s  %8d  %6d\n",
    r$scheme,
    r$constructor,
    format(round(r$payload_mean), big.mark = ","),
    r$payload_model_resid_pct,
    format(round(r$wire_per_fold), big.mark = ","),
    format(round(r$wire_model), big.mark = ","),
    r$shared_copies,
    r$own_frame_copies_per_fold
  ))
}

cat(
  "\nwire/fold counts the leaned payload plus the shared frame riding in",
  "\n.args, which mirai serializes once per task; the workflow term is the",
  "\nuser's object and is not counted (measured at M23).\n"
)
