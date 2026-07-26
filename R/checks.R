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
  # Trained-ness is a field on a workflow, not a class, so this asks rather
  # than tests inherits().
  if (workflows::is_trained_workflow(object)) {
    cli::cli_abort(
      c(
        "{.arg object} must not already be fitted.",
        x = "Nested cross-validation fits the workflow itself, once per outer \\
             fold, on that fold's analysis set."
      ),
      call = call
    )
  }
  check_model_spec(workflows::extract_spec_parsnip(object), call = call)
  invisible(object)
}

# A missing engine package would surface anyway, but only once the first fold
# starts fitting. Asking up front turns a wait-then-fail into an immediate
# answer, which matters when the fold that fails is the tenth. The mode is not
# checked here: workflows::workflow() already refuses a spec without one, so
# there is no path that reaches us with an unknown mode.
check_model_spec <- function(spec, call = rlang::caller_env()) {
  needed <- parsnip::required_pkgs(spec)
  missing <- needed[!vapply(needed, rlang::is_installed, logical(1))]
  if (length(missing) > 0L) {
    cli::cli_abort(
      c(
        "{.pkg {missing}} {?is/are} needed by the workflow's engine but \\
         not installed.",
        i = "Install {cli::qty(missing)}{?it/them} before running the loop."
      ),
      call = call
    )
  }

  invisible(spec)
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
  # The results object labels its rows from these. Without one, the loop would
  # run to completion and only then assemble a malformed object -- the whole
  # cost paid before anything complains, which is what checking here prevents.
  if (!any(grepl("^id", names(resamples)))) {
    cli::cli_abort(
      c(
        "{.arg resamples} has no {.field id} column naming its outer folds.",
        i = "Designs from {.fn nested_resamples} and {.fn rsample::nested_cv} \\
             always carry one."
      ),
      call = call
    )
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
