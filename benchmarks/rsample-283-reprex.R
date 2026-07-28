# Object size of rsample::nested_cv() under the two schemes rsample#283
# conflates: the 10x10 its reprex actually built, and the 5x2 its prose
# describes.
#
#   Rscript benchmarks/rsample-283-reprex.R
#
# The issue reports 13.02x on a call written as `vfold_cv(times = 5)` /
# `vfold_cv(times = 2)`. `vfold_cv()` has no `times` argument; in 2022 that
# argument fell into `...` and both levels took the default `v = 10`. Current
# rsample rejects the same call outright, so the original reprex cannot be
# re-run at all -- which is why both schemes are rebuilt here explicitly rather
# than by replaying it.
#
# Nothing here is asserted. This script exists so that every figure quoted to
# rsample's maintainers is reproducible from a committed recipe, and so a later
# rsample release that changes the answer can be caught by running it again.
#
# Two independent oracle types back each figure (GP2):
#
#   live         the measurement below, `lobstr::obj_size()` on a structure
#                rsample builds here, at the version this script prints
#   closed-form  `rsample_size()` below, the storage the structure must hold,
#                recomputed with explicit arithmetic and independent of
#                rsample's implementation
#
# The closed-form model is anchored to a third, already-committed measurement:
# 11.373x at v = 10 / inner v = 5, recorded at
# tests/testthat/test-nested-resamples-memory.R:87 by the oracle that backs
# nestedtune's own lean constructor.

stopifnot(requireNamespace("rsample", quietly = TRUE),
          requireNamespace("mlbench", quietly = TRUE),
          requireNamespace("lobstr", quietly = TRUE))

SEED <- 35222 # the seed the issue's own reprex fixes

# Committed elsewhere in this repo; see the header note above.
COMMITTED_10x5 <- 11.373

# What the issue reports, for the drift accounting at the end.
ISSUE_BYTES <- 34434200

cat(R.version.string, "|", R.version$platform, "\n")
cat("rsample", as.character(packageVersion("rsample")),
    "| mlbench", as.character(packageVersion("mlbench")),
    "| lobstr", as.character(packageVersion("lobstr")),
    "| seed", SEED, "\n\n")

env <- new.env(parent = emptyenv())
utils::data("LetterRecognition", package = "mlbench", envir = env)
d <- env$LetterRecognition
n <- nrow(d)
data_bytes <- as.numeric(lobstr::obj_size(d))

cat(sprintf("LetterRecognition: %d x %d, %s B\n\n",
            n, ncol(d), format(data_bytes, big.mark = ",")))

# ---- the closed-form storage model ------------------------------------------
#
# What a `nested_cv` object must hold, term by term. `inside_resample()` calls
# `as.data.frame()` on each outer split, which materializes that fold's
# analysis set; the inner rset then references that copy rather than the
# original data. So:
#
#   data_bytes                 one shared copy of the source data
#   data_bytes * (v - 1)       v materialized analysis frames, each holding
#                              n(v-1)/v of the n rows, so v * (v-1)/v copies
#   4 * n * (v - 1)            the outer splits' analysis indices: n(v-1)/v
#                              integers each, v of them. `out_id` is NA on
#                              these -- a split indexing the whole data can
#                              derive its complement.
#   4 * n * (v-1) * (inner_v-1)  the inner splits' analysis indices: each inner
#                              split holds m(inner_v-1)/inner_v of its fold's
#                              m = n(v-1)/v rows, inner_v splits per fold,
#                              v folds. `out_id` is NA on these too.
#
# R stores an integer in 4 bytes. The two index terms collapse:
#
#   4n(v-1) + 4n(v-1)(inner_v-1) = 4n(v-1) * inner_v
#
# The model omits per-object overhead -- the rsplit lists, the tibbles, their
# attributes -- so it should sit slightly UNDER every measurement. A model
# running OVER would mean the structure holds less than this accounting says,
# and the diagnosis would be wrong.
rsample_size <- function(data_bytes, n, v, inner_v) {
  data_bytes * v + 4 * n * (v - 1) * inner_v
}

# For contrast, the model already committed for nestedtune's lean constructor
# (test-nested-resamples-memory.R:43). Its data term does not scale with v --
# that difference, (v-1) copies of the data, IS the issue.
lean_size <- function(data_bytes, n, v, inner_v) {
  data_bytes + 4 * n * (v - 1) * (inner_v + 1)
}

