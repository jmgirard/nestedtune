# AC2 -- the reference-implementation oracle (GP2, "live" type in the validation
# doctrine): rsample::nested_cv() is recomputed at test time and every inner
# analysis and assessment set must match it row for row under one seed.

test_that("inner splits match rsample::nested_cv() for a v-fold/v-fold scheme", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("inner splits match rsample::nested_cv() for a v-fold/bootstrap scheme", {
  d <- make_test_data()

  set.seed(7)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::bootstraps(times = 5)
  )
  set.seed(7)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::bootstraps(times = 5)
  )

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("inner splits match rsample::nested_cv() for a repeated outer scheme", {
  d <- make_test_data()

  set.seed(11)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2, repeats = 2),
    inside = rsample::vfold_cv(v = 3)
  )
  set.seed(11)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2, repeats = 2),
    inside = rsample::vfold_cv(v = 3)
  )

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("an already-evaluated outer rset is accepted and matches", {
  d <- make_test_data()

  set.seed(3)
  outer <- rsample::vfold_cv(d, v = 3)
  set.seed(5)
  ref <- rsample::nested_cv(
    d,
    outside = outer,
    inside = rsample::vfold_cv(v = 4)
  )
  set.seed(5)
  lean <- nested_resamples(
    d,
    outside = outer,
    inside = rsample::vfold_cv(v = 4)
  )

  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("the object is a drop-in: class and spec attributes match rsample's", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )

  # D-008: nestedtune's own class first, then rsample's whole class vector.
  expect_s3_class(lean, "nested_resamples")
  expect_identical(class(lean)[-1], class(ref))
  expect_identical(attr(lean, "outside"), attr(ref, "outside"))
  expect_identical(attr(lean, "inside"), attr(ref, "inside"))
  expect_true("inner_resamples" %in% names(lean))
})

test_that("inner rsets keep the class, id columns and attributes of their spec", {
  d <- make_test_data()

  specs <- list(
    quote(rsample::vfold_cv(v = 4)),
    quote(rsample::vfold_cv(v = 2, repeats = 2)),
    quote(rsample::bootstraps(times = 3))
  )

  for (spec in specs) {
    set.seed(1)
    ref <- eval(bquote(
      rsample::nested_cv(
        d,
        outside = rsample::vfold_cv(v = 2),
        inside = .(spec)
      )
    ))
    set.seed(1)
    lean <- eval(bquote(
      nested_resamples(d, outside = rsample::vfold_cv(v = 2), inside = .(spec))
    ))

    lean_inner <- lean$inner_resamples[[1]]
    ref_inner <- ref$inner_resamples[[1]]

    expect_identical(class(lean_inner), class(ref_inner))
    expect_identical(names(lean_inner), names(ref_inner))
    spec_attrs <- setdiff(
      names(attributes(ref_inner)),
      c("names", "row.names", "class", "fingerprint")
    )
    for (a in spec_attrs) {
      expect_identical(attr(lean_inner, a), attr(ref_inner, a))
    }
  }
})

test_that("a repeated inner spec keeps its id2 column", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 2, repeats = 2)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 2, repeats = 2)
  )

  expect_identical(lean$inner_resamples[[1]]$id2, ref$inner_resamples[[1]]$id2)
  expect_inner_identical(lean, ref)
})

test_that("the inner fingerprint is recomputed, not carried over from rsample", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 4)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 4)
  )

  # The splits index different things, so carrying rsample's hash over would be
  # a stale claim about an object it no longer describes.
  expect_false(identical(
    attr(lean$inner_resamples[[1]], "fingerprint"),
    attr(ref$inner_resamples[[1]], "fingerprint")
  ))
  expect_type(attr(lean$inner_resamples[[1]], "fingerprint"), "character")
})

test_that("retrieved frames are identical to rsample's down to their attributes", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )

  ref_rows <- rsample::analysis(ref$inner_resamples[[1]]$splits[[1]])
  lean_rows <- rsample::analysis(lean$inner_resamples[[1]]$splits[[1]])

  # The two objects index different things -- rsample a materialized analysis
  # frame, nestedtune the original data -- but analysis() renumbers row names on
  # retrieval, so nothing about that choice is observable in the result.
  expect_identical(lean_rows, ref_rows)
  expect_identical(attributes(lean_rows), attributes(ref_rows))

  # The indices really are into the original data, not a copy of it.
  lean_split <- lean$inner_resamples[[1]]$splits[[1]]
  expect_equal(
    d[as.integer(lean_split$in_id), , drop = FALSE],
    lean_rows,
    ignore_attr = "row.names"
  )
})
