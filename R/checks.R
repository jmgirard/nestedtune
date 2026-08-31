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
  # Asked before extract_spec_parsnip(), which raises its own error for this --
  # a fine message, but one whose conditionCall() is that internal call rather
  # than the user's, so the one bad-`object` shape a user is most likely to
  # produce was the one that did not name their call. `workflows` has a
  # has_spec() but does not export it, and `:::` is a check failure, so this
  # asks the structure directly; if that layout ever moved, the extraction
  # below still refuses, which is the behaviour this replaces.
  if (is.null(object$fit$actions$model)) {
    cli::cli_abort(
      c(
        "{.arg object} has no model specification.",
        # An empty workflow carries no preprocessor either, so the bullet says
        # which of the two shapes was actually handed over rather than assuming
        # the commoner one.
        x = if (has_preprocessor(object)) {
          "The workflow carries a preprocessor only."
        } else {
          "The workflow is empty."
        },
        i = "Add one with {.fn workflows::add_model}."
      ),
      call = call
    )
  }
  # The sibling of the branch above. A workflow needs both halves before it can
  # be fitted, and workflows raises for a missing preprocessor only once a fit
  # is attempted -- which here is inside a fold, so every fold failed alike and
  # the message was workflows', from a call the user never wrote.
  if (!has_preprocessor(object)) {
    cli::cli_abort(
      c(
        "{.arg object} has no preprocessor.",
        x = "The workflow carries a model specification only.",
        i = "Add one with {.fn workflows::add_formula}, \\
             {.fn workflows::add_recipe}, or {.fn workflows::add_variables}."
      ),
      call = call
    )
  }
  check_model_spec(workflows::extract_spec_parsnip(object), call = call)
  invisible(object)
}

# Does the workflow carry one of the three things that can preprocess?
#
# Asked by name rather than as `length(object$pre$actions) > 0L`, which is not
# the same question: `workflows::add_case_weights()` also files an action under
# `pre`, so a workflow carrying a model and case weights but no formula, recipe
# or variables has a non-empty `pre$actions` and still cannot be fitted -- it
# slipped the guard below and every outer fold failed alike, the exact
# degradation that guard exists to prevent. The counting form also described
# such a workflow as carrying "a preprocessor only" in the branch above.
has_preprocessor <- function(object) {
  any(c("formula", "recipe", "variables") %in% names(object$pre$actions))
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
  if (
    !is.data.frame(resamples) ||
      !all(c("splits", "inner_resamples") %in% names(resamples))
  ) {
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
  # Last, because the checks above judge the whole object and these judge it
  # element by element. Neither column is checked by anything upstream: a
  # design whose `inside` produced no rset is refused by nested_resamples()
  # (M18) but built without complaint by rsample::nested_cv(), and nothing at
  # all guards `splits`. Left to the drivers, both shapes cost a full run and
  # come back as tune's per-fold notes rather than as the call error they are
  # -- the same reason check_grid_params() refuses a malformed grid (GP3).
  check_column_class(
    resamples,
    "splits",
    "rsplit",
    hint = "Designs from {.fn nested_resamples} and {.fn rsample::nested_cv} \\
            carry one {.cls rsplit} per outer fold.",
    call = call
  )
  # A different hint, because the parallel sentence would be false here for the
  # commonest way of reaching this error: rsample builds the design whatever
  # `inside` returned. Only nestedtune's own constructor refuses it (M18).
  check_column_class(
    resamples,
    "inner_resamples",
    "rset",
    hint = "{.fn rsample::nested_cv} builds the design whatever its \\
            {.arg inside} argument returned; {.fn nested_resamples} refuses an \\
            {.arg inside} that produces no {.cls rset} when the design is built.",
    call = call
  )
  invisible(resamples)
}

# One list column, every element, reporting the first that is wrong.
#
# The first rather than all of them: no observed design has more than one
# offending element, and a caller who fixes the named one gets told about the
# next on the following call. Class inspection only -- nothing here evaluates
# or draws, so it stays safe to run before the seeds are taken.
check_column_class <- function(
  resamples,
  column,
  class,
  hint,
  call = rlang::caller_env()
) {
  elements <- resamples[[column]]
  ok <- vapply(elements, inherits, logical(1), class)
  if (all(ok)) {
    return(invisible(resamples))
  }
  i <- which(!ok)[[1L]]
  cli::cli_abort(
    c(
      "{.arg resamples} has a malformed {.field {column}} column.",
      x = "Element {i} is {.obj_type_friendly {elements[[i]]}}, not \\
           {.cls {class}}.",
      i = hint
    ),
    call = call
  )
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
  if (
    !is.numeric(grid) ||
      length(grid) != 1L ||
      is.na(grid) ||
      grid < 1 ||
      grid != trunc(grid)
  ) {
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
  # the call, because any condition raised downstream deparses the call it was
  # raised from -- and a call carrying the whole data frame produces an error
  # message thousands of lines long, which is the opposite of what this wrapper
  # is for. `nested_resamples()` took the same shape at M18 (`eval_spec()`);
  # before that it inlined, and this comment said so.
  eval_env <- rlang::new_environment(
    list(.nestedtune_data = data),
    parent = env
  )
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
  if (
    is.character(type) &&
      length(type) == 1L &&
      !is.na(type) &&
      type %in% allowed
  ) {
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

# `param_info` is tune's, and it is passed through untouched -- so the only
# thing worth checking here is the one mistake that would otherwise be paid for
# by a whole outer loop before tune saw it.
check_param_info <- function(param_info, call = rlang::caller_env()) {
  if (!is.null(param_info) && !inherits(param_info, "parameters")) {
    cli::cli_abort(
      c(
        "{.arg param_info} must be a {.fn dials::parameters} object or {.code NULL}.",
        x = "Got {.obj_type_friendly {param_info}}."
      ),
      call = call
    )
  }
  invisible(param_info)
}
