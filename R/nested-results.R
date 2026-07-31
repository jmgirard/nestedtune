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

# The counts are attributes, so a row subset carries them along untouched and
# they go on describing the run the rows came from -- which is how a subset
# holding no completed fold could still claim its parent's two. Recomputed here
# so the object's own record of what ran stays true of the object holding it
# (IP4). A subset that drops any of the columns a results object is defined by
# is no longer one at all, and says so by shedding the class rather than
# answering for a run it can no longer describe. The test is the whole set and
# not `.completed` alone: a column subset keeping `.completed` but dropping
# `.metrics` used to stay classed, and every method reading the missing columns
# then failed on an object that still claimed to be a results object.
#' @export
`[.nested_results` <- function(x, i, j, ...) {
  out <- NextMethod()
  if (!is.data.frame(out) || !has_results_columns(out)) {
    if (inherits(out, "nested_results")) {
      class(out) <- setdiff(class(out), "nested_results")
    }
    return(out)
  }
  if (!inherits(out, "nested_results")) {
    class(out) <- c("nested_results", class(out))
  }
  # Which of these two lines is doing work depends on what NextMethod() reached,
  # and the two answers differ (measured at M20 review).
  #
  # `[.tbl_df` -- the method that actually runs, tibble being loaded whenever
  # this package is -- carries arbitrary attributes through every subset shape:
  # row, column, logical and negative alike. Against that method these lines are
  # a duplicate.
  #
  # `[.data.frame` does NOT: it carries them through a row subset and DROPS them
  # on a column subset. So against that method these lines are the guarantee,
  # not a duplicate of one, and they are what makes the `@return` promise
  # ("subsetting rows carries both unchanged") true of the class rather than of
  # whichever `[` happened to be reached. Keep them.
  #
  # The two below are load-bearing under either method, since the counts
  # describe the rows and would otherwise survive as the parent's.
  attr(out, "grid") <- attr(x, "grid")
  attr(out, "metrics") <- attr(x, "metrics")
  # The scheme label is not recomputable from the rows, and the rows kept are
  # no longer the design it names -- "10-fold cross-validation" over three rows
  # is exactly the claim IP4 forbids. It goes rather than travels.
  attr(out, "outer_label") <- NULL
  attr(out, "folds_attempted") <- nrow(out)
  attr(out, "folds_completed") <- sum(out$.completed)
  out
}

# The columns every `nested_results` method reads: the per-fold record, plus at
# least one id column to label the folds with. `fold_ids()` greps for the id
# column rather than naming it, because a repeated design carries `id` and
# `id2`, so the check greps too.
has_results_columns <- function(x) {
  required <- c(".metrics", ".selected", ".grid", ".notes", ".completed")
  all(required %in% names(x)) && any(grepl("^id", names(x)))
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
#' @param ... Not used.
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
#' deviation of the per-fold scores divided by the square root of how many
#' there were. It describes how much those folds varied. It is **not** a
#' confidence interval for the estimate, and one should not be built from it.
#'
#' That is a limit of the statistics rather than of this implementation. Outer
#' fold scores are not independent — any two folds share most of their training
#' rows — so a standard error computed as though they were understates the
#' uncertainty, and Bengio and Grandvalet (2004) proved there is no universally
#' unbiased estimator of a k-fold cross-validation estimate's variance to put in
#' its place. Gauran, Ombao and Yu (2025) measured the consequence inside a
#' nested design: across their simulations, test statistics using a
#' variance-based denominator rejected a true null far more often than the
#' nominal 5% they were run at, reaching roughly 36% in the cells they report,
#' and they recommend against such denominators outright.
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
collect_metrics.nested_results <- function(x, summarize = TRUE, ...) {
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

  mean_of <- vapply(keys[first], function(k) {
    vals <- estimates_for(k)
    if (length(vals) == 0L) NA_real_ else mean(vals)
  }, numeric(1), USE.NAMES = FALSE)
  n_of <- vapply(keys[first], function(k) {
    length(estimates_for(k))
  }, integer(1), USE.NAMES = FALSE)
  se_of <- vapply(keys[first], function(k) {
    vals <- estimates_for(k)
    if (length(vals) < 2L) NA_real_ else stats::sd(vals) / sqrt(length(vals))
  }, numeric(1), USE.NAMES = FALSE)

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
check_any_completed <- function(x, action = "summarize",
                                call = rlang::caller_env()) {
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
    .metric = unlist(lapply(x$.metrics, function(m) m$.metric), use.names = FALSE),
    .estimator = unlist(lapply(x$.metrics, function(m) m$.estimator), use.names = FALSE),
    .estimate = unlist(lapply(x$.metrics, function(m) m$.estimate), use.names = FALSE)
  ))
}

# The outer fold labels. A repeated design carries id and id2; pasting them
# keeps each row's label unique without assuming which columns are present.
fold_ids <- function(x) {
  id_cols <- grep("^id", names(x), value = TRUE)
  if (length(id_cols) == 1L) {
    return(x[[id_cols]])
  }
  do.call(paste, c(lapply(id_cols, function(nm) x[[nm]]), list(sep = ", ")))
}
