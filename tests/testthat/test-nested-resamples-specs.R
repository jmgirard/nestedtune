# AC5 -- stratified and grouped specifications. Transient materialization hands
# the inner specification the real analysis frame, so the columns it references
# are present and these need no special handling; that is what these tests
# check, rather than assuming it.

test_that("a stratified inner spec matches rsample::nested_cv()", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4, strata = strat))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4, strata = strat))

  expect_inner_identical(lean, ref)
})

test_that("a grouped inner spec matches rsample::nested_cv()", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::group_vfold_cv(group = grp, v = 4)
  )
  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::group_vfold_cv(group = grp, v = 4)
  )

  expect_inner_identical(lean, ref)
})

test_that("a grouped inner spec keeps groups whole within each inner split", {
  d <- make_test_data()

  set.seed(1)
  lean <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::group_vfold_cv(group = grp, v = 4)
  )

  for (i in seq_len(nrow(lean))) {
    for (split in lean$inner_resamples[[i]]$splits) {
      in_groups <- unique(d$grp[as.integer(split$in_id)])
      out_groups <- unique(d$grp[as.integer(rsample::complement(split))])
      # The remapping is index arithmetic, so a group leaking across the inner
      # boundary is the failure it could plausibly produce.
      expect_length(intersect(in_groups, out_groups), 0)
    }
  }
})

test_that("stratified and grouped outer specs match rsample::nested_cv()", {
  d <- make_test_data()

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3, strata = strat),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3, strata = strat),
                           inside = rsample::vfold_cv(v = 4))
  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::group_vfold_cv(group = grp, v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::group_vfold_cv(group = grp, v = 3),
                           inside = rsample::vfold_cv(v = 4))
  expect_outer_identical(lean, ref)
  expect_inner_identical(lean, ref)
})

test_that("character and factor stratification behave the same", {
  d <- make_test_data()
  d$strat_chr <- as.character(d$strat)

  set.seed(1)
  by_factor <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                                inside = rsample::vfold_cv(v = 4, strata = strat))
  set.seed(1)
  by_character <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                                   inside = rsample::vfold_cv(v = 4, strata = strat_chr))

  expect_identical(
    by_factor$inner_resamples[[1]]$splits[[1]]$in_id,
    by_character$inner_resamples[[1]]$splits[[1]]$in_id
  )
})

test_that("rows carrying NA are resampled, not dropped", {
  d <- make_test_data()
  d$x[c(3, 17, 88)] <- NA_real_

  set.seed(1)
  ref <- rsample::nested_cv(d, outside = rsample::vfold_cv(v = 3),
                            inside = rsample::vfold_cv(v = 4))
  set.seed(1)
  lean <- nested_resamples(d, outside = rsample::vfold_cv(v = 3),
                           inside = rsample::vfold_cv(v = 4))

  expect_inner_identical(lean, ref)
  seen <- sort(unique(unlist(lapply(
    seq_len(nrow(lean)),
    function(i) as.integer(lean$splits[[i]]$in_id)
  ))))
  expect_identical(seen, seq_len(nrow(d)))
})


# Error branches. Each cli_abort() in nested_resamples() is fired here.

test_that("`data` must be a data frame", {
  expect_error(
    nested_resamples(1:10, outside = rsample::vfold_cv(v = 2),
                     inside = rsample::vfold_cv(v = 2)),
    "must be a data frame"
  )
})

test_that("`outside` must be a spec or an rset", {
  d <- make_test_data()
  not_an_rset <- 42

  expect_error(
    nested_resamples(d, outside = not_an_rset, inside = rsample::vfold_cv(v = 2)),
    "must be a resampling specification or an"
  )
})

test_that("an outer bootstrap is refused, as a call and as an object", {
  d <- make_test_data()

  expect_error(
    nested_resamples(d, outside = rsample::bootstraps(times = 3),
                     inside = rsample::vfold_cv(v = 2)),
    "cannot be a bootstrap"
  )

  # rsample only inspects the deparsed call, so a namespaced call or a
  # pre-built object slips past its warning; both are caught here.
  set.seed(1)
  boots <- rsample::bootstraps(d, times = 3)
  expect_error(
    nested_resamples(d, outside = boots, inside = rsample::vfold_cv(v = 2)),
    "cannot be a bootstrap"
  )
})

