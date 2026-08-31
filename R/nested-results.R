# The results object.
#
# Deliberately NOT a `tune_results`. Inheriting it would bring show_best() and
# select_best() along, and both would happily rank outer folds -- output that
# looks authoritative and means nothing, since there is nothing to select at
# the outer level. Refusing the class makes them error instead (D-010).

new_nested_results <- function(resamples, folds, seeds, grid, metrics) {
  n <- length(folds)
  id_cols <- setdiff(names(resamples), c("splits", "inner_resamples"))

  cols <- list(splits = resamples$splits)
  for (nm in id_cols) {
    cols[[nm]] <- resamples[[nm]]
  }
  completed <- vapply(folds, function(x) x$completed, logical(1))

  cols[[".metrics"]] <- lapply(folds, function(x) x$metrics)
  cols[[".selected"]] <- lapply(folds, function(x) x$selected)
  # IP4's "the grid actually evaluated", per fold rather than per run: folds can
  # genuinely search different candidate sets, so this is a column and not an
  # attribute. An attribute would also survive a row subset as the parent's
  # record (M20), which is the stale claim the same principle forbids.
  cols[[".grid"]] <- lapply(folds, function(x) x$grid)
  cols[[".notes"]] <- lapply(folds, function(x) x$notes)
  cols[[".completed"]] <- completed
  cols[[".tuning_seed"]] <- seeds[seq(1L, by = 2L, length.out = n)]
  cols[[".outer_fit_seed"]] <- seeds[seq(2L, by = 2L, length.out = n)]

  out <- new_tbl(cols)
  attr(out, "grid") <- grid
  attr(out, "metrics") <- metrics
  attr(out, "outer_label") <- outer_scheme_label(resamples)
  # IP4: what ran is recorded positively, never inferred from what is absent.
  attr(out, "folds_attempted") <- n
  attr(out, "folds_completed") <- sum(completed)
  class(out) <- c("nested_results", class(out))
  out
}

# How the outer resampling scheme describes itself, for printing.
#
# rsample answers this through pretty(), but a nested design dispatches to a
# method describing both levels at once. Stripping the nested classes leaves the
# outer rset, which describes only itself. A design built somewhere else may
# carry no pretty() method at all, and then the run simply has no scheme to
# name -- printing drops the line rather than inventing one.
outer_scheme_label <- function(resamples) {
  outer <- resamples
  class(outer) <- setdiff(class(outer), c("nested_resamples", "nested_cv"))
  label <- tryCatch(pretty(outer), error = function(cnd) NULL)
  if (!is.character(label) || length(label) != 1L) {
    return(NULL)
  }
  label
}

# The invariants, and the one rule every operation on the class goes through.
#
# These are tune's, declared on `tune_results` (tune#221) and asked for here in
# #32: rows may be reordered but never added or removed, and columns may be
# added or reordered. An operation inside that set gets the class back; anything
# else gets a bare tibble, because an object holding rows other than the ones
# the run produced cannot answer for the run and must stop claiming it can
# (IP4). The alternative -- what this class did until M36 -- is what makes
# `slice(x, 1)` return a one-row object still headed "3-fold cross-validation".
#
# Only `dplyr_reconstruct()` is registered. dplyr's default `dplyr_row_slice()`
# and `dplyr_col_modify()` both finish by calling it, and so does `bind_rows()`,
# so one method covers the verbs; `[` is the one door that does not lead here on
# its own, and is routed here explicitly below.

# Which of these names are the design's own fold labels.
#
# The constructor takes whatever the rset carries beside `splits` and
# `inner_resamples`, and for every design rsample builds that is `id` alone, or
# `id` and `id2` for a repeated one. Matching those names is therefore the same
# set, and it is the only place the answer is given -- record_columns(),
# has_results_columns() and fold_ids() all ask here, so the class cannot hold
# two ideas of what a label column is.
#
# The anchor at both ends is the point. A bare `^id` prefix also matches
# `ideal`, `id_extra` and anything else a caller joins in to label folds with,
# and treating one of those as the design's own is what made an added column
# impossible to remove again, what turned an added list column into an order()
# key on a repeated design, and what pasted an added column into every fold's
# printed label (M36 review O2, O3). An rset whose label column is spelled some
# other way is not matched, and its results object then stops keeping the class
# through a dplyr verb rather than keeping it on an unchecked record -- the
# conservative direction (M36 review O6).
id_columns <- function(nms) {
  grep("^id[0-9]*$", nms, value = TRUE)
}

