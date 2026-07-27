# Plotting a nested_results object (M08).
#
# No oracle is recorded here, deliberately. The plot produces no numeric result
# of its own: every number it draws was computed and oracle-verified upstream
# (M02's estimate, M04's selections), and what these tests pin is that the plot
# reproduces those numbers without distorting or inventing them -- an internal
# consistency check, not a claim about the world. The one equality that could be
# mistaken for an oracle, the marked estimate against collect_metrics(), is
# asserted for exactly that reason: the two must never be able to disagree.

test_that("the parameters view draws one point per completed fold", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  pts <- plot_points(autoplot(res, type = "parameters"))

  selected <- as.numeric(vapply(res$.selected, function(s) s$num_comp, integer(1)))

  expect_identical(pts$fold, c("Fold1", "Fold2", "Fold3"))
  expect_identical(unique(pts$panel), "num_comp")
  expect_identical(pts$y, selected)
  # This fixture's folds agree, so agreement is a flat row: one value, three
  # points. The disagreement case below is the same assertion with scatter.
  expect_length(unique(pts$y), 1L)
})

test_that("folds that disagree are drawn at their own values, keyed by fold", {
  skip_if_no_engines()
  u <- unstable_data()

  set.seed(2)
  res <- nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4),
    grid = unstable_grid(), metrics = reg_metrics()
  )
  pts <- plot_points(autoplot(res))

  # The fixture's folds land on 4, 4, 4, 3 (the same disagreement M04's print
  # tests read). Position identifies the fold, so the values are asserted in
  # fold order -- a plot that drew the right four values in the wrong order
  # would pass a set comparison and fail this.
  expect_identical(pts$fold, c("Fold1", "Fold2", "Fold3", "Fold4"))
  expect_identical(pts$y, c(4, 4, 4, 3))
})

test_that("a failed fold keeps its place on the axis and draws no point", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))
  p <- autoplot(res)

  # IP4: the fold that did not run is on the axis, so the shortfall is visible
  # in the figure itself and not only in the count -- but it contributes no
  # point, so nothing is imputed for it.
  expect_identical(axis_labels(p), c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_points(p)$fold, c("Fold1", "Fold3"))
})

test_that("a completed fold with no value for a parameter is not imputed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- drop_selection(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  p <- autoplot(res)

  # Distinct from the failed fold above: this one ran. It still draws no point,
  # because a point at any height would be a selection it never made.
  expect_identical(axis_labels(p), c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_points(p)$fold, c("Fold1", "Fold3"))
})

test_that("the parameters view states how many folds contributed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  whole <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  set.seed(2)
  partial <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))

  expect_match(plot_label(autoplot(whole), "subtitle"), "3 of 3 outer folds")
  expect_match(plot_label(autoplot(partial), "subtitle"), "2 of 3 outer folds")
})

test_that("the parameters view is the default and both views are ggplots", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )

  # A bare autoplot() dispatches: the generic is re-exported, so a user who has
  # loaded only nestedtune reaches the method without namespacing it.
  expect_s3_class(autoplot(res), "ggplot")
  expect_s3_class(autoplot(res, type = "performance"), "ggplot")
  expect_identical(
    plot_points(autoplot(res)),
    plot_points(autoplot(res, type = "parameters"))
  )
})

test_that("the performance view draws one point per fold and metric", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  pts <- plot_points(autoplot(res, type = "performance"))

  expect_identical(sort(unique(pts$panel)), c("rmse", "rsq"))
  expect_identical(
    pts$fold,
    rep(c("Fold1", "Fold2", "Fold3"), each = 2L)
  )
  expect_identical(pts$y, collect_metrics(res, summarize = FALSE)$.estimate)
})

test_that("the marked estimate is the number collect_metrics reports", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  rules <- plot_rules(autoplot(res, type = "performance"))
  summary <- collect_metrics(res)

  # Exact, not approximate: the rule is read off the same summarize_folds() the
  # summary uses, so any difference at all means one of them recomputed it.
  expect_identical(rules$panel, summary$.metric)
  expect_identical(rules$yintercept, summary$mean)
})

test_that("the performance view says the estimate is not a model's score", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  p <- autoplot(res, type = "performance")

  # IP3, in the subtitle rather than only in the help page: ggplot2 renders a
  # subtitle into the image, so the caveat travels with a figure that has been
  # exported out of the session that produced it.
  subtitle <- plot_label(p, "subtitle")
  expect_match(subtitle, "3 of 3 outer folds")
  expect_match(subtitle, "nested estimate")
  expect_match(subtitle, "not a model you can deploy", fixed = TRUE)
  expect_match(plot_label(p, "y"), "held-out outer fold")
})

test_that("a failed fold keeps its slot and contributes no score", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))
  p <- autoplot(res, type = "performance")
  rules <- plot_rules(p)

  expect_identical(axis_labels(p), c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_points(p)$fold, rep(c("Fold1", "Fold3"), each = 2L))
  expect_match(plot_label(p, "subtitle"), "2 of 3 outer folds")
  # The rule averages the folds that ran, which is what the summary reports for
  # the same object -- neither claims the design that was requested (IP4).
  expect_identical(
    rules$yintercept,
    suppressWarnings(collect_metrics(res))$mean
  )
})

