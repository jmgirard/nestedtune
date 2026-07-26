# IP2 -- reproducible results. M01 ships no parallelism, so the parallel half of
# IP2 has nothing to bind yet; what is checkable here is that the seed fully
# determines the object, that it genuinely determines it (a constructor that
# ignored the seed would pass a same-seed test trivially), and that fidelity to
# rsample extends to how much randomness is consumed.

test_that("the same seed produces the same object", {
  d <- make_test_data()

  set.seed(99)
  first <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(99)
  second <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                             inside = rsample::vfold_cv(v = 4))

  expect_identical(first, second)
})

test_that("a different seed produces different splits", {
  d <- make_test_data()

  set.seed(99)
  first <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(100)
  other <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))

  expect_false(identical(
    first$inner_resamples[[1]]$splits[[1]]$in_id,
    other$inner_resamples[[1]]$splits[[1]]$in_id
  ))
})

test_that("the same amount of randomness is consumed as rsample::nested_cv()", {
  d <- make_test_data()

  set.seed(1)
  invisible(rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                               inside = rsample::vfold_cv(v = 4)))
  after_ref <- .Random.seed

  set.seed(1)
  invisible(nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                             inside = rsample::vfold_cv(v = 4)))
  after_lean <- .Random.seed

  # Not just the same splits: the RNG stream is left in the same place, so a
  # seeded script that does anything after this call is unaffected by the swap.
  expect_identical(after_lean, after_ref)
})

test_that("no analysis frame is retained -- every split shares the caller's data", {
  skip_if_not_installed("lobstr")
  d <- make_test_data()

  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  # identical() would be satisfied by a copy; the address is what distinguishes
  # a shared reference from one more materialized frame per fold.
  data_addr <- lobstr::obj_addr(d)
  for (i in seq_len(nrow(lean))) {
    for (split in lean$inner_resamples[[i]]$splits) {
      expect_identical(lobstr::obj_addr(split$data), data_addr)
    }
  }
})

test_that("indices land on the original data, not on a per-fold renumbering", {
  d <- make_test_data()

  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  for (i in seq_len(nrow(lean))) {
    outer_idx <- as.integer(lean$splits[[i]]$in_id)
    for (split in lean$inner_resamples[[i]]$splits) {
      inner_idx <- as.integer(split$in_id)
      # Every inner index is a row of the original data, and specifically one
      # the outer fold put in its analysis set -- which is IP1 at this layer.
      expect_true(all(inner_idx >= 1L & inner_idx <= nrow(d)))
      expect_true(all(inner_idx %in% outer_idx))
      expect_true(all(as.integer(rsample::complement(split)) %in% outer_idx))
    }
  }
})