# The run's record: every column new_nested_results() writes. Read off the
# TEMPLATE only -- see can_reconstruct_results().
record_columns <- function(nms) {
  fixed <- c(
    "splits",
    ".metrics",
    ".selected",
    ".grid",
    ".notes",
    ".completed",
    ".tuning_seed",
    ".outer_fit_seed"
  )
  nms %in% fixed | nms %in% id_columns(nms)
}

# Whether `data` may wear `template`'s class: every column of the template's
# record still present, holding the same values, over the same number of rows.
# Row ORDER is exempt -- the folds are a set, and arrange() rearranging them
# changes nothing the object claims -- so both sides are put in id order before
# their values are compared.
#
# The record compared is the TEMPLATE's, and a column `data` carries beyond it
# is simply not looked at. Comparing the two sets for equality instead would
# read a caller-added column as a record that no longer matches, which is what
# "columns may be added" forbids (M36 review F2).
can_reconstruct_results <- function(data, template) {
  if (!is.data.frame(data) || !has_results_columns(data)) {
    return(FALSE)
  }
  cols <- sort(names(template)[record_columns(names(template))])
  if (!all(cols %in% names(data))) {
    return(FALSE)
  }
  if (!identical(nrow(data), nrow(template))) {
    return(FALSE)
  }
  # Without an id column there is no ordering to compare under: the
  # permutation is empty, every compared column comes out zero-length, and any
  # two objects are identical(). Refusing is the honest answer -- the record
  # cannot be checked, so it cannot be vouched for (M36 review O5).
  id_cols <- id_columns(cols)
  if (length(id_cols) == 0L) {
    return(FALSE)
  }
  in_id_order <- function(x) {
    ord <- do.call(order, lapply(id_cols, function(nm) x[[nm]]))
    lapply(cols, function(nm) x[[nm]][ord])
  }
  identical(in_id_order(data), in_id_order(template))
}

# The rule. `template` supplies what describes the call; the rows in hand supply
# what describes themselves.
reconstruct_results <- function(data, template) {
  if (!can_reconstruct_results(data, template)) {
    return(bare_results(data))
  }
  # Promoted before the class goes on, for the reason as_results_tbl() gives:
  # the class is documented as a tibble subclass, and dplyr hands this function
  # a bare data frame often enough that only the bare branch promoting would
  # make it one for some verbs and not others (M36 review F1).
  out <- as_results_tbl(data)
  if (!inherits(out, "nested_results")) {
    class(out) <- c("nested_results", class(out))
  }
  # `metrics` is absent rather than NULL when none was supplied, and assigning
  # NULL to an attribute removes it, so this preserves the distinction.
  attr(out, "grid") <- attr(template, "grid")
  attr(out, "metrics") <- attr(template, "metrics")
  attr(out, "outer_label") <- attr(template, "outer_label")
  # Read off the rows rather than copied from the template. Under the invariants
  # the two agree, so this corrects nothing today; it is the object's own record
  # of what ran, and IP4 asks that it be true of the object holding it however
  # the object was reached.
  attr(out, "folds_attempted") <- nrow(out)
  attr(out, "folds_completed") <- sum(out$.completed)
  out
}

# Shedding the class also sheds the run's record. Leaving `outer_label` on a
# bare tibble would leave the stale claim readable by anyone who looks for it,
# which is the same fault one layer down.
#
# The class is removed by subtraction rather than replaced with tibble's three,
# which leaves whatever else the object was carrying alone.
bare_results <- function(data) {
  for (nm in results_attributes()) {
    attr(data, nm) <- NULL
  }
  class(data) <- setdiff(class(data), "nested_results")
  as_results_tbl(data)
}

# What both branches return is a tibble. `nested_results` is a tibble subclass
# (DESIGN: "a plain tibble carrying class `nested_results`"), and dplyr hands
# `dplyr_reconstruct()` a bare data frame for a good half of the verbs --
# `filter()`, `mutate()`, `arrange()`, `bind_cols()`, `left_join()`, `slice()`
# and `bind_rows()` all do, measured 2026-08-31 -- so leaving the classes off
# would make the result a tibble after `select()` and not after `mutate()`,
# and drop `x[, "id"]` to a bare vector for the second. Neither branch is a
# downgrade the caller asked for.
as_results_tbl <- function(data) {
  if (!inherits(data, "tbl_df")) {
    class(data) <- c("tbl_df", "tbl", class(data))
  }
  data
}

results_attributes <- function() {
  c("grid", "metrics", "outer_label", "folds_attempted", "folds_completed")
}

