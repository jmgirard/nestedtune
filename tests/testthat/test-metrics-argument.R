# The `metrics` argument reaches tune (M18).
#
# Nothing here asserted anything before M18: the suite's shared metric set is
# `metric_set(rmse, rsq)`, which IS tune's regression default, so every test
# passing it produced a run identical to one passing nothing. Deleting the
# argument from any call site left the suite green.
#
# These tests run on sep_* (helper-orchestration.R), a fixture built so that the
# caller's metric set and tune's default disagree about both the metric names
# and the selected candidate. The disagreement is the whole instrument, so the
# first test below asserts the fixture still has it -- without that, the other
# two would pass vacuously against a future tune whose defaults had changed,
# which is the failure mode this file exists to prevent.

test_that("the fixture separates the caller's metric set from tune's default", {
  skip_if_no_engines()

  d <- sep_data()
  wf <- sep_workflow(d)
  nested <- sep_nested(d)

  set.seed(20)
  mine <- nested_tune_grid(wf, nested, grid = sep_grid(), metrics = sep_metrics())
  set.seed(20)
  theirs <- nested_tune_grid(wf, nested, grid = sep_grid(), metrics = NULL)

  # Different metric names, so the outer .metrics column can tell them apart.
  expect_false(setequal(
    unique(unlist(lapply(mine$.metrics, function(m) m$.metric))),
    unique(unlist(lapply(theirs$.metrics, function(m) m$.metric)))
  ))
  # Different selections in every outer fold, so .selected can tell them apart
  # even though the inner tuning run is not retained on nested_results.
  mine_sel <- vapply(mine$.selected, function(s) s$num_comp, integer(1))
  theirs_sel <- vapply(theirs$.selected, function(s) s$num_comp, integer(1))
  expect_true(all(mine_sel != theirs_sel))
})

test_that("nested_tune_grid() scores the metrics it was given", {
  skip_if_no_engines()

  d <- sep_data()
  wf <- sep_workflow(d)
  nested <- sep_nested(d)

  set.seed(20)
  res <- nested_tune_grid(wf, nested, grid = sep_grid(), metrics = sep_metrics())

  for (i in seq_len(nrow(res))) {
    expect_identical(sort(res$.metrics[[i]]$.metric), c("mae", "rmse"))
  }
})

test_that("nested_tune_grid() selects under the metrics it was given", {
  skip_if_no_engines()

  d <- sep_data()
  wf <- sep_workflow(d)
  nested <- sep_nested(d)

  set.seed(20)
  res <- nested_tune_grid(wf, nested, grid = sep_grid(), metrics = sep_metrics())

  # The reference resolves the first metric of the caller's set, exactly as the
  # driver does off its own tuned object -- so this fails if the inner
  # tune_grid() ever stops receiving `metrics` and falls back to `rmse`.
  ref <- reference_nested_loop(
    wf, nested, sep_grid(), sep_metrics(), seed = 20, metric_name = "mae"
  )
  for (i in seq_len(nrow(res))) {
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
  }
})

test_that("nested_final_fit() tunes under the metrics it was given", {
  skip_if_no_engines()

  d <- sep_data()
  wf <- sep_workflow(d)
  nested <- sep_nested(d)

  set.seed(30)
  final <- nested_final_fit(wf, nested, grid = sep_grid(), metrics = sep_metrics())

  expect_identical(
    sort(unique(tune::collect_metrics(final$tuning)$.metric)),
    c("mae", "rmse")
  )
})
