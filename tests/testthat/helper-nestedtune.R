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

# rsample's nested_cv() materializes each outer fold's analysis set with
# as.data.frame(), which renumbers rows 1..n; nestedtune indexes the original
# data, so retrieved rows keep their original names. AC2's "row-identical" is
# identity of the rows themselves, so comparisons normalize row names. The
# divergence itself is asserted deliberately in its own test.
strip_rownames <- function(x) {
  rownames(x) <- NULL
  x
}

expect_inner_identical <- function(lean, ref) {
  testthat::expect_equal(nrow(lean), nrow(ref))
  testthat::expect_equal(lean$id, ref$id)
  for (i in seq_len(nrow(ref))) {
    lean_inner <- lean$inner_resamples[[i]]
    ref_inner <- ref$inner_resamples[[i]]
    testthat::expect_equal(nrow(lean_inner), nrow(ref_inner))
    testthat::expect_equal(lean_inner$id, ref_inner$id)
    for (j in seq_len(nrow(ref_inner))) {
      testthat::expect_equal(
        strip_rownames(rsample::analysis(lean_inner$splits[[j]])),
        strip_rownames(rsample::analysis(ref_inner$splits[[j]]))
      )
      testthat::expect_equal(
        strip_rownames(rsample::assessment(lean_inner$splits[[j]])),
        strip_rownames(rsample::assessment(ref_inner$splits[[j]]))
      )
    }
  }
}

expect_outer_identical <- function(lean, ref) {
  testthat::expect_equal(nrow(lean), nrow(ref))
  testthat::expect_equal(lean$id, ref$id)
  for (i in seq_len(nrow(ref))) {
    testthat::expect_equal(
      strip_rownames(rsample::analysis(lean$splits[[i]])),
      strip_rownames(rsample::analysis(ref$splits[[i]]))
    )
    testthat::expect_equal(
      strip_rownames(rsample::assessment(lean$splits[[i]])),
      strip_rownames(rsample::assessment(ref$splits[[i]]))
    )
  }
}
