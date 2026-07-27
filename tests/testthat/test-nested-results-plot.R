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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
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
  res <- memoised(nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4),
    grid = unstable_grid(), metrics = reg_metrics()
  ))
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
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  )))
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
  res <- drop_selection(memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  )))
  p <- autoplot(res)

  # Distinct from the failed fold above: this one ran. It still draws no point,
  # because a point at any height would be a selection it never made.
  expect_identical(axis_labels(p), c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_points(p)$fold, c("Fold1", "Fold3"))
})

test_that("the parameters view states how much of the design ran", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  whole <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  )))

  # A design fact, true of the whole figure however its panels differ: the
  # subtitle claims nothing about per-panel contribution, which is what it got
  # wrong before (F1/F2).
  expect_match(
    plot_label(autoplot(whole), "subtitle"),
    "3 outer folds requested, 3 completed"
  )
  expect_match(
    plot_label(autoplot(partial), "subtitle"),
    "3 outer folds requested, 2 completed"
  )
})

test_that("a panel says so when fewer folds contributed to it than completed", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

  # Every completed fold chose, so nothing is qualified: the common plot stays
  # uncluttered and a bare label means "all of them".
  expect_identical(strip_labels(autoplot(res)), "num_comp")
  expect_identical(
    strip_labels(autoplot(res, type = "performance")),
    c("rmse", "rsq")
  )

  # A completed fold that recorded no value for the parameter. Two folds chose,
  # and they agree -- so the flat row must not be readable as three agreeing.
  # print says "all 2 folds that chose it agree; 1 recorded no value"; the panel
  # is where the plot can say the same thing (F2).
  expect_identical(strip_labels(autoplot(drop_selection(res))),
                   "num_comp (2 of 3 chose)")

  # A fold that completed but scored NA on one metric only. print puts
  # "(from 2 folds)" on that metric's own line; so does the panel (F1).
  one_na <- res
  rmse_row <- one_na$.metrics[[2L]]$.metric == "rmse"
  one_na$.metrics[[2L]]$.estimate[rmse_row] <- NA_real_
  expect_identical(
    strip_labels(autoplot(one_na, type = "performance")),
    c("rmse (from 2 folds)", "rsq")
  )
})

test_that("each panel decides its own breaks", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  # A whole-number parameter beside a continuous one, which is what glmnet,
  # xgboost and svm_rbf all look like. Deciding over the pooled column put the
  # integer panel back on 2.950/2.975/3.000 -- the defect the single-parameter
  # fix claimed to have closed (F3).
  mixed <- res
  for (i in seq_len(nrow(mixed))) {
    mixed$.selected[[i]]$penalty <- c(0.001, 0.02, 0.3)[[i]]
  }
  p <- autoplot(mixed)

  expect_identical(strip_labels(p), c("num_comp", "penalty"))
  expect_identical(axis_labels(p, "y", panel = 1L), "3")
  expect_true(any(grepl(".", axis_labels(p, "y", panel = 2L), fixed = TRUE)))

  # The harder case, and the one the disjoint fixture above cannot see: the
  # continuous parameter's values fall *inside* the integer parameter's range, so
  # "which pooled values are in these limits" no longer identifies the panel.
  # Asking that question rather than which parameter owns the panel put
  # 2.0/2.5/3.0/3.5/4.0 back on an axis whose only values are 2, 3 and 4.
  overlapping <- res
  for (i in seq_len(nrow(overlapping))) {
    overlapping$.selected[[i]]$num_comp <- c(2L, 3L, 4L)[[i]]
    overlapping$.selected[[i]]$degree <- c(2.5, 2.7, 3.5)[[i]]
  }
  q <- autoplot(overlapping)

  expect_identical(strip_labels(q), c("num_comp", "degree"))
  expect_identical(axis_labels(q, "y", panel = 1L), c("2", "3", "4"))
  expect_true(any(grepl(".", axis_labels(q, "y", panel = 2L), fixed = TRUE)))
})

