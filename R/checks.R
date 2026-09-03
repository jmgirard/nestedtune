# Argument validation for the orchestrators and the final fit.
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
# `recorded = TRUE` is the final fit's reading: the grid came off the results
# object and is the fixed side, so the message names `object` -- the workflow
# handed over -- rather than a `grid` argument the caller never wrote (D-041).
check_grid_params <- function(
  object,
  grid,
  call = rlang::caller_env(),
  recorded = FALSE
) {
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
    if (recorded) {
      cli::cli_abort(
        c(
          "{.arg object} does not tune {length(unknown)} parameter{?s} the \\
           recorded grid has {?a column/columns} for: {.val {unknown}}.",
          i = "Hand over the workflow the nested run in {.arg results} was \\
               built around."
        ),
        call = call
      )
    }
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
    if (recorded) {
      cli::cli_abort(
        c(
          "{.arg object} tunes {length(missing)} parameter{?s} the recorded \\
           grid has no column for: {.val {missing}}.",
          i = "Hand over the workflow the nested run in {.arg results} was \\
               built around."
        ),
        call = call
      )
    }
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

# The record a final fit re-runs (D-041, RR05 Q3): a `nested_results` carrying
# the design's inner resampling specification and the procedure that ran, with
# at least one row to read the data off. One class for every shape, as the
# Bayesian arguments are refused (`nestedtune_bad_<arg>`): what a caller does
# is the same on each -- stop, and go back to an object the orchestrator
# produced -- and the message carries which shape it was.
#
# Three origins reach here, and the messages name them. An operation outside
# the class's invariants -- rows added or removed -- returns a bare tibble
# (R/nested-results.R), so `res[0, ]` and `filter(res, ...)` arrive as "not a
# nested_results", never as a classed object missing its record. A classed
# object with no `inside` has two indistinguishable origins, because an
# attribute cannot hold NULL: a result built before the specification was
# recorded, and one built from a design that carried none. And a classed
# object with the record and no rows is a prototype: it describes a run and
# holds no data to re-run it on.
check_results_record <- function(results, call = rlang::caller_env()) {
  if (!inherits(results, "nested_results")) {
    cli::cli_abort(
      c(
        "{.arg results} must be a {.cls nested_results} from \\
         {.fn nested_tune_grid} or one of its siblings.",
        x = "Got {.obj_type_friendly {results}}.",
        i = "An operation that adds or removes rows returns a plain tibble \\
             without the run's record; hand over the object the \\
             orchestrator returned."
      ),
      class = "nestedtune_bad_results",
      call = call
    )
  }
  inside <- attr(results, "inside")
  procedure <- attr(results, "procedure")
  if (!rlang::is_call(inside) || !is.list(procedure)) {
    absent <- c(
      if (!rlang::is_call(inside)) "inner resampling specification",
      if (!is.list(procedure)) "tuning procedure"
    )
    cli::cli_abort(
      c(
        "{.arg results} carries no {absent} to re-run.",
        x = "It was built by an earlier version of nestedtune, or from a \\
             design assembled by hand rather than by {.fn nested_resamples} \\
             or {.fn rsample::nested_cv}, which store the specification as \\
             a call.",
        i = "Re-run {.fn nested_tune_grid} or the sibling that built it on \\
             this version, on a design from one of those constructors; a \\
             results object is not migrated."
      ),
      class = "nestedtune_bad_results",
      call = call
    )
  }
  if (nrow(results) == 0L) {
    cli::cli_abort(
      c(
        "{.arg results} has no rows, so there is no data to re-run the \\
         procedure on.",
        x = "A prototype describes a run but cannot re-run it."
      ),
      class = "nestedtune_bad_results",
      call = call
    )
  }
  invisible(results)
}

# A run in which no outer fold completed has no estimate, and the estimate is
# the number a final model is reported with (IP3): fitting one from such a
# record would hand back a model with no companion figure, so the request is
# refused (GP3). Read from `.completed`, the column every tuner's worker writes
# through one constructor, as `check_any_completed()` (R/nested-results.R)
# reads it for the summary doors -- and under the same class, so one fact is
# catchable one way whichever door asked. A partial run is not refused: the
# final fit is not the estimate, and `collect_metrics()`'s warning already
# sits where the estimate is. This is a refusal of the run, not of the
# object's shape, so it is not `nestedtune_bad_results`.
check_completed_folds <- function(results, call = rlang::caller_env()) {
  if (any(results$.completed)) {
    return(invisible(results))
  }
  n <- nrow(results)
  cli::cli_abort(
    c(
      "{.arg results} carries no estimate to report a model with: no outer \\
       fold completed.",
      x = "All {n} outer fold{?s} failed.",
      i = "Call {.fn summary} on {.arg results} for the stage each fold \\
           failed at, and re-run {.fn nested_tune_grid} or the sibling that \\
           built it once the cause is fixed."
    ),
    class = "nestedtune_no_completed_folds",
    call = call
  )
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

# `eval_time` is tune's too, and like `event_level` it is passed through
# untouched (D-038). What is refused here is only what tune has no use for:
# `tune:::.filter_eval_time()` coerces with `as.numeric()`, drops missing
# values, keeps what is finite and `>= 0`, uniques the rest, warns about what it
# dropped, and aborts only when nothing survives. So `0`, duplicates and
# unsorted times are accepted here and left for tune to normalize -- refusing
# them would invent a second, stricter rule for tune's own argument -- while a
# value tune would have thrown away is refused before a whole outer loop is paid
# for, and before a mirai daemon can raise it in a frame naming tune rather than
# the function the user called.
#
# Whether the mode is one `eval_time` applies to is not consulted, for the
# reason `check_event_level()` gives below: tune warns about that itself, on its
# own argument.
check_eval_time <- function(eval_time, call = rlang::caller_env()) {
  if (is.null(eval_time)) {
    return(invisible(eval_time))
  }

  if (!is.numeric(eval_time) || length(eval_time) == 0L) {
    cli::cli_abort(
      c(
        "{.arg eval_time} must be a numeric vector of evaluation times, or {.code NULL}.",
        x = if (is.numeric(eval_time)) {
          "Got an empty vector."
        } else {
          "Got {.obj_type_friendly {eval_time}}."
        }
      ),
      call = call
    )
  }

  # Every offending position, not the first: a caller who passed a vector wants
  # to know which of its times is the problem.
  unusable <- is.na(eval_time) | !is.finite(eval_time) | eval_time < 0
  if (any(unusable)) {
    # As character, so cli reads them as a list of items to name rather
    # than as the quantity a numeric interpolation would set.
    positions <- as.character(which(unusable))
    cli::cli_abort(
      c(
        "Every element of {.arg eval_time} must be finite, non-missing, and non-negative.",
        x = "{cli::qty(length(positions))}Element{?s} {positions} {?is/are} not."
      ),
      call = call
    )
  }

  invisible(eval_time)
}

# `event_level` is tune's, and it is passed through untouched. tune accepts the
# setting on a regression workflow and ignores it, so the mode is not consulted
# here (plan gate, 2026-08-31) -- refusing it there would diverge from tune for
# the same argument and would punish one wrapper written for both kinds of
# model. What is refused is a value that names no level at all, before a whole
# outer loop is paid for.
check_event_level <- function(event_level, call = rlang::caller_env()) {
  named_a_level <- is.character(event_level) &&
    length(event_level) == 1L &&
    !is.na(event_level)

  if (named_a_level && event_level %in% c("first", "second")) {
    return(invisible(event_level))
  }

  cli::cli_abort(
    c(
      "{.arg event_level} must be {.val first} or {.val second}.",
      x = if (named_a_level) {
        "Got {.val {event_level}}."
      } else {
        "Got {.obj_type_friendly {event_level}}."
      }
    ),
    call = call
  )
}

# The iterating orchestrators' own arguments (D-040, D-046). All are tune's
# or finetune's, and each is refused here only where the upstream check is
# looser than a whole outer loop can afford: tune's `check_iter()` accepts
# `2.5`, and its `check_initial()` accepts a `tune_results` in place of a
# count. The classes are this package's, so a caller can catch the refusal as
# a refusal of that argument rather than by matching its message.
#
# `floor` is the smallest value the calling sibling accepts. `iter` is 0 for
# `nested_tune_bayes()` -- the initial candidates alone -- and 1 for
# `nested_tune_sim_anneal()`, because finetune 1.3.0 loops `(existing_iter +
# 1):iter`, which at `iter = 0` is `1:0`: two iterations, not none (measured
# 2026-09-02, M51). `initial` is 2 for Bayes, `tune_bayes()`'s own
# requirement, and 1 for annealing, finetune's default.

check_iter <- function(iter, floor = 0, call = rlang::caller_env()) {
  if (is_whole_number(iter) && iter >= floor) {
    return(invisible(iter))
  }
  cli::cli_abort(
    c(
      if (floor > 0) {
        "{.arg iter} must be a single whole number of at least {floor}."
      } else {
        "{.arg iter} must be a single non-negative whole number."
      },
      x = if (is_single_number(iter)) {
        "Got {.val {iter}}."
      } else {
        "Got {.obj_type_friendly {iter}}."
      }
    ),
    class = "nestedtune_bad_iter",
    call = call
  )
}

# A count only. tune also takes the result of an earlier `tune_grid()` run
# here, and that is refused rather than passed on: one tuning run cannot serve
# every outer fold, and its candidates were scored on resamples of data that
# may hold a fold's assessment rows -- the leak IP1 exists to forbid (D-040).
check_initial <- function(initial, floor = 2, call = rlang::caller_env()) {
  if (inherits(initial, "tune_results")) {
    cli::cli_abort(
      c(
        "{.arg initial} must be a number of candidates, not a \\
         {.cls tune_results}.",
        x = "One tuning run cannot serve every outer fold: its candidates \\
             were scored on resamples that may hold a fold's assessment rows.",
        i = "Give the number of candidates to score before the first \\
             iteration, and each fold generates and scores its own."
      ),
      class = "nestedtune_bad_initial",
      call = call
    )
  }
  if (is_whole_number(initial) && initial >= floor) {
    return(invisible(initial))
  }
  cli::cli_abort(
    c(
      "{.arg initial} must be a single whole number of at least {floor}.",
      x = if (is_single_number(initial)) {
        "Got {.val {initial}}."
      } else {
        "Got {.obj_type_friendly {initial}}."
      }
    ),
    class = "nestedtune_bad_initial",
    call = call
  )
}

check_objective <- function(objective, call = rlang::caller_env()) {
  if (inherits(objective, "acquisition_function")) {
    return(invisible(objective))
  }
  cli::cli_abort(
    c(
      "{.arg objective} must be an acquisition function from tune.",
      x = "Got {.obj_type_friendly {objective}}.",
      i = "Use {.fn tune::exp_improve}, {.fn tune::prob_improve} or \\
           {.fn tune::conf_bound}."
    ),
    class = "nestedtune_bad_objective",
    call = call
  )
}

is_whole_number <- function(x) {
  is_single_number(x) && is.finite(x) && x == trunc(x)
}

# Whether there is a value worth naming in the refusal: `2.5` is, a data frame
# is not.
is_single_number <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

# The dots, forced (D-042). The one formal is `...` itself, so a name a
# caller puts in the dots -- `call`, say -- has nothing else to bind to and
# reaches `check_dots_control()` as the argument it is. Forcing is where a
# control the caller built inline runs -- `control = tune::control_bayes()`
# draws its `seed` slot when it is built -- and that happens here, before the
# loop's own RNG snapshot; the draw is discarded by `effective_control()`, so
# the stream is put back where the caller left it (D-011's net-zero entry),
# and a run under an inline control is the run under the same control built
# beforehand. Unlike the loop's `restore_rng()`, a session that had no state
# is left with none: a state the forcing created is removed rather than kept,
# because the refusals downstream promise to fire before anything is drawn,
# and `RNGkind()` is never called here, since setting a kind is itself a
# draw. Assigning `.Random.seed` restores the kind with it.
capture_dots <- function(...) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = globalenv())
  on.exit(
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    },
    add = TRUE
  )
  rlang::list2(...)
}

