# The named doors onto what selection saw.
#
# `nested_final_fit` has carried its tuning run since M05, reachable only as an
# undocumented list slot; D-014 shipped `extract_workflow()` and left this one
# as "a documented slot suffices pre-1.0" (RR02 Q7). D-023 gives it a name, and
# gives one to the candidate set that run scored -- the final fit's equivalent
# of the candidate set each fold's `.inner_metrics` describes on
# `nested_results` (M21's column, replaced at M49), derived by the same
# function from the run's metrics table so the two can never describe the
# same thing differently.
#
# Generics rather than plain functions: the `extract_*` family is generic
# everywhere in tidymodels, so a non-generic would leave no room for a second
# class to answer. They are generics this package OWNS rather than borrows,
# which is new here -- `collect_metrics()`, `extract_workflow()` and
# `autoplot()` are all methods on someone else's -- and it is forced: neither
# tune nor hardhat defines either name (verified 2026-07-30, tune 2.1.0), so
# there is no upstream generic to register against.
#
# Both carry a default method because R's bare "no applicable method" names
# neither what was handed over nor what would have answered. tune reaches for
# the same remedy on `show_best()` (M06).

#' Extract the tuning run a final fit was selected from
#'
#' Returns the [tune::tune_grid()] or [tune::tune_bayes()] result that
#' [nested_final_fit()] chose its parameters from — the record of what
#' selection saw when the procedure was re-run on the complete dataset.
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return The stored `tune_results` object, unchanged. It is tune's own object,
#'   so tune's generics apply to it directly.
#'
#' @section What its numbers are, and are not:
#'
#' The returned object answers `collect_metrics()`, and will hand its metrics
#' over without qualifying them. Every one of them is a **selection-time**
#' quantity: it was computed on the resamples that chose the candidate it
#' describes, which makes it optimistically biased as a claim about the model
#' this final fit produced. Nothing in that object is this model's performance.
#'
#' Report the nested estimate instead — `collect_metrics()` on the results
#' object the fit was built from, the [nested_tune_grid()] or
#' [nested_tune_bayes()] result. That number is measured on data no part of the
#' tune-and-fit procedure ever saw, which is what makes it an honest description
#' of the procedure that produced your model.
#'
#' The run is kept because it is the record of what selection saw, not because
#' it describes the model.
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
#' set.seed(3)
#' final <- nested_final_fit(wf, res)
#'
#' extract_tune_results(final)
#'
#' @seealso [extract_scored_candidates()], [nested_final_fit()],
#'   [nested_tune_grid()]
#' @export
extract_tune_results <- function(x, ...) {
  UseMethod("extract_tune_results")
}

#' @export
extract_tune_results.default <- function(x, ...) {
  rlang::check_dots_empty()
  # `current_env()` and not `caller_env()`: inside a method reached by
  # UseMethod() the former renders the generic's own call --
  # `extract_tune_results(x)` -- while the latter renders the call one frame
  # further out, naming whatever function the user happened to be inside.
  abort_no_extract_method(
    "extract_tune_results",
    x,
    call = rlang::current_env()
  )
}

#' @export
extract_tune_results.nested_final_fit <- function(x, ...) {
  rlang::check_dots_empty()
  x$tuning
}

#' Extract the candidates a final fit actually scored
#'
#' Returns the candidate parameter settings that [nested_final_fit()]'s tuning
#' run actually evaluated — the full-data counterpart of the candidate set each
#' outer fold's `.inner_metrics` table describes on a [nested_tune_grid()] or
#' [nested_tune_bayes()] result, derived the same way from the run's
#' [tune::collect_metrics()] table, so a Bayesian final fit's table carries the
#' `.iter` column that path's tables do.
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return A tibble with one row per candidate scored, carrying one column per
#'   tuned parameter plus tune's `.config` label for the candidate, and `.iter`
#'   on a Bayesian fit. It is the distinct parameter rows of the run's
#'   [tune::collect_metrics()] table with those labels — the same shape one
#'   element of a result's `.inner_metrics` column reduces to when its metric
#'   columns are dropped — so the two can be compared directly.
#'
#'   This is what was **scored**, not what was **asked for**. A `grid` given as
#'   a size is expanded by tune and may reach fewer candidates than the number
#'   requested; a candidate that failed everywhere scored nothing. See the
#'   `.inner_metrics` discussion in [nested_tune_grid()] for the full account
#'   of how the two records diverge, which holds here too — this record is
#'   derived the same way.
#'
#'   One pointer there does **not** carry over. A candidate that failed on every
#'   inner resample is missing from this table, and on a `nested_tune_grid()`
#'   result its failure is recorded in that object's `.notes` column. A
#'   `nested_final_fit` has no such column. Look instead inside the tuning run
#'   itself — `tune::collect_notes(extract_tune_results(x))`.
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
#' set.seed(3)
#' final <- nested_final_fit(wf, res)
#'
#' extract_scored_candidates(final)
#'
#' @seealso [extract_tune_results()], [nested_final_fit()],
#'   [nested_tune_grid()]
#' @export
extract_scored_candidates <- function(x, ...) {
  UseMethod("extract_scored_candidates")
}

#' @export
extract_scored_candidates.default <- function(x, ...) {
  rlang::check_dots_empty()
  abort_no_extract_method(
    "extract_scored_candidates",
    x,
    call = rlang::current_env()
  )
}

#' @export
extract_scored_candidates.nested_final_fit <- function(x, ...) {
  rlang::check_dots_empty()
  # The same derivation the fold readers apply to `.inner_metrics`,
  # deliberately: two functions deriving one thing is two chances to describe
  # it differently, and the `@return` above promises a reader they can compare
  # this against a fold's candidate set directly (D-043).
  scored_candidates(x$tuning)
}

# One refusal serving every accessor here, so their wording cannot drift apart.
#
# Classed, so a caller can catch it as this package's own rather than by
# matching the message -- the convention M18 established for the argument
# checks.
abort_no_extract_method <- function(fn, x, call = rlang::caller_env()) {
  cli::cli_abort(
    c(
      "{.fn {fn}} has no method for {.obj_type_friendly {x}}.",
      i = "It answers for a {.cls nested_final_fit} object, from \\
           {.fn nested_final_fit}."
    ),
    class = "nestedtune_no_extract_method",
    call = call
  )
}
