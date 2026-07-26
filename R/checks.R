# Argument validation for nested_tune_grid().
#
# GP3: a provably invalid design is refused rather than warned about. Each of
# these fires before any fitting, so a misspecified call fails in a second
# rather than after the first fold.

check_workflow <- function(object, call = rlang::caller_env()) {
  if (!inherits(object, "workflow")) {
    cli::cli_abort(
      c(
        "{.arg object} must be a {.cls workflow}.",
        x = "Got {.obj_type_friendly {object}}.",
        i = "Wrap a model and a preprocessor with {.fn workflows::workflow}."
      ),
      call = call
    )
  }
  if (inherits(object, "trained_workflow")) {
    cli::cli_abort(
      c(
        "{.arg object} must not already be fitted.",
        x = "Nested cross-validation fits the workflow itself, once per outer \\
             fold, on that fold's analysis set."
      ),
      call = call
    )
  }
  invisible(object)
}

check_nested <- function(resamples, call = rlang::caller_env()) {
  if (!is.data.frame(resamples) ||
      !all(c("splits", "inner_resamples") %in% names(resamples))) {
    cli::cli_abort(
      c(
        "{.arg resamples} must be a nested resampling design.",
        x = "Got {.obj_type_friendly {resamples}}.",
        i = "Build one with {.fn nested_resamples} or \\
             {.fn rsample::nested_cv}."
      ),
      call = call
    )
  }
  if (nrow(resamples) == 0L) {
    cli::cli_abort("{.arg resamples} has no outer folds.", call = call)
  }
  # rsample only warns for a bootstrap here. The same row can land in both the
  # inner analysis and the inner assessment set, which makes the estimate
  # invalid rather than merely unusual, so this refuses (GP3). nested_resamples()
  # already refuses at construction; this catches designs built elsewhere.
  if (inherits(resamples, "bootstraps")) {
    cli::cli_abort(
      c(
        "{.arg resamples} cannot use a bootstrap for the outer loop.",
        x = "The same row can land in both the inner analysis and inner \\
             assessment set, so the nested estimate would be invalid.",
        i = "{.fn rsample::nested_cv} only warns here; {.fn nested_tune_grid} \\
             refuses."
      ),
      call = call
    )
  }
  invisible(resamples)
}

check_grid <- function(grid, call = rlang::caller_env()) {
  if (is.data.frame(grid)) {
    if (nrow(grid) == 0L) {
      cli::cli_abort(
        "{.arg grid} must have at least one candidate row.",
        call = call
      )
    }
    return(invisible(grid))
  }
  if (!is.numeric(grid) || length(grid) != 1L || is.na(grid) ||
      grid < 1 || grid != trunc(grid)) {
    cli::cli_abort(
      c(
        "{.arg grid} must be a data frame of candidates or a single positive \\
         whole number.",
        x = "Got {.obj_type_friendly {grid}}."
      ),
      call = call
    )
  }
  invisible(grid)
}

check_metrics <- function(metrics, call = rlang::caller_env()) {
  if (!is.null(metrics) && !inherits(metrics, "metric_set")) {
    cli::cli_abort(
      c(
        "{.arg metrics} must be a {.fn yardstick::metric_set} or {.code NULL}.",
        x = "Got {.obj_type_friendly {metrics}}."
      ),
      call = call
    )
  }
  invisible(metrics)
}
