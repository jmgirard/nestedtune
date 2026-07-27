# Plotting a nested_results.
#
# Both views derive every fact from the columns at plot time rather than from the
# counts stamped at construction, exactly as printing does: a subset's rows are
# their own run (IP4).
#
# Two properties are structural rather than cosmetic. Every *attempted* fold
# keeps its slot on the x axis and a fold that contributed nothing draws no
# point, so a figure lifted out of its console session still shows that the
# design fell short. And the marked estimate is read off the same
# `summarize_folds()` that `collect_metrics()` uses, never recomputed, so the
# plot and the summary cannot disagree about the number.

#' Plot a nested cross-validation result
#'
#' @description
#' Two views of a `nested_results` object, both drawing one point per outer
#' fold with the folds in design order.
#'
#' `type = "parameters"`, the default, shows what each outer fold's inner
#' tuning selected. A flat row of points means the folds agreed; points at
#' different heights mean they disagreed, and the tuning procedure is unstable
#' on this data — which averaging the metrics hides. This is the view nothing
#' else in the ecosystem offers.
#'
#' `type = "performance"` shows each outer fold's score on its held-out
#' assessment set, with a rule at the nested estimate: the same value
#' [collect_metrics()] reports.
#'
#' @param object A `nested_results` object from [nested_tune_grid()].
#' @param type Which view to draw: `"parameters"` (the default) or
#'   `"performance"`.
#' @param ... Not used.
#'
#' @return A `ggplot` object.
#'
#' @details
#' An outer fold that failed keeps its place on the x axis and draws no point,
#' as does a fold that completed without recording a value for a parameter.
#' Neither is imputed and neither is dropped from the axis, so the shortfall is
#' visible in the figure itself.
#'
#' The subtitle states how much of the requested design ran. Contribution is
#' counted per panel instead, because it differs between them: a panel says so
#' when fewer folds contributed to it than completed — `mtry (2 of 3 chose)`,
#' `rmse (from 2 folds)` — and an unqualified panel means every completed fold
#' contributed. A requested metric that no completed fold could score keeps an
#' empty panel rather than disappearing.
#'
#' The selected-value axis is numeric when every value drawn is a number, and
#' discrete otherwise — a single axis cannot be both, and character-valued
#' tuning parameters are ordinary. A fold that selected `NA` is a value on that
#' discrete axis rather than an absent point.
#'
#' @examplesIf rlang::is_installed(c("recipes", "yardstick"))
#' data(mtcars)
#'
#' rec <- recipes::step_pca(
#'   recipes::recipe(mpg ~ ., data = mtcars),
#'   recipes::all_predictors(),
#'   num_comp = tune::tune()
#' )
#' wf <- workflows::workflow(rec, parsnip::linear_reg())
#'
#' set.seed(1)
#' folds <- nested_resamples(
#'   mtcars,
#'   outside = rsample::vfold_cv(v = 3),
#'   inside = rsample::vfold_cv(v = 3)
#' )
#'
#' set.seed(2)
#' res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
#'
#' autoplot(res)
#' autoplot(res, type = "performance")
#'
#' @seealso [nested_tune_grid()], [print.nested_results()], [collect_metrics()]
#' @importFrom rlang .data
#' @export
autoplot.nested_results <- function(object,
                                    type = c("parameters", "performance"),
                                    ...) {
  type <- check_plot_type(type)
  check_any_completed(object, action = "plot")

  switch(
    type,
    parameters = plot_selection(object),
    performance = plot_performance(object)
  )
}

plot_selection <- function(x, call = rlang::caller_env()) {
  frame <- selection_frame(x)
  if (is.null(frame)) {
    cli::cli_abort(
      c(
        "There are no tuned parameters to plot.",
        x = "No completed outer fold recorded a selected parameter.",
        i = "{.code autoplot(x, type = \"performance\")} draws the outer-fold \\
             scores instead."
      ),
      call = call
    )
  }

  ggplot2::ggplot(frame, ggplot2::aes(x = .data$fold, y = .data$value)) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::scale_x_discrete(drop = FALSE) +
    value_scale(frame$value) +
    ggplot2::facet_wrap(ggplot2::vars(.data$parameter), scales = "free_y") +
    ggplot2::labs(
      title = "Inner-loop selections across outer folds",
      # Two lines, because one does not fit a 7-inch device: a subtitle is not
      # wrapped for you, and a clipped caveat is worse than a short one.
      subtitle = paste0(
        design_line(x),
        "\nPoints at different heights in a panel mean the folds disagreed."
      ),
      x = "Outer fold",
      y = "Selected value"
    )
}

