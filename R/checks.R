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

# A grid can be judged against the workflow before any fitting: tune knows which
# parameters are marked for tuning, and a column that is not one of them -- or a
# tuned parameter with no column -- is wrong for every fold rather than for this
# one. tune raises exactly this, but per fold, and M03 records fold failures
# instead of re-raising them; without this check a malformed grid would surface
# as an entire design failing rather than as the call error it is (GP3).
check_grid_params <- function(object, grid, call = rlang::caller_env()) {
  if (!is.data.frame(grid)) {
    return(invisible(grid))
  }
  # A check that cannot be made is skipped, never turned into a false refusal:
  # extraction can fail for reasons that are not the caller's doing.
  ids <- tryCatch(
    tune::extract_parameter_set_dials(object)$id,
    error = function(cnd) NULL
  )
  if (is.null(ids)) {
    return(invisible(grid))
  }

  unknown <- setdiff(names(grid), ids)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{.arg grid} has {length(unknown)} column{?s} not marked for tuning: \\
         {.val {unknown}}.",
        i = "Mark {cli::qty(unknown)}{?it/them} with {.fn tune::tune}, or drop \\
             {cli::qty(unknown)}{?it/them} from the grid."
      ),
      call = call
    )
  }

  missing <- setdiff(ids, names(grid))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c(
        "{.arg grid} has no column for {length(missing)} tuned parameter{?s}: \\
         {.val {missing}}.",
        i = "Every parameter marked with {.fn tune::tune} needs candidate values."
      ),
      call = call
    )
  }

  invisible(grid)
}

# The design's inner resampling specification, which the final fit re-runs over
# every row.
#
# `nested_resamples()` and `rsample::nested_cv()` both store it as an
# unevaluated call, and that is the whole reason a final fit can be built from
# the design alone: the procedure the nested estimate describes can be run
# again. A design assembled some other way carries no such call and cannot be
# re-run, which is worth saying here rather than letting the re-evaluation fail
# on something else.
check_inside_spec <- function(resamples, call = rlang::caller_env()) {
  inside <- attr(resamples, "inside")
  if (!rlang::is_call(inside)) {
    cli::cli_abort(
      c(
        "{.arg resamples} carries no inner resampling specification to re-run.",
        x = "Its {.field inside} attribute is \\
             {.obj_type_friendly {inside}}, not a call.",
        i = "Designs from {.fn nested_resamples} and {.fn rsample::nested_cv} \\
             always carry one; a design assembled by hand does not."
      ),
      call = call
    )
  }
  invisible(inside)
}

# Re-evaluate that specification against the whole data.
#
# The stored call travels without its environment, so it is evaluated wherever
# the caller stands now rather than where the design was built. A specification
# written against a variable -- `vfold_cv(v = k)` -- therefore resolves to
# whatever `k` means here: to a different design if `k` changed, and to nothing
# at all if `k` is gone. The first case is undetectable from the design alone
# and the documentation is what defends against it by asking for literals. This
# is the second case, turned into an error naming the call that was attempted
# instead of one from inside rsample.
eval_inside_spec <- function(inside, data, env, call = rlang::caller_env()) {
  spec <- paste(deparse(inside), collapse = " ")
  # The data is bound to a name in a child environment rather than inlined into
  # the call. Inlining is what `nested_resamples()` does and is equivalent here,
  # but any condition raised downstream deparses the call it was raised from --
  # and a call carrying the whole data frame produces an error message thousands
  # of lines long, which is the opposite of what this wrapper is for.
  eval_env <- rlang::new_environment(list(.nestedtune_data = data), parent = env)
  out <- tryCatch(
    eval(rlang::call_modify(inside, data = quote(.nestedtune_data)), eval_env),
    error = function(cnd) cnd
  )
  if (inherits(out, "condition")) {
    cli::cli_abort(
      c(
        "The design's inner resampling specification could not be \\
         re-evaluated.",
        x = "Tried to run {.code {spec}}.",
        i = "It is re-evaluated when {.fn nested_final_fit} is called, so \\
             every variable in it must still be in scope. Literal arguments \\
             such as {.code vfold_cv(v = 5)} always are."
      ),
      parent = out,
      call = call
    )
  }
  if (!inherits(out, "rset")) {
    cli::cli_abort(
      c(
        "The design's inner resampling specification did not produce an \\
         {.cls rset}.",
        x = "{.code {spec}} gave {.obj_type_friendly {out}}."
      ),
      call = call
    )
  }
  out
}

# Which of the two views `autoplot()` was asked for.
#
# The default is the whole vector, as the signature spells it out, and the first
# element wins -- so this accepts it, accepts either name on its own, and
# refuses anything else by naming both.
check_plot_type <- function(type, call = rlang::caller_env()) {
  allowed <- c("parameters", "performance")
  if (identical(type, allowed)) {
    return(allowed[[1L]])
  }
  if (is.character(type) && length(type) == 1L && !is.na(type) &&
      type %in% allowed) {
    return(type)
  }
  cli::cli_abort(
    c(
      "{.arg type} must be one of {.val {allowed}}.",
      x = if (is.character(type) && length(type) == 1L) {
        "Got {.val {type}}."
      } else {
        "Got {.obj_type_friendly {type}}."
      }
    ),
    call = call
  )
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