# What `...` accepts on the two orchestrators (D-042): `control` and nothing
# else. There is no `control` formal -- tune's maintainer reserves that name
# for a future control of the outer work -- so the object comes through the
# dots, and every other name is refused here, at entry, with the argument
# named. An unnamed argument is refused too: everything after `resamples` is
# matched by name, so a positional value is a call that meant something else.
# `dots` is the list `capture_dots()` returns, never the dots themselves: a
# `call` in the caller's dots would bind to this function's `call` formal.
check_dots_control <- function(dots, call = rlang::caller_env()) {
  nms <- rlang::names2(dots)
  unknown <- nms[nms != "control"]
  if (length(unknown) > 0L) {
    named <- unknown[nzchar(unknown)]
    n_unnamed <- sum(!nzchar(unknown))
    cli::cli_abort(
      c(
        "{.arg ...} accepts {.arg control} and nothing else.",
        x = if (length(named) > 0L) "Got {.arg {named}}.",
        x = if (n_unnamed > 0L) {
          "Got {n_unnamed} unnamed argument{?s}; everything after {.arg resamples} is matched by name."
        }
      ),
      class = "nestedtune_bad_dots",
      call = call
    )
  }
  if (sum(nms == "control") > 1L) {
    cli::cli_abort(
      c(
        "{.arg ...} accepts {.arg control} and nothing else.",
        x = "Got {.arg control} {sum(nms == 'control')} times."
      ),
      class = "nestedtune_bad_dots",
      call = call
    )
  }
  dots[["control"]]
}

