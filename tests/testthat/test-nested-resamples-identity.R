# AC2 -- the reference-implementation oracle (GP2, "live" type in the validation
# doctrine): rsample::nested_cv() is recomputed at test time and every inner
# analysis and assessment set must match it row for row under one seed.

test_that("inner splits match rsample::nested_cv() for a v-fold/v-fold scheme", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("inner splits match rsample::nested_cv() for a v-fold/bootstrap scheme", {
  d <- make_test_data()

  set.seed(7)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::bootstraps(times = 5))
  set.seed(7)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::bootstraps(times = 5))

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("inner splits match rsample::nested_cv() for a repeated outer scheme", {
  d <- make_test_data()

  set.seed(11)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 2, repeats = 2),
                            inside = rsample::vfold_cv(v = 3))
  set.seed(11)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 2, repeats = 2),
                           inside = rsample::vfold_cv(v = 3))

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("an already-evaluated outer rset is accepted and matches", {
  d <- make_test_data()

  set.seed(3)
  outer <- rsample::vfold_cv(d, v = 3)
  set.seed(5)
  ref <- rsample::nested_cv(d, outside = outer, inside = rsample::vfold_cv(v = 4))
  set.seed(5)
  lean <- nested_resamples(d, outside = outer, inside = rsample::vfold_cv(v = 4))

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("the object is a drop-in: class and spec attributes match rsample's", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  # D-008: nestedtune's own class first, then rsample's whole class vector.
  expect_s3_class(lean, "nested_resamples")
  expect_identical(class(lean)[-1], class(ref))
  expect_identical(attr(lean, "outside"), attr(ref, "outside"))
  expect_identical(attr(lean, "inside"), attr(ref, "inside"))
  expect_true("inner_resamples" %in% names(lean))
})

test_that("row names diverge from rsample by design, and ours are the original rows", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  ref_rows <- rsample::analysis(ref$inner_resamples[[1]]$splits[[1]])
  lean_rows <- rsample::analysis(lean$inner_resamples[[1]]$splits[[1]])

  # rsample renumbers, so its row names are a 1..n prefix of the analysis frame.
  expect_identical(rownames(ref_rows), as.character(seq_len(nrow(ref_rows))))
  # nestedtune keeps the original row identity, which is strictly more
  # informative -- and is what makes it possible to check the mapping at all.
  expect_false(identical(rownames(lean_rows), rownames(ref_rows)))
  expect_identical(d[as.integer(rownames(lean_rows)), , drop = FALSE], lean_rows)
})
