# Test fixtures are generated here rather than committed, so this function *is*
# the generator the profile's fixture-provenance rule asks for: source and seed
# are both visible in the code below.

make_test_data <- function(n = 200, seed = 42) {
  set.seed(seed)
  data.frame(
    x = rnorm(n),
    z = runif(n),
    strat = factor(sample(c("a", "b", "c"), n, replace = TRUE)),
    grp = factor(rep(seq_len(n / 10), each = 10))
  )
}

# Comparisons are exact. rsample's analysis()/assessment() renumber row names
# on retrieval, so it makes no difference that nestedtune's splits index the
# original data while rsample's index a materialized analysis frame -- the
# retrieved frames are identical down to their attributes.

expect_inner_identical <- function(lean, ref) {
  testthat::expect_equal(nrow(lean), nrow(ref))
  testthat::expect_equal(lean$id, ref$id)
  for (i in seq_len(nrow(ref))) {
    lean_inner <- lean$inner_resamples[[i]]
    ref_inner <- ref$inner_resamples[[i]]
    testthat::expect_equal(nrow(lean_inner), nrow(ref_inner))
    testthat::expect_equal(lean_inner$id, ref_inner$id)
    for (j in seq_len(nrow(ref_inner))) {
      testthat::expect_identical(
        rsample::analysis(lean_inner$splits[[j]]),
        rsample::analysis(ref_inner$splits[[j]])
      )
      testthat::expect_identical(
        rsample::assessment(lean_inner$splits[[j]]),
        rsample::assessment(ref_inner$splits[[j]])
      )
    }
  }
}

expect_outer_identical <- function(lean, ref) {
  testthat::expect_equal(nrow(lean), nrow(ref))
  testthat::expect_equal(lean$id, ref$id)
  for (i in seq_len(nrow(ref))) {
    testthat::expect_identical(
      rsample::analysis(lean$splits[[i]]),
      rsample::analysis(ref$splits[[i]])
    )
    testthat::expect_identical(
      rsample::assessment(lean$splits[[i]]),
      rsample::assessment(ref$splits[[i]])
    )
  }
}