# The control, held to the tuner and to the `event_level` argument, and
# returned in its effective form (D-042). `tuner` is the tune function's name.
#
# Class first: tune's own `condense_control()` reads slots by name and would
# run `tune_grid()` under a `control_bayes()` without complaint, so what the
# matching `tune::control_*()` returns is the contract. Then `event_level`:
# the argument is the one place the level is set, and a control naming a
# level that is neither tune's default nor the argument's is a visible
# conflict, refused rather than silently overwritten. A control left at tune's
# default takes the argument's level -- a control object cannot tell a default
# "first" from a typed one, and refusing every disagreement would refuse
# `event_level = "second"` beside every untouched control (M48 gate).
check_control <- function(
  control,
  tuner,
  event_level,
  call = rlang::caller_env()
) {
  expected <- control_class(tuner)
  pkg <- tuner_entry(tuner)$package
  if (!is.null(control) && !inherits(control, expected)) {
    cli::cli_abort(
      c(
        "{.arg control} must be what {.fn {pkg}::{expected}} returns.",
        x = "Got {.obj_type_friendly {control}}."
      ),
      class = "nestedtune_bad_control",
      call = call
    )
  }
  level <- control[["event_level"]]
  if (
    !is.null(control) &&
      !identical(level, "first") &&
      !identical(level, event_level)
  ) {
    cli::cli_abort(
      c(
        "{.arg control} carries {.code event_level = {.val {level}}} while {.arg event_level} is {.val {event_level}}.",
        i = "Set the level once, as the {.arg event_level} argument; a control left at tune's default takes it."
      ),
      class = "nestedtune_bad_control",
      call = call
    )
  }
  effective_control(tuner, control, event_level)
}