#' @importFrom dplyr dplyr_reconstruct
#' @export
dplyr_reconstruct.nested_results <- function(data, template) {
  reconstruct_results(data, template)
}

# `[` reaches tibble's method, which carries every attribute through every
# subset shape and would hand back a classed object for any of them. Routing its
# result through the same rule is what makes the invariants a property of the
# class rather than of whichever `[` NextMethod() happened to reach.
#' @export
`[.nested_results` <- function(x, i, j, ...) {
  out <- NextMethod()
  if (!is.data.frame(out)) {
    return(out)
  }
  reconstruct_results(out, x)
}

# The columns every `nested_results` method reads: the per-fold record, plus at
# least one id column to label the folds with. A subset of `record_columns()`,
# and the weaker test -- it asks only that the methods will work, while
# `can_reconstruct_results()` asks that the record be whole.
has_results_columns <- function(x) {
  required <- c(".metrics", ".selected", ".grid", ".notes", ".completed")
  all(required %in% names(x)) && length(id_columns(names(x))) > 0L
}

# A tibble is a data frame with three classes and compact row names. Building
# one directly costs a line and saves a dependency on tibble for the sake of
# a constructor.
new_tbl <- function(cols) {
  structure(
    cols,
    class = c("tbl_df", "tbl", "data.frame"),
    row.names = .set_row_names(length(cols[[1L]]))
  )
}

#' Collect the metrics from a nested resampling run
#'
#' @param x A `nested_results` object from [nested_tune_grid()].
#' @param summarize Whether to average the per-fold metrics (`TRUE`, the
#'   default) or return them one row per outer fold (`FALSE`).
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return A tibble. Summarized, one row per metric with the mean across outer
#'   folds, the number of folds, and the standard error of that mean.
#'   Unsummarized, one row per outer fold and metric.
#'
#' @details
#' The summarized value is the nested cross-validation estimate: what the
#' tune-and-fit procedure achieves on data it never saw. It is not the
#' performance of any model you have in hand.
#'
#' Only the outer folds that completed are summarized, and `n` counts them, so
#' a run with failures never reports its estimate as though the whole design
#' had run. Those folds are dropped with a warning naming them; when no fold
#' completed at all, this errors instead of returning `NA`.
#'
#' @section Reading `std_err`:
#'
#' `std_err` is the standard error of the mean across outer folds: the standard
#' deviation of the per-fold scores divided by the square root of how many there
#' were. It is the precision of that mean, not the fold-to-fold spread, which is
#' larger by the same square-root factor. It is **not** a confidence interval for
#' the estimate, and one should not be built from it.
#'
#' That is a limit of the statistics rather than of this implementation. Outer
#' fold scores are not independent — any two folds share most of their training
#' rows — so a standard error computed as though they were can misstate the
#' uncertainty, typically downward. Bengio and Grandvalet (2004) proved there is
#' no universally unbiased estimator of a k-fold cross-validation estimate's
#' variance to put in its place. Gauran, Ombao and Yu (2025) measured what that
#' costs inside a nested design: several of their test statistics built on a
#' variance-based denominator rejected a true null far more often than the
#' nominal 5% they were run at — 36% and 40% in the worst cells they report —
#' and they recommend against such denominators outright.
#'
#' Both results are about closely related quantities rather than this column
#' exactly: Bengio and Grandvalet study the variance of a k-fold estimate built
#' from per-observation losses, and Gauran and colleagues work inside ridge and
#' LASSO designs. Neither gap rescues the column — no interval here is
#' oracle-backed, which is the practical point.
#'
#' The column is reported because `tune` reports it and users expect the shape;
#' no inferential claim is made with it.
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
#' collect_metrics(res)
#' collect_metrics(res, summarize = FALSE)
#'
#' @references
#' Bengio, Y., & Grandvalet, Y. (2004). No unbiased estimator of the variance of
#' K-fold cross-validation. *Journal of Machine Learning Research*, 5,
#' 1089–1105.
#'
#' Gauran, I. I., Ombao, H., & Yu, Z. (2025). Predictive performance test based
#' on the exhaustive nested cross-validation for high-dimensional data.
#' *arXiv:2408.03138*.
#'
#' @export
collect_metrics.nested_results <- function(x, ..., summarize = TRUE) {
  rlang::check_dots_empty()
  check_any_completed(x)
  warn_partial_summary(x)

  per_fold <- per_fold_metrics(x)
  if (!summarize) {
    return(per_fold)
  }
  summarize_folds(per_fold)
}

