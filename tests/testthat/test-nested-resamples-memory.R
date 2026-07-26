# AC3 and AC4 -- the memory oracles. These are the two independent oracle types
# GP2 requires for the size claim; AC2's identity tests are the third.
#
# Oracle records (validation doctrine; DESIGN.md Conventions declares that they
# live beside the asserting test):
#
#   O1  type      live -- an independent implementation recomputed at test time
#       source    rsample::nested_cv(), recomputed here rather than frozen
#       asserts   that the per-outer-fold size slope is far shallower than
#                 rsample's, in `the size slope is far shallower ...` below
#
#   O2  type      closed-form -- a storage model recomputed with explicit
#                 arithmetic, independent of the implementation under test
#       source    derived in `analytic_size()` below from what the structure
#                 must hold: one shared copy of the data, the outer splits'
#                 index vectors, and the inner splits' index vectors. The
#                 inner term charges both an analysis and an assessment index
#                 because splits indexing the whole data cannot derive the
#                 complement -- rsample's inner splits can leave `out_id = NA`
#                 only because they index a frame that already *is* the
#                 analysis set.
#       asserts   the measured size at every v, in `measured size matches the
#                 analytic prediction` below
#
# Fixture provenance: mlbench::LetterRecognition, the dataset rsample#283's own
# measurements use. It is not committed -- it is loaded from the Suggests
# package, so the generator is the `letter_recognition()` call below plus the
# seed each measurement fixes.

letter_recognition <- function() {
  env <- new.env(parent = emptyenv())
  utils::data("LetterRecognition", package = "mlbench", envir = env)
  env$LetterRecognition
}

# One shared copy of the data, plus every index vector the scheme implies.
#
# The outer rset holds one analysis index per fold, summing to n * (v - 1)
# integers. Each inner split holds an analysis index and an assessment index,
# which together partition its outer fold's analysis set; with `inner_v` inner
# splits per outer fold that is inner_v * n * (v - 1) integers. R stores an
# integer in 4 bytes.
analytic_size <- function(data_bytes, n, v, inner_v) {
  data_bytes + 4 * n * (v - 1) * (inner_v + 1)
}

measure <- function(v_values, inner_v = 5, seed = 1) {
  d <- letter_recognition()
  n <- nrow(d)
  data_bytes <- as.numeric(lobstr::obj_size(d))

  rows <- lapply(v_values, function(v) {
    set.seed(seed)
    lean <- nested_resamples(d, outside = rsample::vfold_cv(v = v),
                             inside = rsample::vfold_cv(v = inner_v))
    set.seed(seed)
    ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = v),
                              inside = rsample::vfold_cv(v = inner_v))
    data.frame(
      v = v,
      lean = as.numeric(lobstr::obj_size(lean)) / data_bytes,
      ref = as.numeric(lobstr::obj_size(ref)) / data_bytes,
      analytic = analytic_size(data_bytes, n, v, inner_v) / data_bytes
    )
  })
  do.call(rbind, rows)
}

# Slope of size-in-data-units against the outer fold count, over the endpoints.
slope <- function(size, v) (size[length(size)] - size[1]) / (v[length(v)] - v[1])

V_VALUES <- c(2, 5, 10, 50)

test_that("the size slope is far shallower than rsample::nested_cv()'s", {
  skip_if_not_installed("lobstr")
  skip_if_not_installed("mlbench")

  m <- measure(V_VALUES)

  # Recorded measurement, LetterRecognition (20000 x 17, 2.645 MB), inner v = 5,
  # rsample 1.3.2 / R 4.6.1, as multiples of the source data size:
  #
  #   v      lean     rsample   analytic
  #    2     1.186     2.156     1.181
  #    5     1.734     5.612     1.726
  #   10     2.649    11.373     2.633
  #   50     9.965    57.458     9.893
  #
  # slopes per outer fold: lean 0.183, rsample 1.152 -- a ratio of 6.3.
  lean_slope <- slope(m$lean, m$v)
  ref_slope <- slope(m$ref, m$v)

  # rsample keeps one materialized analysis set per outer fold, so its slope is
  # essentially one copy of the data per fold.
  expect_gt(ref_slope, 0.9)
  expect_lt(ref_slope, 1.3)

  # AC3: growth comes from index vectors only.
  expect_lt(lean_slope, 0.25)
  expect_gte(ref_slope / lean_slope, 5)

  # And the advantage widens rather than holding constant.
  gap <- m$ref - m$lean
  expect_true(all(diff(gap) > 0))
})

test_that("measured size matches the analytic prediction within 2%", {
  skip_if_not_installed("lobstr")
  skip_if_not_installed("mlbench")

  m <- measure(V_VALUES)

  # A shared copy plus the index vectors is the whole story; anything the model
  # omits -- a retained analysis frame above all -- would show up here as the
  # measurement outrunning the prediction.
  expect_true(all(abs(m$lean / m$analytic - 1) <= 0.02))
})

test_that("rsample's own size does NOT match the lean analytic model", {
  skip_if_not_installed("lobstr")
  skip_if_not_installed("mlbench")

  m <- measure(V_VALUES)

  # The model would be vacuous if it fitted anything, so it is checked against
  # the implementation it is meant to distinguish.
  expect_false(any(abs(m$ref / m$analytic - 1) <= 0.02))
})
