#' Run the nested cross-validation loop with racing inside
#'
#' `nested_tune_race_anova()` and `nested_tune_race_win_loss()` drive the
#' outer loop of nested cross-validation with finetune's two racing tuners,
#' [finetune::tune_race_anova()] and [finetune::tune_race_win_loss()], as the
#' inner tuner. For each outer fold the race scores every candidate in `grid`
#' on the first `burn_in` inner resamples, drops the candidates that are
#' already clearly worse than the best -- by a repeated-measures ANOVA, or by
#' a Bradley-Terry model of pairwise wins and losses -- and scores the
#' survivors on the remaining resamples, dropping more as the evidence comes
#' in; the fold then selects the best, finalizes the workflow, and fits and
#' scores it on the outer split with [tune::last_fit()]. Each is
#' [nested_tune_grid()] with the inner tuner swapped: the arguments, the loop,
#' the seeds, the results object and its methods are the same, and that
#' function's help page is the reference for everything the three share --
#' what a failed fold records, how the folds run in parallel, and what an
#' operation on the result may do.
#'
#' The estimate this returns describes the whole race-and-fit *procedure*, not
#' any single fitted model, exactly as for [nested_tune_grid()]; report it for
#' that procedure. No final model is returned here: build that with
#' [nested_final_fit()], which takes this result and races the same grid again
#' with the whole dataset in hand.
#'
#' Both functions need finetune installed; `nested_tune_race_anova()` also
#' needs lme4, which fits the ANOVA, and `nested_tune_race_win_loss()`
#' BradleyTerry2, which fits the win/loss model. A missing package is refused
#' at entry, before any fold runs.
#'
#' @inheritParams nested_tune_grid
#' @param ... A control object as `control` -- what [finetune::control_race()]
#'   returns -- and nothing else. It reaches the inner race in every fold, and
#'   in the final fit, with the slots this package forces overwritten; the
#'   section on differences from finetune says what becomes of each slot.
#'   Any other name is an error, as is an unnamed value.
#' @param grid A data frame of candidate parameter values, or a positive whole
#'   number giving the size of a grid to generate: the design the race is
#'   offered. Passed to the racing function, which scores every candidate on
#'   the burn-in resamples and only the survivors after that. A data frame is
#'   checked against the workflow before anything is fitted, as on
#'   [nested_tune_grid()].
#'
#' @return An object of class `nested_results`, one row per outer fold, with
#'   the columns [nested_tune_grid()] documents. One thing differs from a grid
#'   run, and it is the point of racing.
#'
#'   Each fold's `.inner_metrics` holds every candidate its race scored,
#'   eliminated candidates included -- `tune::collect_metrics(<the race>,
#'   all_configs = TRUE)`, where finetune's own default keeps the survivors
#'   alone -- and `n` is the number of inner resamples each candidate was
#'   scored on: the full inner resample count for a candidate that survived to
#'   the end, and fewer for one eliminated along the way. The recorded `grid`,
#'   on the `procedure` attribute and as `attr(x, "grid")`, is the design the
#'   race was *offered*, exactly as given; what each candidate *ran* is `n`.
#'   A candidate that failed on every inner resample is absent, and its
#'   failure is in `.notes`, as on the grid path.
#'
#'   `attr(x, "procedure")` names the tuner (`"tune_race_anova"` or
#'   `"tune_race_win_loss"`) and holds the `grid`, `param_info`,
#'   `event_level`, `eval_time` and the effective control, as
#'   [nested_tune_grid()] describes.
#'
#' @section Reproducibility:
#'
#' The seed contract is [nested_tune_grid()]'s: seed the session before the
#' call, there is no `seed` argument, `2 * n` seeds are drawn in one
#' `sample.int(.Machine$integer.max, 2 * n)` call on entry, and fold `i` races
#' under element `2 * i - 1` and fits under element `2 * i`, each applied with
#' the generator kind pinned.
#'
#' A race draws from the generator even with a deterministic engine: with
#' `randomize = TRUE` (finetune's default) the inner resamples are shuffled
#' before the burn-in, so which resamples the burn-in uses, and with it which
#' candidates are eliminated when, comes from the fold's tuning seed. Fold `i`
#' is exactly (with `resamples$inner_resamples[[i]]` read as
#' [nested_tune_grid()]'s reproducibility section reads it):
#'
#' ```
#' set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' control <- attr(res, "procedure")$control
#' raced <- tune_race_anova(object, resamples$inner_resamples[[i]],
#'                          grid = grid, param_info = param_info,
#'                          metrics = metrics, eval_time = eval_time,
#'                          control = control)   # or tune_race_win_loss()
#' final <- finalize_workflow(object, select_best(raced, metric = <first metric>))
#' set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' last_fit(final, resamples$splits[[i]], metrics = metrics,
#'          eval_time = eval_time,
#'          control = control_last_fit(event_level = event_level))
#' ```
#'
#' and `res$.inner_metrics[[i]]` is `collect_metrics(raced, all_configs =
#' TRUE)`, `res$.selected[[i]]` the `select_best()` above.
#'
#' The caller's RNG state and generator kind are restored on exit, including
#' when the call errors. The same seed gives the same result serially and in
#' parallel, at any number of daemons -- provided every daemon's library holds
#' finetune, which the loop attaches in each daemon before the first fold is
#' sent and warns about where it cannot.
#'
#' @section Differences from calling finetune directly:
#'
#' There is no `control` formal, but a [finetune::control_race()] passed
#' through `...` as `control` reaches the inner race in every fold, and in the
#' final fit that re-runs the result -- `control = control_race(burn_in = 2)`,
#' say, on a design with three inner resamples. What runs is the control
#' passed, or finetune's default when none is, with the slots this package
#' forces overwritten; the result records that effective control as
#' `attr(res, "procedure")$control`, which is what the recipe above passes.
#' Every slot of `control_race()` falls under one of six headings.
#'
#' **Forced: `allow_par`.** Both tune calls a fold makes -- the inner race and
#' the outer scoring fit -- run at `allow_par = FALSE`, whatever the control
#' carries. Parallelism belongs over the outer folds, and leaving that to a
#' caller would put two pools in contention.
#'
#' **Settable as its own argument: `event_level`.** As on [nested_tune_grid()]:
#' the argument is the one place the level is set, a control left at
#' finetune's default takes it, and a control naming a level that is neither
#' finetune's default nor the argument's is refused at entry, naming both.
#' `grid` and `eval_time` are the racing functions' own arguments rather than
#' control slots, offered here as arguments and reaching them unchanged.
#'
#' **Refused: none.** No slot is refused on its own. What is refused at entry
#' is a control of another class -- a `control_grid()`, which finetune itself
#' would accept here -- the `event_level` conflict above, and a `burn_in` no
#' fold's inner design can meet: finetune refuses a race whose resample count
#' is not greater than `burn_in`, and this package refuses the whole call
#' before any fold runs when any outer fold's inner `rset` would be, naming
#' the count and the burn-in. `control_race()` defaults `burn_in` to 3, so a
#' design with three inner resamples needs `control = control_race(burn_in =
#' 2)` or fewer.
#'
#' **Passed through: `burn_in`, `alpha`, `num_ties`, `randomize`,
#' `verbose_elim`, `verbose`, `pkgs`, `parallel_over`, `workflow_size`.**
#' Each reaches the race as given. `burn_in`, `alpha`, `num_ties` and
#' `randomize` govern each fold's race as they would a direct call: how many
#' resamples every candidate is scored on before elimination starts, the
#' significance level an elimination needs, how many rounds two tied
#' survivors are given before one is dropped, and whether the resamples are
#' shuffled first -- the draw the section above describes. `verbose_elim`
#' prints finetune's elimination log from a serial run, once per fold, and
#' from a mirai daemon where nothing shows it; `verbose` likewise. `pkgs`,
#' `parallel_over` and `workflow_size` behave as on [nested_tune_grid()],
#' `parallel_over` included: it changes the numbers a stochastic engine
#' produces even at `allow_par = FALSE`.
#'
#' **Not returned: `extract`, `save_pred`, `save_workflow`.** As on
#' [nested_tune_grid()]: each lands on the inner race result a fold record
#' discards, so on a nested run setting them costs the work and returns
#' nothing; the final fit keeps its race as `$tuning`, where what they saved
#' is reachable.
#'
#' **Inert: `backend_options`.** Options for a parallel backend, with no
#' backend to reach at `allow_par = FALSE`.
#'
#' @examples
#' \donttest{
#' if (rlang::is_installed(c("finetune", "lme4", "recipes", "yardstick"))) {
#'   data(mtcars)
#'
#'   rec <- recipes::step_pca(
#'     recipes::recipe(mpg ~ ., data = mtcars),
#'     recipes::all_predictors(),
#'     num_comp = tune::tune()
#'   )
#'   wf <- workflows::workflow(rec, parsnip::linear_reg())
#'
#'   set.seed(1)
#'   folds <- nested_resamples(
#'     mtcars,
#'     outside = rsample::vfold_cv(v = 3),
#'     inside = rsample::vfold_cv(v = 5)
#'   )
#'
#'   set.seed(2)
#'   res <- nested_tune_race_anova(
#'     wf,
#'     folds,
#'     grid = data.frame(num_comp = 1:4),
#'     control = finetune::control_race(burn_in = 2, verbose_elim = FALSE)
#'   )
#'   collect_metrics(res)
#'
#'   # Every candidate the first fold's race scored, and on how many inner
#'   # resamples: `n` below 5 is a candidate the race eliminated.
#'   res$.inner_metrics[[1]]
#' }
#' }
#'
#' @seealso [nested_tune_grid()], [nested_tune_bayes()], [nested_resamples()],
#'   [nested_final_fit()], [finetune::tune_race_anova()],
#'   [finetune::tune_race_win_loss()]
#' @name nested_tune_race
NULL