test_that("a fold scoring NA on one metric still scores the others", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  # An outer assessment set with one class gives roc_auc = NA, so a fold can
  # complete and score on some metrics but not all. Staged here rather than
  # engineered, because a fixture that reaches it naturally would have to be a
  # classification design built for this one row.
  rmse_row <- res$.metrics[[2L]]$.metric == "rmse"
  res$.metrics[[2L]]$.estimate[rmse_row] <- NA_real_

  p <- autoplot(res, type = "performance")
  pts <- plot_points(p)

  expect_identical(pts$fold[pts$panel == "rmse"], c("Fold1", "Fold3"))
  expect_identical(pts$fold[pts$panel == "rsq"], c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_rules(p)$yintercept, collect_metrics(res)$mean)
})

test_that("a run where no fold completed is refused, in plotting's own words", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_every_fold(det_nested(d)),
    grid = det_grid(), metrics = reg_metrics()
  ))

  # Printing describes such an object without complaint (M04); plotting is a
  # request for a figure of a design that did not run, so it refuses as
  # collect_metrics() does -- and says "plot", not "summarize", about the same
  # object.
  expect_error(autoplot(res), "nothing to plot")
  expect_error(autoplot(res, type = "performance"), "nothing to plot")
  expect_error(collect_metrics(res), "nothing to summarize")
})

test_that("a design with no tuned parameters points at the other view", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  for (i in seq_len(nrow(res))) {
    res$.selected[[i]] <- res$.selected[[i]][, ".config", drop = FALSE]
  }

  expect_error(autoplot(res), "no tuned parameters")
  expect_error(autoplot(res), "type = \"performance\"", fixed = TRUE)
  # The scores are still there, so the view it points at must actually work.
  expect_s3_class(autoplot(res, type = "performance"), "ggplot")
})

test_that("an unrecognized type is refused by name", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )

  expect_error(autoplot(res, type = "parameter"), "must be one of")
  expect_error(autoplot(res, type = "parameter"), "performance")
  expect_error(autoplot(res, type = c("performance", "parameters")), "one of")
  expect_error(autoplot(res, type = 1), "must be one of")
  expect_error(autoplot(res, type = NA_character_), "must be one of")
})

test_that("a whole-number parameter is not given fractional breaks", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )

  # This fixture's folds are unanimous, which collapses the value range to
  # nothing. The default breaks then label a flat row of identical integer
  # choices 2.950, 2.975, 3.000 -- a plot about disagreement inventing some.
  expect_identical(axis_labels(autoplot(res), "y"), "3")

  # A genuinely continuous parameter keeps the default breaks, because rounding
  # one would collapse every candidate of, say, `penalty` onto zero.
  continuous <- res
  for (i in seq_len(nrow(continuous))) {
    continuous$.selected[[i]]$num_comp <- continuous$.selected[[i]]$num_comp / 8
  }
  labels <- axis_labels(autoplot(continuous), "y")
  expect_true(any(grepl(".", labels, fixed = TRUE)))
})

# The pictures.
#
# Everything above asserts on the built plot, which is blind to the part a
# reader actually meets: where the labels sit, whether the caveat fits, what a
# gap looks like. These pin that, on the same deterministic fixtures. vdiffr
# skips itself on CRAN and wherever its rendering stack differs, so a failure
# here is a change in the figure and never a change in the machine.
test_that("both views look the way they read", {
  skip_if_not_installed("vdiffr")
  skip_if_no_engines()
  d <- make_reg_data()
  u <- unstable_data()

  set.seed(2)
  agreed <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  set.seed(2)
  split <- nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4),
    grid = unstable_grid(), metrics = reg_metrics()
  )
  set.seed(2)
  partial <- suppressWarnings(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  ))

  vdiffr::expect_doppelganger("parameters, folds agree", autoplot(agreed))
  vdiffr::expect_doppelganger("parameters, folds disagree", autoplot(split))
  # The gap where Fold2 sits is the whole point of keeping it on the axis, and
  # it is the one thing no assertion on the built data can see.
  vdiffr::expect_doppelganger("parameters, a fold failed", autoplot(partial))
  vdiffr::expect_doppelganger(
    "performance, folds agree",
    autoplot(agreed, type = "performance")
  )
})

test_that("a non-numeric selection is drawn on a discrete axis", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )
  # A character-valued parameter is ordinary in the ecosystem (`weight_func`,
  # `activation`), and one panel cannot mix a numeric axis with a discrete one.
  # Every selected value in the plot being numeric is what earns the numeric
  # axis; anything else falls back to a discrete one for all panels.
  for (i in seq_len(nrow(res))) {
    res$.selected[[i]]$num_comp <- paste0("c", res$.selected[[i]]$num_comp)
  }
  p <- autoplot(res)

  expect_s3_class(p, "ggplot")
  expect_identical(plot_points(p)$fold, c("Fold1", "Fold2", "Fold3"))
  expect_identical(axis_labels(p, "y"), "c3")
})
