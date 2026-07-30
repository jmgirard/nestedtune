# The named doors onto what selection saw.
#
# `nested_final_fit` has carried its tuning run since M05, reachable only as an
# undocumented list slot; D-014 shipped `extract_workflow()` and left this one
# as "a documented slot suffices pre-1.0" (RR02 Q7). D-023 gives it a name, and
# gives one to the candidate set that run scored -- the final fit's equivalent
# of the `.grid` column M21 put on `nested_results`, derived by the same
# function so the two can never describe the same thing differently.
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
#' Returns the [tune::tune_grid()] result that [nested_final_fit()] chose its
#' parameters from — the record of what selection saw when the procedure was
#' re-run on the complete dataset.
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used.
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
#' Report the nested estimate instead — `collect_metrics()` on the
#' [nested_tune_grid()] result. That number is measured on data no part of the
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
#' set.seed(3)
#' final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))
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
  # `current_env()` and not `caller_env()`: inside a method reached by
  # UseMethod() the former renders the generic's own call --
  # `extract_tune_results(x)` -- while the latter renders the call one frame
  # further out, naming whatever function the user happened to be inside.
  abort_no_extract_method("extract_tune_results", x, call = rlang::current_env())
}

#' @export
extract_tune_results.nested_final_fit <- function(x, ...) {
  x$tuning
}

#' Extract the candidates a final fit actually scored
#'
#' Returns the candidate parameter settings that [nested_final_fit()]'s tuning
#' run actually evaluated — the full-data counterpart of the `.grid` column
#' [nested_tune_grid()] records for each outer fold.
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used.
#'
#' @return A tibble with one row per candidate scored, carrying one column per
#'   tuned parameter plus tune's `.config` label for the candidate. It is the
#'   same shape as one element of [nested_tune_grid()]'s `.grid` column, so the
#'   two can be compared directly.
#'
#'   This is what was **scored**, not what was **asked for**. A `grid` given as
#'   a size is expanded by tune and may reach fewer candidates than the number
#'   requested; a candidate that failed everywhere scored nothing. See the
#'   `.grid` discussion in [nested_tune_grid()] for the full account of how the
#'   two records diverge, which holds here too — this record is derived the same
#'   way.
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
#' set.seed(3)
#' final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))
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
  abort_no_extract_method(
    "extract_scored_candidates", x,
    call = rlang::current_env()
  )
}

#' @export
extract_scored_candidates.nested_final_fit <- function(x, ...) {
  # The same derivation the loop uses, deliberately: two functions deriving one
  # thing is two chances to describe it differently, and the `@return` above
  # promises a reader they can compare this against a fold's `.grid` directly.
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