test_that("`inside` must be an expression, not an existing object", {
  d <- make_test_data()
  set.seed(1)
  built <- rsample::vfold_cv(d, v = 2)

  expect_error(
    nested_resamples(d, outside = rsample::vfold_cv(v = 2), inside = built),
    "must be an expression"
  )
})

# An `inside` specification that evaluates to something other than an rset used
# to build a design silently: `inner_resamples[[1]]` held whatever the call
# returned, and the first symptom was a crash inside pretty.default() at print
# time. The guard sits in the per-fold evaluation, so it covers every fold --
# checked below by a specification that turns bad only on a later one.

test_that("an `inside` spec that does not produce an rset is refused", {
  d <- make_test_data()

  expect_error(
    nested_resamples(d, outside = rsample::vfold_cv(v = 2), inside = list()),
    "did not produce an"
  )
})

test_that("the `inside` guard covers every outer fold, not just the first", {
  d <- make_test_data()

  # Keyed to the call count rather than to anything about the fold, so the
  # failure lands on the third fold whatever the outer split happens to be. A
  # guard that inspected only the first fold would return a design here.
  seen <- 0L
  flaky_inner <- function(data, ...) {
    seen <<- seen + 1L
    if (seen < 3L) rsample::vfold_cv(data, v = 2) else list()
  }

  expect_error(
    nested_resamples(d, outside = rsample::vfold_cv(v = 3), inside = flaky_inner()),
    "did not produce an"
  )
  # The first two folds evaluated cleanly, so the refusal came from the third.
  expect_identical(seen, 3L)
})

test_that("the refusal names the user's call, not an internal one", {
  d <- make_test_data()

  cnd <- tryCatch(
    nested_resamples(d, outside = rsample::vfold_cv(v = 2), inside = list()),
    error = function(e) e
  )
  expect_identical(conditionCall(cnd)[[1]], as.name("nested_resamples"))
})

# The data used to be inlined into the calls being evaluated, so any condition
# raised from one deparsed the whole frame into its message -- 1,194 characters
# on a 30x2 frame, and growing with the data. Binding it to a name instead makes
# the message a property of the specification alone.
#
# Both halves of the assertion are load-bearing. Equality alone passes today at
# larger sizes, because R truncates a condition message at 8,190 bytes and two
# truncated messages are equal; the length bound is what makes it fail.

test_that("a failing spec reports a message that does not carry the data", {
  small <- data.frame(a = rnorm(30), b = rnorm(30))
  large <- data.frame(a = rnorm(3000), b = rnorm(3000))

  msg <- function(data, which) {
    cnd <- tryCatch(
      if (identical(which, "outside")) {
        nested_resamples(data, outside = nrow(), inside = rsample::vfold_cv(v = 2))
      } else {
        nested_resamples(data, outside = rsample::vfold_cv(v = 2), inside = nrow())
      },
      error = function(e) e
    )
    conditionMessage(cnd)
  }

  for (which in c("outside", "inside")) {
    small_msg <- msg(small, which)
    expect_identical(small_msg, msg(large, which))
    expect_lt(nchar(small_msg), 500L)
  }
})

test_that("a zero-row data frame is refused by the underlying spec", {
  empty <- make_test_data()[0, , drop = FALSE]

  expect_error(
    nested_resamples(empty, outside = rsample::vfold_cv(v = 2),
                     inside = rsample::vfold_cv(v = 2)),
    "number of rows is less than"
  )
})

test_that("a single-row data frame is refused by the underlying spec", {
  one <- make_test_data()[1, , drop = FALSE]

  expect_error(
    nested_resamples(one, outside = rsample::vfold_cv(v = 2),
                     inside = rsample::vfold_cv(v = 2)),
    "number of rows is less than"
  )
})