# The packages a tuner needs, required before anything else is judged (M50,
# GP3): the registry's `requires` for the tuner -- finetune for the racers,
# and the package each race calls `rlang::check_installed()` on inside the
# first fold, which would otherwise prompt or fail there, one outer loop's
# worth of checks later. Asked through `rlang::is_installed()` so a test can
# mock the absence.
check_tuner_installed <- function(tuner, call = rlang::caller_env()) {
  pkgs <- tuner_entry(tuner)$requires
  missing <- pkgs[!vapply(pkgs, rlang::is_installed, logical(1))]
  if (length(missing) > 0L) {
    # One call the user can paste: `deparse()` gives `"pkg"` for one package
    # and `c("a", "b")` for several, where cli's collapse would give `"a" and "b"`.
    hint <- paste0("install.packages(", deparse(missing), ")")
    cli::cli_abort(
      c(
        "{.fn {tuner}} needs {.pkg {missing}}, which {?is/are} not installed.",
        i = "Install {?it/them} with {.code {hint}}."
      ),
      class = "nestedtune_pkg_not_installed",
      call = call
    )
  }
  invisible(pkgs)
}

# A race scores every candidate on `burn_in` inner resamples before it
# eliminates any, and finetune refuses a design whose resample count is not
# greater than that -- per fold, inside the loop, where M03 records it as a
# fold failure. Every outer fold's inner `rset` is judged here instead, at
# entry, so a design no fold can race is refused before any work is spent
# (GP3, M50 plan). `control` is the effective control, so `burn_in` is what
# will run; the failing folds are named by position with their counts.
check_race_burn_in <- function(resamples, control, call = rlang::caller_env()) {
  burn_in <- control[["burn_in"]]
  counts <- vapply(
    resamples$inner_resamples,
    function(inner) as.integer(NROW(inner)),
    integer(1)
  )
  short <- which(counts <= burn_in)
  if (length(short) > 0L) {
    detail <- paste(
      sprintf(
        "Outer fold %d holds %d inner resample%s",
        short,
        counts[short],
        ifelse(counts[short] == 1L, "", "s")
      ),
      collapse = "; "
    )
    cli::cli_abort(
      c(
        "A race needs more inner resamples than its {.arg burn_in} of \\
         {burn_in}.",
        x = "{detail}: not more than {burn_in}.",
        i = "Pass {.code control = control_race(burn_in = <fewer>)} \\
             or build the design with more inner resamples."
      ),
      class = "nestedtune_bad_burn_in",
      call = call
    )
  }
  invisible(counts)
}