# ---- the call the issue actually made ---------------------------------------
#
# Recorded rather than worked around: the claim that the reprex built a 10x10
# scheme rests on this call being the one that produced 13.02x, and on what
# `times` did with it.

original <- tryCatch(
  rsample::nested_cv(d,
                     outside = rsample::vfold_cv(times = 5),
                     inside = rsample::vfold_cv(times = 2)),
  error = function(e) e
)
cat("the issue's original call, under rsample",
    as.character(packageVersion("rsample")), "->\n  ",
    if (inherits(original, "error")) {
      paste0(class(original)[1], ": ", conditionMessage(original))
    } else {
      sprintf("no error; %d outer folds", nrow(original))
    },
    "\n\n")

# ---- measurement against the model ------------------------------------------

measure <- function(v, inner_v, note) {
  set.seed(SEED)
  nested <- rsample::nested_cv(d,
                               outside = rsample::vfold_cv(v = v),
                               inside = rsample::vfold_cv(v = inner_v))
  bytes <- as.numeric(lobstr::obj_size(nested))
  model <- rsample_size(data_bytes, n, v, inner_v)
  data.frame(
    scheme = sprintf("%dx%d", v, inner_v),
    note = note,
    outer_folds = nrow(nested),
    bytes = bytes,
    per_fold = bytes / nrow(nested),
    ratio = bytes / data_bytes,
    model_ratio = model / data_bytes,
    resid_pct = 100 * (model / bytes - 1),
    lean_ratio = lean_size(data_bytes, n, v, inner_v) / data_bytes
  )
}

schemes <- rbind(
  measure(10, 5, "the committed anchor"),
  measure(10, 10, "what the reprex built"),
  measure(5, 2, "what its prose describes")
)

cat("scheme  outer        bytes     x data   model   resid    lean model\n")
for (i in seq_len(nrow(schemes))) {
  r <- schemes[i, ]
  cat(sprintf("%-6s  %5d  %11s  %9.3f %7.3f %+6.2f%%  %9.3f   %s\n",
              r$scheme, r$outer_folds,
              format(round(r$bytes), big.mark = ","),
              r$ratio, r$model_ratio, r$resid_pct, r$lean_ratio, r$note))
}

anchor <- schemes[schemes$scheme == "10x5", ]
cat(sprintf(
  paste0("\nanchor: this run measures %.3fx at 10x5; the committed figure is ",
         "%.3fx (%+.2f%%),\n        and the model predicts %.3fx (%+.2f%% ",
         "against the committed figure).\n"),
  anchor$ratio, COMMITTED_10x5,
  100 * (anchor$ratio / COMMITTED_10x5 - 1),
  anchor$model_ratio,
  100 * (anchor$model_ratio / COMMITTED_10x5 - 1)))

# ---- the issue's 2022 figure against today's --------------------------------
#
# The issue measured 34,434,200 B where the same scheme measures less today.
# The gap is one explicit integer row-names vector per materialized analysis
# frame: v frames of n(v-1)/v rows, 4 bytes each. Today those frames carry
# compact row names, which `.row_names_info()` reports as a negative count.

reprex_row <- schemes[schemes$scheme == "10x10", ]
rownames_cost <- 4 * (n * 9 / 10) * 10
set.seed(SEED)
one_frame <- as.data.frame(
  rsample::nested_cv(d,
                     outside = rsample::vfold_cv(v = 10),
                     inside = rsample::vfold_cv(v = 10))$splits[[1]]
)
cat(sprintf(
  paste0("\ndrift: issue %s B - this run %s B = %s B;\n",
         "       %d explicit row-names vectors would cost %s B.\n",
         "       .row_names_info() on an analysis frame today: %d ",
         "(negative = compact).\n"),
  format(ISSUE_BYTES, big.mark = ","),
  format(round(reprex_row$bytes), big.mark = ","),
  format(round(ISSUE_BYTES - reprex_row$bytes), big.mark = ","),
  10, format(rownames_cost, big.mark = ","),
  .row_names_info(one_frame)))

cat("\nissue #283 reports 3,443,420 B per resample, from",
    "`obj_size(nested) / nrow(nested)`;\nthe divisor it used is the outer",
    "fold count printed above.\n")
