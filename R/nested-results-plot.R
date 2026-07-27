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
#' Neither is imputed and neither is dropped from the axis, so the gap says what
#' the subtitle's fold count says.
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
    ggplot2::facet_wrap(ggplot2::vars(.data$parameter), scales = "free_y") +
    ggplot2::labs(
      title = "Inner-loop selections across outer folds",
      subtitle = paste0(
        contributed(x, "a selection"),
        " Points at different heights in a panel mean the folds disagreed."
      ),
      x = "Outer fold",
      y = "Selected value"
    )
}

plot_performance <- function(x) {
  per_fold <- per_fold_metrics(x)
  summarized <- summarize_folds(per_fold)
  ambiguous <- ambiguous_metrics(summarized)
  panels <- metric_panel(summarized$.metric, summarized$.estimator, ambiguous)

  # A fold can complete and still score NA on one metric while scoring the
  # others -- an outer assessment set with one class gives roc_auc = NA. It
  # contributed nothing to that metric, so it draws no point there, and the
  # metric's own rule already averages only the folds that did contribute.
  scored <- !is.na(per_fold$.estimate)
  points <- new_tbl(list(
    fold = factor(per_fold$id[scored], levels = fold_ids(x)),
    score = per_fold$.estimate[scored],
    metric = factor(
      metric_panel(
        per_fold$.metric[scored], per_fold$.estimator[scored], ambiguous
      ),
      levels = panels
    )
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
    ggplot2::facet_wrap(ggplot2::vars(.data$metric), scales = "free_y") +
    ggplot2::labs(
      title = "Nested cross-validation estimate",
      # IP3, and the reason this line is in the subtitle rather than in the help
      # page: ggplot2 renders a subtitle into the image, so the caveat survives
      # the figure being exported into a slide or a paper, where the console
      # session and the documentation do not travel with it.
      subtitle = paste0(
        contributed(x, "a score"),
        " The line marks the nested estimate.\nIt describes the tune-and-fit ",
        "procedure, not a model you can deploy."
      ),
      x = "Outer fold",
      y = "Score on the held-out outer fold"
    )
}

# How much of the requested design is in the figure. Derived from the column, as
# printing derives it, so a subset says what is true of the rows in hand (IP4).
contributed <- function(x, what) {
  requested <- nrow(x)
  completed <- sum(x$.completed)
  paste0(
    completed, " of ", requested, " outer fold",
    if (requested == 1L) "" else "s", " contributed ", what, "."
  )
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
  for (param in params) {
    raw <- selection_raw(x$.selected, param)
    present <- !vapply(raw, is.null, logical(1))
    fold <- c(fold, ids[present])
    parameter <- c(parameter, rep(param, sum(present)))
    values <- c(values, unname(raw[present]))
  }
  if (length(values) == 0L) {
    return(NULL)
  }

  new_tbl(list(
    fold = factor(fold, levels = ids),
    parameter = factor(parameter, levels = params),
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