# The selected-value scale.
#
# A tuning parameter that only takes whole numbers -- `mtry`, `num_comp`,
# `min_n`, `trees`, most of the grid a user tunes over -- must not be given
# fractional breaks: unanimity collapses the range to nothing, and the default
# breaks then label a flat row of identical choices 2.950, 2.975, 3.000, which
# reads as disagreement at the third decimal place. Whole-number breaks label it
# 3, which is what happened.
#
# The decision is per panel and never over the pooled column. `facet_wrap(scales
# = "free_y")` trains one scale per panel but shares a single breaks function,
# calling it with each panel's own limits -- so one continuous parameter judged
# globally put every *other* panel back on fractional breaks, which is how the
# defect this exists to fix came back for any grid mixing an integer parameter
# with a continuous one (M08 review F3). Judging by panel needs no panel identity:
# a panel's limits are trained on its own parameter's values, so the drawn values
# that fall inside them are the ones that panel is about.
value_scale <- function(values) {
  if (!is.numeric(values)) {
    return(NULL)
  }
  whole <- !is.na(values) & values == trunc(values)
  if (!any(whole)) {
    return(NULL)
  }
  ggplot2::scale_y_continuous(breaks = panel_breaks(values))
}

panel_breaks <- function(values) {
  function(limits) {
    inside <- values[!is.na(values) &
                       values >= limits[[1L]] & values <= limits[[2L]]]
    if (length(inside) == 0L || !all(inside == trunc(inside))) {
      # `pretty()` rather than ggplot2's own default, which lives in `scales` and
      # would be an undeclared namespace to reach for. The two agree closely, and
      # this branch is only reached by a continuous parameter sharing a figure
      # with a whole-number one.
      return(pretty(limits))
    }
    whole_number_breaks(limits)
  }
}

whole_number_breaks <- function(limits) {
  candidates <- unique(round(pretty(limits)))
  candidates[candidates >= floor(limits[[1L]]) &
               candidates <= ceiling(limits[[2L]])]
}

plot_performance <- function(x) {
  per_fold <- per_fold_metrics(x)
  summarized <- summarize_folds(per_fold)
  ambiguous <- ambiguous_metrics(summarized)
  bases <- metric_panel(summarized$.metric, summarized$.estimator, ambiguous)
  # The qualifier goes on the panel, exactly where print puts it: a metric
  # averaged over fewer folds than completed says so on its own line, "where the
  # heading would be wrong for it alone" (R/nested-results-print.R:229). One
  # figure-level count cannot be true of every panel, and claiming otherwise is
  # what made the subtitle assert a three-fold estimate for a two-fold number
  # (M08 review F1).
  panels <- qualify_panels(bases, summarized$n, sum(x$.completed), from_folds)

  # A fold can complete and still score NA on one metric while scoring the
  # others -- an outer assessment set with one class gives roc_auc = NA. It
  # contributed nothing to that metric, so it draws no point there, and the
  # metric's own rule already averages only the folds that did contribute.
  scored <- !is.na(per_fold$.estimate)
  scored_panels <- panels[match(
    metric_panel(per_fold$.metric[scored], per_fold$.estimator[scored], ambiguous),
    bases
  )]
  points <- new_tbl(list(
    fold = factor(per_fold$id[scored], levels = fold_ids(x)),
    score = per_fold$.estimate[scored],
    metric = factor(scored_panels, levels = panels)
  ))

  estimated <- !is.na(summarized$mean)
  rules <- new_tbl(list(
    metric = factor(panels[estimated], levels = panels),
    mean = summarized$mean[estimated]
  ))

  ggplot2::ggplot(points, ggplot2::aes(x = .data$fold, y = .data$score)) +
    ggplot2::geom_hline(
      data = rules,
      mapping = ggplot2::aes(yintercept = .data$mean),
      linetype = "dashed"
    ) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::scale_x_discrete(drop = FALSE) +
    # `drop = FALSE` for the same reason the fold axis carries it: a metric that
    # was requested keeps its panel even when no completed fold could score it,
    # rather than vanishing with no trace that it had been asked for. It also
    # makes the nothing-scored-anywhere figure build instead of failing inside
    # ggplot2 on an empty faceting variable (M08 review F4).
    ggplot2::facet_wrap(
      ggplot2::vars(.data$metric), scales = "free_y", drop = FALSE
    ) +
    ggplot2::labs(
      title = "Nested cross-validation estimate",
      # IP3, and the reason this line is in the subtitle rather than in the help
      # page: ggplot2 renders a subtitle into the image, so the caveat survives
      # the figure being exported into a slide or a paper, where the console
      # session and the documentation do not travel with it.
      subtitle = paste0(
        design_line(x),
        " The line marks the nested estimate.\nIt describes the tune-and-fit ",
        "procedure, not a model you can deploy."
      ),
      x = "Outer fold",
      y = "Score on the held-out outer fold"
    )
}

# How much of the requested design ran. Derived from the columns, as printing
# derives it, so a subset says what is true of the rows in hand (IP4).
#
# It deliberately claims nothing about what contributed to any one panel: that
# count differs per metric and per parameter, and a figure-level sentence
# asserting it was wrong whenever they differed. The panels carry it instead.
design_line <- function(x) {
  requested <- nrow(x)
  paste0(
    requested, " outer fold", if (requested == 1L) "" else "s",
    " requested, ", sum(x$.completed), " completed."
  )
}

