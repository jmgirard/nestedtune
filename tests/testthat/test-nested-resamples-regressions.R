# Regressions found by the M01 review fan-out. Each test fails against the
# implementation as it stood when the review ran.

test_that("a prebuilt `outside` rset built on other data is refused (IP1)", {
  d1 <- data.frame(x = 1:40, tag = paste0("A", 1:40))
  set.seed(9)
  d2 <- d1[sample(40), ]
  rownames(d2) <- NULL

  set.seed(1)
  outer <- rsample::vfold_cv(d1, v = 2)

  # Silently remapping d1's indices onto d2 put rows from the outer assessment
  # set into inner analysis sets -- 22 of them, where rsample leaks none.
  expect_error(
    nested_resamples(d2, outside = outer, inside = rsample::vfold_cv(v = 2)),
    "was built on different data"
  )

  # A row-count mismatch used to construct fine and only fail later, on
  # retrieval, with an out-of-range error naming nothing the user typed.
  expect_error(
    nested_resamples(
      d1[1:20, ],
      outside = outer,
      inside = rsample::vfold_cv(v = 2)
    ),
    "was built on different data"
  )

  # The legitimate case still works: same data, prebuilt rset.
  set.seed(5)
  expect_no_error(
    nested_resamples(d1, outside = outer, inside = rsample::vfold_cv(v = 2))
  )
})

test_that("no inner analysis row ever comes from the outer assessment set (IP1)", {
  d <- make_test_data()
  d$tag <- paste0("row", seq_len(nrow(d)))

  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 4)
  )

  for (i in seq_len(nrow(lean))) {
    # Compare by row content, not by index: indices alone cannot detect a
    # remapping onto the wrong frame.
    outer_assessment <- rsample::assessment(lean$splits[[i]])$tag
    for (split in lean$inner_resamples[[i]]$splits) {
      expect_length(
        intersect(rsample::analysis(split)$tag, outer_assessment),
        0
      )
      expect_length(
        intersect(rsample::assessment(split)$tag, outer_assessment),
        0
      )
    }
  }
})

test_that("inner rsplit objects match rsample's in class and structure", {
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

    for (j in seq_along(ref$inner_resamples[[1]]$splits)) {
      ref_split <- ref$inner_resamples[[1]]$splits[[j]]
      lean_split <- lean$inner_resamples[[1]]$splits[[j]]

      # The oracle used to stop at analysis()/assessment(), which is why the
      # split objects were free to diverge underneath.
      expect_identical(class(lean_split), class(ref_split))
      expect_identical(names(lean_split), names(ref_split))
      expect_identical(lean_split$id, ref_split$id)
      expect_identical(labels(lean_split), labels(ref_split))
    }
  }
})

test_that("inner splits carry resample ids that tidymodels can attach", {
  d <- make_test_data()

  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 2, repeats = 2)
  )
  split <- lean$inner_resamples[[1]]$splits[[3]]

  # add_resample_id() is how tidymodels labels per-resample predictions; it
  # errored on a split with no $id element.
  labelled <- rsample::add_resample_id(data.frame(a = 1), split)
  expect_true(all(c("id", "id2") %in% names(labelled)))
  expect_identical(nrow(labelled), 1L)
})
