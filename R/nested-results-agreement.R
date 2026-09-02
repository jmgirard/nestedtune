# How often each candidate was selected across the outer folds.
#
# summary() prints the selections one parameter at a time and autoplot() draws
# them; this is the same fact as a table, keyed by the whole selected
# combination rather than by one parameter (M44, issue #36). Nothing here ranks
# the folds or names a winner: the most frequent row is a description of the
# procedure's choices, and the final model's parameters come from
# nested_final_fit() running the same procedure on the whole data (D-014).

#' Tabulate how often each candidate was selected across the outer folds
#'
#' @description
#' Each outer fold of a nested resampling run tunes on its own inner resamples
#' and selects one candidate. `agreement()` counts those selections: one row per
#' distinct combination of selected parameter values, with how many completed
#' outer folds chose it and what proportion of them that is, most frequent
#' first.
#'
#' The most frequent combination is **not** the final model's parameters.
#' The outer folds describe how stable the tuning procedure's choice is; the
#' model to deploy comes from [nested_final_fit()], which runs the same
#' procedure once more on the whole dataset and selects for itself.
#'
#' @param x A `nested_results` object from [nested_tune_grid()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return A tibble with one column per parameter any completed fold's
#'   selection recorded, holding the values as the folds selected them,
#'   followed by `n`, the number of completed outer folds that selected that
#'   combination, and `prop`, `n` divided by the number of completed outer
#'   folds. Rows are ordered by `n` decreasing, ties in the order the
#'   combination first appears among the object's rows. Every completed fold is
#'   counted once, so when the table has rows `sum(n)` is the number of
#'   completed folds. tune's `.config` label is not a column: it names a
#'   candidate within one fold's own tuning run, and folds can search different
#'   grids.
#'
#'   A completed fold whose selection carries no value for a parameter is
#'   counted under `NA` for that parameter, in the same row as a fold that
#'   selected `NA` for it; [summary.nested_results()] reports the two apart. A
#'   workflow with nothing to tune gives a tibble with columns `n` and `prop`
#'   and no rows. A parameter whose id is `n` or `prop` cannot be tabulated,
#'   because its column would collide with the counts, and is an error.
#'
#' A run in which some outer folds failed is tabulated over the folds that
#' completed, with a warning saying so; a run in which no fold completed is an
#' error, as it is for [collect_metrics()].
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
#' agreement(res)
#'
#' @seealso [summary.nested_results()], [autoplot.nested_results()],
#'   [nested_final_fit()]
#' @export
agreement <- function(x, ...) {
  UseMethod("agreement")
}

#' @export
agreement.default <- function(x, ...) {
  rlang::check_dots_empty()
  # `current_env()` and not `caller_env()`: inside a method reached by
  # UseMethod() the former renders the generic's own call -- `agreement(x)` --
  # while the latter renders the call one frame further out, naming whatever
  # function the user happened to be inside.
  abort_no_agreement_method(x, call = rlang::current_env())
}

#' @export
agreement.nested_results <- function(x, ...) {
  rlang::check_dots_empty()
  check_any_completed(x, action = "tabulate")
  warn_partial_summary(x, noun = "table")

  selected <- x$.selected[x$.completed]
  completed <- length(selected)
  params <- selection_params(selected)
  clash <- intersect(params, c("n", "prop"))
  if (length(clash) > 0L) {
    cli::cli_abort(
      c(
        "{.fn agreement} cannot tabulate a parameter with id {.val {clash}}.",
        i = "The table's count columns are {.code n} and {.code prop}; give \\
             the parameter another id in {.fn tune::tune}."
      ),
      class = "nestedtune_agreement_name_collision"
    )
  }
  if (length(params) == 0L) {
    return(new_tbl(list(n = integer(), prop = double())))
  }

  # One row per completed fold, in fold order, over the union of the parameters
  # any fold chose. A fold with no value for a parameter holds NA there, so it
  # still counts as a fold and its combination stays distinct from the folds
  # that chose a value. Stacked through vctrs rather than `$` on the column
  # (M06): the selections are tune's tibbles, and a fold's missing column is
  # filled by the common type, never by whichever fold happened to come first.
  rows <- lapply(selected, function(s) {
    cols <- lapply(params, function(p) if (p %in% names(s)) s[[p]] else NA)
    names(cols) <- params
    vctrs::new_data_frame(cols)
  })
  stacked <- vctrs::vec_rbind(!!!rows)

  # `sort = "location"` keeps first appearance; order() is stable, so ties in
  # `n` keep it after the sort. NA is one value here: two folds that both
  # recorded no value for a parameter chose the same thing, and vec_count()
  # groups them together as it does any other equal keys.
  counts <- vctrs::vec_count(stacked, sort = "location")
  counts <- counts[order(-counts$count), , drop = FALSE]

  out <- as.list(counts$key)
  out$n <- counts$count
  out$prop <- counts$count / completed
  new_tbl(out)
}

# The refusal for every object this generic has no method for, shaped like
# abort_no_extract_method() so the two families cannot drift apart in what
# they say. Classed, so a caller can catch it as this package's own rather than
# by matching the message.
abort_no_agreement_method <- function(x, call = rlang::caller_env()) {
  cli::cli_abort(
    c(
      "{.fn agreement} has no method for {.obj_type_friendly {x}}.",
      i = "It answers for a {.cls nested_results} object, from \\
           {.fn nested_tune_grid}."
    ),
    class = "nestedtune_no_agreement_method",
    call = call
  )
}