#' @rdname nested_tune_race
#' @export
nested_tune_race_anova <- function(
  object,
  resamples,
  ...,
  param_info = NULL,
  grid = 10,
  metrics = NULL,
  event_level = "first",
  eval_time = NULL
) {
  nested_tune_race(
    "tune_race_anova",
    object,
    resamples,
    dots = capture_dots(...),
    param_info = param_info,
    grid = grid,
    metrics = metrics,
    event_level = event_level,
    eval_time = eval_time,
    call = rlang::current_env()
  )
}

#' @rdname nested_tune_race
#' @export
nested_tune_race_win_loss <- function(
  object,
  resamples,
  ...,
  param_info = NULL,
  grid = 10,
  metrics = NULL,
  event_level = "first",
  eval_time = NULL
) {
  nested_tune_race(
    "tune_race_win_loss",
    object,
    resamples,
    dots = capture_dots(...),
    param_info = param_info,
    grid = grid,
    metrics = metrics,
    event_level = event_level,
    eval_time = eval_time,
    call = rlang::current_env()
  )
}

# The one body behind the two racing exports (M50). The exports differ in
# nothing but the registry key, so the checks and the loop are written once;
# `call` is the export's frame, so every refusal and the run's warnings name
# the function the user called. The checks run in the grid orchestrator's
# order, with the two that are racing's own -- the packages the race needs,
# and the burn-in against every fold's inner design -- at the two ends: the
# packages first, before anything is judged that could not run anyway, and
# the burn-in last, once the control is effective and the design is known to
# be a design (GP3).
nested_tune_race <- function(
  fn,
  object,
  resamples,
  dots,
  param_info,
  grid,
  metrics,
  event_level,
  eval_time,
  call
) {
  check_tuner_installed(fn, call = call)
  control <- check_dots_control(dots, call = call)
  check_workflow(object, call = call)
  check_nested(resamples, call = call)
  check_grid(grid, call = call)
  check_grid_params(object, grid, call = call)
  check_metrics(metrics, call = call)
  check_param_info(param_info, call = call)
  check_event_level(event_level, call = call)
  check_eval_time(eval_time, call = call)
  control <- check_control(control, fn, event_level, call = call)
  check_race_burn_in(resamples, control, call = call)

  nested_loop(
    object,
    resamples,
    tuner = tuner_race(fn, grid),
    metrics = metrics,
    param_info = param_info,
    event_level = event_level,
    eval_time = eval_time,
    control = control,
    grid = grid,
    call = call
  )
}