# The averaging, with no conditions of its own.
#
# Split out from collect_metrics() so that print.nested_results() can show the
# same numbers without the warning and the abort: a summary is a request for an
# estimate and owes the caller a condition when the design fell short, while a
# print is a description of the object and says the same thing in its header
# instead. Both read the estimate off this one function, so they can never
# disagree about it.
summarize_folds <- function(per_fold) {
  keys <- paste(per_fold$.metric, per_fold$.estimator, sep = "\r")
  first <- !duplicated(keys)

  # A fold can score NA -- an outer assessment set with one class gives
  # roc_auc = NA, which small folds on imbalanced data reach routinely. Those
  # folds are dropped from the summary rather than allowed to poison it, and
  # `n` counts the folds that actually contributed, so a summary row never
  # reports no estimate while claiming every fold was in it. This is what
  # tune::estimate_tune_results() does, and GP1 says to match it.
  estimates_for <- function(k) {
    vals <- per_fold$.estimate[keys == k]
    vals[!is.na(vals)]
  }

  mean_of <- vapply(
    keys[first],
    function(k) {
      vals <- estimates_for(k)
      if (length(vals) == 0L) NA_real_ else mean(vals)
    },
    numeric(1),
    USE.NAMES = FALSE
  )
  n_of <- vapply(
    keys[first],
    function(k) {
      length(estimates_for(k))
    },
    integer(1),
    USE.NAMES = FALSE
  )
  se_of <- vapply(
    keys[first],
    function(k) {
      vals <- estimates_for(k)
      if (length(vals) < 2L) NA_real_ else stats::sd(vals) / sqrt(length(vals))
    },
    numeric(1),
    USE.NAMES = FALSE
  )

  new_tbl(list(
    .metric = per_fold$.metric[first],
    .estimator = per_fold$.estimator[first],
    mean = mean_of,
    n = n_of,
    std_err = se_of
  ))
}

# IP4: nothing is reported for a design that did not run at all. With no fold
# completed there is no estimate to give, and returning NA would let a caller
# treat the absence of a result as a result. `action` names what the caller was
# asking for -- summarizing or plotting -- so both refusals say the same thing
# about the same object and cannot drift apart.
check_any_completed <- function(
  x,
  action = "summarize",
  call = rlang::caller_env()
) {
  # Read from the column, never from the stamped count: the column travels with
  # the rows, so the two can never disagree about the object actually in hand.
  if (any(x$.completed)) {
    return(invisible(x))
  }
  n <- nrow(x)
  cli::cli_abort(
    c(
      "There is nothing to {action}: no outer fold completed.",
      x = "All {n} outer fold{?s} failed.",
      i = "See {.code x$.notes} for what went wrong."
    ),
    call = call
  )
}

# A partial run is still summarized -- expensive compute is not thrown away --
# but never quietly. The count in `n` says how many folds contributed; this
# says which ones did not, and that the design asked for more.
warn_partial_summary <- function(x, call = rlang::caller_env()) {
  failed <- fold_ids(x)[!x$.completed]
  if (length(failed) == 0L) {
    return(invisible(x))
  }
  n <- nrow(x)
  cli::cli_warn(
    c(
      "!" = "This summary covers {sum(x$.completed)} of {n} outer fold{?s}.",
      x = "Failed: {.val {failed}}.",
      i = "It describes the folds that ran, not the design that was requested."
    ),
    class = "nestedtune_partial_summary",
    call = call
  )
  invisible(x)
}

# One row per outer fold and metric. The per-fold tibbles come straight from
# tune::last_fit(), so their columns are tune's, not ours.
per_fold_metrics <- function(x) {
  ids <- fold_ids(x)
  n_rows <- vapply(x$.metrics, nrow, integer(1))

  new_tbl(list(
    id = rep(ids, times = n_rows),
    .metric = unlist(
      lapply(x$.metrics, function(m) m$.metric),
      use.names = FALSE
    ),
    .estimator = unlist(
      lapply(x$.metrics, function(m) m$.estimator),
      use.names = FALSE
    ),
    .estimate = unlist(
      lapply(x$.metrics, function(m) m$.estimate),
      use.names = FALSE
    )
  ))
}

# The outer fold labels. A repeated design carries id and id2; pasting them
# keeps each row's label unique without assuming which columns are present.
# Asking id_columns() rather than grepping `^id` here is what stops a column the
# caller added from being pasted in with them (M36 T9).
fold_ids <- function(x) {
  id_cols <- id_columns(names(x))
  if (length(id_cols) == 1L) {
    return(x[[id_cols]])
  }
  do.call(paste, c(lapply(id_cols, function(nm) x[[nm]]), list(sep = ", ")))
}
