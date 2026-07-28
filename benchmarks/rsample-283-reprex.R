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

stopifnot(requireNamespace("rsample", quietly = TRUE),
          requireNamespace("mlbench", quietly = TRUE),
          requireNamespace("lobstr", quietly = TRUE))

SEED <- 35222 # the seed the issue's own reprex fixes

cat(R.version.string, "|", R.version$platform, "\n")
cat("rsample", as.character(packageVersion("rsample")),
    "| mlbench", as.character(packageVersion("mlbench")),
    "| lobstr", as.character(packageVersion("lobstr")),
    "| seed", SEED, "\n\n")

env <- new.env(parent = emptyenv())
utils::data("LetterRecognition", package = "mlbench", envir = env)
d <- env$LetterRecognition
data_bytes <- as.numeric(lobstr::obj_size(d))

cat(sprintf("LetterRecognition: %d x %d, %s B\n\n",
            nrow(d), ncol(d), format(data_bytes, big.mark = ",")))

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

# ---- both schemes, built explicitly -----------------------------------------

measure <- function(v, inner_v) {
  set.seed(SEED)
  nested <- rsample::nested_cv(d,
                               outside = rsample::vfold_cv(v = v),
                               inside = rsample::vfold_cv(v = inner_v))
  bytes <- as.numeric(lobstr::obj_size(nested))
  data.frame(
    scheme = sprintf("%dx%d", v, inner_v),
    v = v,
    inner_v = inner_v,
    outer_folds = nrow(nested),
    bytes = bytes,
    per_fold = bytes / nrow(nested),
    ratio = bytes / data_bytes
  )
}

schemes <- rbind(
  measure(10, 10), # what the reprex built
  measure(5, 2)    # what its prose describes
)

cat("scheme  outer folds        bytes      per fold    x data\n")
for (i in seq_len(nrow(schemes))) {
  r <- schemes[i, ]
  cat(sprintf("%-6s  %11d  %11s  %12s  %8.3f\n",
              r$scheme, r$outer_folds,
              format(round(r$bytes), big.mark = ","),
              format(round(r$per_fold), big.mark = ","),
              r$ratio))
}
cat("\nissue #283 reports 34,434,200 B, 3,443,420 B per resample, 13.02037x.\n")
cat("`obj_size(nested) / nrow(nested)` is the issue's own per-resample figure;",
    "\nthe divisor it used is the outer fold count printed above.\n")