test_that("a metric no fold could score keeps its panel", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

  # roc_auc on a one-class assessment set reaches this routinely. The metric was
  # requested, so it keeps its panel as a failed fold keeps its axis slot --
  # dropping it left no trace that it had been asked for (F4).
  none <- res
  for (i in seq_len(nrow(none))) {
    rmse_row <- none$.metrics[[i]]$.metric == "rmse"
    none$.metrics[[i]]$.estimate[rmse_row] <- NA_real_
  }
  p <- autoplot(none, type = "performance")

  expect_identical(strip_labels(p), c("rmse (from 0 folds)", "rsq"))
  expect_identical(plot_points(p)$panel, rep("rsq", 3L))

  # And with nothing scored anywhere, the figure builds AND draws: it used to
  # return a ggplot that errored from inside ggplot2 when printed, which is
  # neither our own condition nor near the call that caused it.
  nothing <- res
  for (i in seq_len(nrow(nothing))) nothing$.metrics[[i]]$.estimate <- NA_real_
  empty <- autoplot(nothing, type = "performance")
  expect_s3_class(empty, "ggplot")
  # Laying the figure out is where it used to fail, so the assertion has to go
  # that far -- onto a null device, since letting one open by default writes an
  # Rplots.pdf at the package root and R CMD check NOTEs it.
  expect_no_error(on_null_device(ggplot2::ggplot_gtable(ggplot2::ggplot_build(empty))))
})

test_that("two estimators for one metric get a panel each", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  # Rare, but a metric reported under two estimators would otherwise share one
  # panel and be marked with two rules -- one of them wrong for every point
  # beside it.
  for (i in seq_len(nrow(res))) {
    m <- res$.metrics[[i]]
    extra <- m[m$.metric == "rsq", ]
    extra$.estimator <- "trad"
    extra$.estimate <- extra$.estimate / 2
    res$.metrics[[i]] <- rbind(m, extra)
  }
  p <- autoplot(res, type = "performance")

  expect_identical(
    strip_labels(p),
    c("rmse", "rsq (standard)", "rsq (trad)")
  )
  expect_identical(nrow(plot_rules(p)), 3L)
  expect_identical(plot_rules(p)$yintercept, collect_metrics(res)$mean)
})

test_that("the parameters view is the default and both views are ggplots", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  p <- autoplot(res, type = "performance")

  # IP3, in the subtitle rather than only in the help page: ggplot2 renders a
  # subtitle into the image, so the caveat travels with a figure that has been
  # exported out of the session that produced it.
  subtitle <- plot_label(p, "subtitle")
  expect_match(subtitle, "3 outer folds requested, 3 completed")
  expect_match(subtitle, "nested estimate")
  expect_match(subtitle, "not a model you can deploy", fixed = TRUE)
  expect_match(plot_label(p, "y"), "held-out outer fold")
})

test_that("a failed fold keeps its slot and contributes no score", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  )))
  p <- autoplot(res, type = "performance")
  rules <- plot_rules(p)

  expect_identical(axis_labels(p), c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_points(p)$fold, rep(c("Fold1", "Fold3"), each = 2L))
  expect_match(plot_label(p, "subtitle"), "3 outer folds requested, 2 completed")
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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  # An outer assessment set with one class gives roc_auc = NA, so a fold can
  # complete and score on some metrics but not all. Staged here rather than
  # engineered, because a fixture that reaches it naturally would have to be a
  # classification design built for this one row.
  rmse_row <- res$.metrics[[2L]]$.metric == "rmse"
  res$.metrics[[2L]]$.estimate[rmse_row] <- NA_real_

  p <- autoplot(res, type = "performance")
  pts <- plot_points(p)

  # The rmse panel carries its own count, since two folds contributed to it
  # where three completed; rsq is unqualified because all three did.
  expect_identical(
    pts$fold[pts$panel == "rmse (from 2 folds)"], c("Fold1", "Fold3")
  )
  expect_identical(pts$fold[pts$panel == "rsq"], c("Fold1", "Fold2", "Fold3"))
  expect_identical(plot_rules(p)$yintercept, collect_metrics(res)$mean)
})

test_that("a run where no fold completed is refused, in plotting's own words", {
  skip_if_no_engines()
  d <- make_reg_data()

  set.seed(2)
  res <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_every_fold(det_nested(d)),
    grid = det_grid(), metrics = reg_metrics()
  )))

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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))

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
  agreed <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
  set.seed(2)
  split <- memoised(nested_tune_grid(
    unstable_workflow(u), det_nested(u, v = 4),
    grid = unstable_grid(), metrics = reg_metrics()
  ))
  set.seed(2)
  partial <- suppressWarnings(memoised(nested_tune_grid(
    det_workflow(d), break_fold(det_nested(d), 2L, "outer fit"),
    grid = det_grid(), metrics = reg_metrics()
  )))

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
  res <- memoised(nested_tune_grid(
    det_workflow(d), det_nested(d), grid = det_grid(), metrics = reg_metrics()
  ))
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