# A panel label, qualified only when that panel drew fewer folds than the run
# completed. An unqualified label therefore means "all of them", and the usual
# figure -- where nothing was lost -- carries no qualifier at all.
qualify_panels <- function(bases, contributed, completed, qualifier) {
  short <- contributed != completed
  out <- bases
  out[short] <- paste0(
    bases[short], " (", qualifier(contributed[short], completed), ")"
  )
  out
}

# The two views phrase the qualifier differently because they are counting
# different things: how many folds a metric's estimate came from, and how many
# folds chose a value for a parameter at all.
from_folds <- function(k, completed) {
  paste0("from ", k, " fold", ifelse(k == 1L, "", "s"))
}

chose_value <- function(k, completed) {
  paste0(k, " of ", completed, " chose")
}

# The panel a metric's scores sit in. Two estimators for the same metric would
# otherwise share a panel and be marked with two rules; the estimator joins the
# label exactly when it has to, so the usual plot is not cluttered by it.
metric_panel <- function(metric, estimator, ambiguous) {
  ifelse(
    metric %in% ambiguous,
    paste0(metric, " (", estimator, ")"),
    metric
  )
}

ambiguous_metrics <- function(summarized) {
  counts <- table(summarized$.metric)
  names(counts)[counts > 1L]
}

# The tidy frame behind the parameters view: one row per fold-and-parameter the
# design actually produced a value for.
#
# Fold labels are a factor over every *attempted* fold in design order, so the
# scale keeps a slot for one that drew no point. Parameters come from the union
# across completed folds, as printing takes them, so a parameter only some folds
# carry is still shown.
selection_frame <- function(x) {
  ids <- fold_ids(x)
  params <- selection_params(x$.selected[x$.completed])
  if (length(params) == 0L) {
    return(NULL)
  }

  fold <- character(0)
  parameter <- character(0)
  values <- list()
  chose <- integer(0)
  for (param in params) {
    raw <- selection_raw(x$.selected, param)
    present <- !vapply(raw, is.null, logical(1))
    fold <- c(fold, ids[present])
    parameter <- c(parameter, rep(param, sum(present)))
    values <- c(values, unname(raw[present]))
    chose <- c(chose, sum(present))
  }
  if (length(values) == 0L) {
    return(NULL)
  }

  # A parameter that only some completed folds chose a value for says so on its
  # own panel. Without it a flat row of two agreeing folds, under a figure-level
  # sentence counting three, read as three folds agreeing -- the false-agreement
  # mirror of the false-instability flag print treats as its worst output
  # (M08 review F2).
  panels <- qualify_panels(params, chose, sum(x$.completed), chose_value)

  new_tbl(list(
    fold = factor(fold, levels = ids),
    parameter = factor(panels[match(parameter, params)], levels = panels),
    value = selection_axis(values)
  ))
}

# One fold's value for a parameter, or NULL where it has none.
#
# `.selected` is a list column of one-row tibbles, so a value is reached through
# the element and never with `$` on the column: `x$.selected$num_comp` answers
# NULL rather than erroring, and a caller that believed it rendered "0 distinct
# values" and built perfectly cleanly (M06).
#
# A fold that failed carries NULL, and a completed fold's selection may simply
# have no such column. Both are "no value", and neither may be drawn.
selection_raw <- function(selected, param) {
  lapply(selected, function(s) {
    if (is.null(s) || !param %in% names(s)) {
      return(NULL)
    }
    value <- s[[param]][[1L]]
    if (length(value) != 1L) {
      return(paste(format(value), collapse = ", "))
    }
    value
  })
}

# The y aesthetic for the parameters view.
#
# One column carries one type and a facetted panel cannot mix a numeric axis
# with a discrete one, so the axis is numeric only when every value drawn is a
# number. Anything else -- a character-valued parameter, or a fold that selected
# NA, which printing treats as a value rather than an absence -- puts every
# panel on a discrete axis. Its levels are ordered numerically where the strings
# are numbers, so a discrete fallback does not sort 10 before 3.
selection_axis <- function(values) {
  numeric_only <- vapply(
    values,
    function(v) is.numeric(v) && length(v) == 1L && !is.na(v),
    logical(1)
  )
  if (all(numeric_only)) {
    return(vapply(values, as.numeric, numeric(1)))
  }

  labels <- vapply(
    values,
    function(v) paste(format(v), collapse = ", "),
    character(1)
  )
  unique_labels <- unique(labels)
  as_number <- suppressWarnings(as.numeric(unique_labels))
  factor(
    labels,
    levels = unique_labels[order(as_number, unique_labels, na.last = TRUE)]
  )
}
