# Printing a nested_final_fit.
#
# The object holds a tuning run, and that run has metrics: the full-data
# resampling estimate at the selected configuration. It is plain CV subject to
# selection optimism over the grid, and it wears tune's authoritative clothes.
# No number from it appears here (RR02 Q7). What appears instead is the sentence
# saying where this model's honest estimate lives, because a print method is
# where a user meets the object.

#' Print a final fit
#'
#' @description
#' Reports which parameters the full-data tuning run selected, says where this
#' model's performance estimate actually comes from, and names the accessors
#' that reach what selection saw.
#'
#' No performance number is shown. The tuning run stored on the object has
#' metrics, but they were consumed by selection and are optimistically biased as
#' a claim about this model; the nested estimate from [nested_tune_grid()] is
#' the one to report (IP3).
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return `x`, invisibly.
#'
#' @seealso [summary.nested_final_fit()], [nested_final_fit()],
#'   [nested_tune_grid()], [extract_tune_results()],
#'   [extract_scored_candidates()]
#' @export
print.nested_final_fit <- function(x, ...) {
  rlang::check_dots_empty()
  cli::cli_h1("Nested cross-validation final fit")
  cli::cli_text("Selected: {selected_label(x$selected)}")
  cli::cli_text("")
  cli::cli_bullets(c(
    i = "This model has no performance estimate of its own. Report the nested \\
         estimate from {.code collect_metrics()} on the {.fn nested_tune_grid} \\
         result, which describes the procedure that produced it.",
    i = "Compare the parameters above with {.code .selected} from that run. \\
         Outer folds choosing differently is selection instability, and it is \\
         information about the procedure rather than noise.",
    # The caution travels with the pointer rather than living only on the help
    # page: this line is where a user first learns the run is reachable, so it
    # is where naming what its numbers are worth costs them nothing to read.
    i = "{.fn extract_tune_results} returns the tuning run selection came \\
         from, and {.fn extract_scored_candidates} the candidates it scored. \\
         Any metric reachable through the first is a selection-time quantity, \\
         optimistically biased as a claim about this model."
  ))
  invisible(x)
}

#' Summarize a final fit
#'
#' @description
#' Answers what the final fit means: the full-data tuning run the selection
#' came from, how many candidates that run scored, which parameter values it
#' selected, and where this model's honest performance estimate lives.
#'
#' The estimate component is always `NULL`, and that is the point. The tuning
#' run stored on the object has metrics, but selection consumed them and they
#' are optimistically biased as a claim about this model; the nested estimate
#' from [nested_tune_grid()] is the one to report (IP3). The absence is carried
#' as a component rather than left out, so a caller reading the summary meets a
#' recorded fact instead of a missing name.
#'
#' @param object A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return
#' `summary()` returns an object of class `summary.nested_final_fit`: a list
#' holding the full-data tuning run's resampling label, the number of
#' candidates that run scored, the parameter values selection chose, and an
#' `estimate` component that is always `NULL`. Printing it is what most callers
#' want; the components are there for a caller that needs a value rather than a
#' line of text.
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
#' final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))
#'
#' summary(final)
#'
#' @seealso [print.nested_final_fit()], [nested_final_fit()],
#'   [summary.nested_results()], [extract_tune_results()]
#' @export
summary.nested_final_fit <- function(object, ...) {
  rlang::check_dots_empty()
  new_summary_nested_final_fit(object)
}

#' @rdname summary.nested_final_fit
#' @param x A `summary.nested_final_fit` object from
#'   [summary.nested_final_fit()].
#' @return
#' `print()` returns `x`, invisibly.
#' @export
print.summary.nested_final_fit <- function(x, ...) {
  rlang::check_dots_empty()
  cli::cli_h1("Nested cross-validation final fit")
  print_final_design(x)
  print_final_selection(x)
  print_final_estimate(x)
  invisible(x)
}

# Everything the summary reports, derived from the object at call time.
#
# Nothing here raises: `scored_candidates()` swallows its own errors by
# construction, and the label falls back to NULL the way `outer_scheme_label()`
# does for the loop -- a run whose tuning object cannot describe itself has no
# scheme to name, and the line is dropped rather than invented.
#
# `estimate` is carried and set to NULL rather than omitted. This object has no
# performance estimate of its own (IP3), and recording that positively is the
# same habit IP4 asks of the loop: what is true is written down, never left to
# be inferred from a name that is not there.
new_summary_nested_final_fit <- function(x) {
  structure(
    list(
      tuning_label = tuning_scheme_label(x$tuning),
      candidates = nrow(scored_candidates(x$tuning)),
      selection = summary_final_selection(x$selected),
      estimate = NULL
    ),
    class = "summary.nested_final_fit"
  )
}

# How the full-data tuning run's resampling scheme describes itself.
#
# The same tryCatch guard `outer_scheme_label()` uses, for the same reason: a
# resampling object built somewhere else may carry no pretty() method, and then
# the run simply has no scheme to name.
tuning_scheme_label <- function(tuned) {
  label <- tryCatch(pretty(tuned), error = function(cnd) NULL)
  if (!is.character(label) || length(label) != 1L) {
    return(NULL)
  }
  label
}

# One entry per parameter selection chose a value for, unrendered.
#
# The single extraction both the summary component and the print line are
# rendered from, so the two cannot come to describe one selection differently.
#
# tune adds a `.config` column to what select_best() returns; it labels the
# candidate inside the tuning run and means nothing outside it, so it is
# dropped here and by everything reading this.
final_selection_values <- function(selected) {
  keep <- setdiff(names(selected), ".config")
  out <- lapply(keep, function(nm) selected[[nm]][[1L]])
  names(out) <- keep
  out
}

# The stored `selection` component: one string per parameter, at the value's
# own precision.
#
# `as.character()` rather than `format()`, matching `selection_values()` on the
# results side. This is a component a caller reaches for a value, and comparing
# it against the results-side selection is the thing it is for; `format()`
# would round it to the session's `digits` option and report two equal
# selections as different ones (M40 review F1).
#
# The values are collapsed rather than taken as scalars. A list-valued
# selection is not something select_best() produces, but the caller is a print
# path that promises never to raise, and a length-2 cell would otherwise abort
# where a joined string describes it.
summary_final_selection <- function(selected) {
  lapply(final_selection_values(selected), function(value) {
    if (length(value) != 1L) {
      return(paste0(format(value), collapse = ", "))
    }
    if (is.na(value)) {
      return("NA")
    }
    as.character(value)
  })
}

# The selected candidate as `name = value` pairs, on one line.
#
# Rendered with `format()`, which is what a one-line label wants and what this
# method has always emitted; the stored component above renders the same
# extraction for a reader who wants the value instead.
selected_label <- function(selected) {
  values <- final_selection_values(selected)
  if (length(values) == 0L) {
    return("nothing to select")
  }
  rendered <- vapply(
    values,
    function(value) paste0(format(value), collapse = ", "),
    character(1)
  )
  paste0(names(rendered), " = ", rendered, collapse = ", ")
}

# What the tuning run was, before what it chose. The candidate count is the
# size of the menu selection picked from, which is what makes the line below it
# a choice rather than a foregone conclusion.
print_final_design <- function(s) {
  if (!is.null(s$tuning_label)) {
    cli::cli_text("Full-data tuning: {s$tuning_label}")
  }
  cli::cli_text("Candidates scored: {s$candidates}")
  invisible(NULL)
}

print_final_selection <- function(s) {
  cli::cli_h2("Selected parameters")
  if (length(s$selection) == 0L) {
    cli::cli_bullets(c(i = "No tuned parameters."))
    return(invisible(NULL))
  }
  for (param in names(s$selection)) {
    cli::cli_text("{param}: {s$selection[[param]]}")
  }
  invisible(NULL)
}

# IP3, under the heading a reader looking for a number goes to first. The
# heading is where the number would be, so the sentence saying there is none
# and where the real one lives is what stands in its place. No value from the
# stored tuning run appears here or anywhere in this method.
print_final_estimate <- function(s) {
  cli::cli_h2("Estimate")
  cli::cli_bullets(c(
    i = "This model has no performance estimate of its own. Report the nested \\
         estimate from {.code collect_metrics()} on the {.fn nested_tune_grid} \\
         result, which describes the procedure that produced it.",
    i = "The tuning run above has metrics, but selection consumed them. \\
         {.fn extract_tune_results} reaches them, and every one is a \\
         selection-time quantity, optimistically biased as a claim about this \\
         model."
  ))
  invisible(NULL)
}
