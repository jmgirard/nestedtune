#' Run the nested cross-validation loop with Bayesian optimization inside
#'
#' `nested_tune_bayes()` drives the outer loop of nested cross-validation with
#' [tune::tune_bayes()] as the inner tuner. For each outer fold it scores an
#' initial set of candidates on that fold's inner resamples, lets a Gaussian
#' process propose the next `iter` candidates one at a time, selects the best,
#' finalizes the workflow, and fits and scores it on the outer split with
#' [tune::last_fit()]. It is [nested_tune_grid()] with the inner tuner swapped:
#' the loop, the seeds, the results object and its methods are the same, and
#' that function's help page is the reference for everything the two share --
#' what a failed fold records, how the folds run in parallel, and what an
#' operation on the result may do.
#'
#' The estimate this returns describes the whole search-and-fit *procedure*,
#' not any single fitted model, exactly as for [nested_tune_grid()]; report it
#' for that procedure. No final model is returned here: build that with
#' [nested_final_fit()], which takes this result and runs the search it
#' recorded again with the whole dataset in hand.
#'
#' @inheritParams nested_tune_grid
#' @param param_info A [dials::parameters()] object, or `NULL` to let tune
#'   derive one from the workflow. Passed unchanged to [tune::tune_bayes()] on
#'   every outer fold: the initial candidates are drawn from its ranges, and
#'   every proposal stays inside them.
#' @param iter The maximum number of search iterations, passed to
#'   [tune::tune_bayes()]. A single non-negative whole number. Each iteration
#'   proposes one candidate and scores it on the fold's inner resamples. `0`
#'   scores the initial candidates and proposes nothing, which makes the run
#'   the same as [nested_tune_grid()] on the space-filling grid those
#'   candidates form. tune stops a fold's search early when no unscored
#'   candidate remains, saying so on the console and keeping what it has, and
#'   after ten consecutive iterations without improvement (its `no_improve`
#'   default, not settable here); the fold completes with the candidates
#'   scored so far, and nothing about the early stop reaches `.notes`.
#' @param initial The number of candidates to score before the first
#'   iteration: a single whole number of at least 2. Each fold generates its own
#'   space-filling set of that size from the parameter ranges with
#'   [dials::grid_space_filling()] and scores it with [tune::tune_grid()], under
#'   the fold's own tuning seed. A `tune_results` object, which
#'   [tune::tune_bayes()] also accepts here, is refused: one tuning run cannot
#'   serve every outer fold, and its candidates were scored on resamples that
#'   may hold a fold's assessment rows.
#' @param objective An acquisition function from tune, deciding which candidate
#'   the Gaussian process proposes next: [tune::exp_improve()] (the default),
#'   [tune::prob_improve()] or [tune::conf_bound()].
#'
#' @return An object of class `nested_results`, one row per outer fold, with
#'   the columns [nested_tune_grid()] documents. Two things differ from a grid
#'   run.
#'
#'   Each fold's `.grid` -- the candidates its inner search actually scored --
#'   carries an `.iter` column beside the parameter columns and `.config`: `0`
#'   for the initial candidates and `i` for the candidate the `i`-th iteration
#'   proposed. Every candidate that scored on at least one inner resample is a
#'   row, so a fold that stopped early holds the rows it reached. As on the
#'   grid path, a candidate that failed on every inner resample is absent, and
#'   its failure is in `.notes`.
#'
#'   There is no `grid` attribute: `attr(x, "grid")` is `NULL`, because nothing
#'   was asked for as a grid. What was asked for is on the `procedure`
#'   attribute, which every result of either orchestrator carries: a named list
#'   giving the tuner (`"tune_bayes"` here, `"tune_grid"` there), that tuner's
#'   own arguments (`iter`, `initial` and `objective` here, `grid` there), and
#'   `param_info`, `event_level` and `eval_time` on both. `attr(x, "metrics")`
#'   holds the `metrics` argument as on the grid path, absent when none was
#'   given. The record describes the call, so it travels with the class through
#'   every dplyr and vctrs door the grid path's help page describes, and is
#'   shed with the class by the operations that shed it.
#'
#' @section Reproducibility:
#'
#' The seed contract is [nested_tune_grid()]'s: seed the session before the
#' call, there is no `seed` argument, `2 * n` seeds are drawn in one
#' `sample.int(.Machine$integer.max, 2 * n)` call on entry, and fold `i` tunes
#' under element `2 * i - 1` and fits under element `2 * i`, each applied with
#' the generator kind pinned.
#'
#' One rule is this function's own. [tune::control_bayes()] has a `seed` slot
#' that drives the Gaussian-process proposals, and tune draws it from the
#' stream when it is not given -- so left alone, a fold's proposals would depend
#' on how much of the stream tune had consumed before reaching it. Here the
#' control is given `seed` inside the fold's seed scope, set to the fold's
#' tuning seed, the same number `.tuning_seed` reports; the recorded control
#' carries no `seed` for that reason. Fold `i` is exactly:
#'
#' ```
#' set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' control <- attr(res, "procedure")$control
#' control$seed <- res$.tuning_seed[[i]]
#' tuned <- tune_bayes(object, resamples$inner_resamples[[i]],
#'                     iter = iter, initial = initial, objective = objective,
#'                     param_info = param_info, metrics = metrics,
#'                     eval_time = eval_time, control = control)
#' final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
#' set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' last_fit(final, resamples$splits[[i]], metrics = metrics,
#'          eval_time = eval_time,
#'          control = control_last_fit(event_level = event_level))
#' ```
#'
#' The caller's RNG state and generator kind are restored on exit, including
#' when the call errors. The same seed gives the same result serially and in
#' parallel, at any number of daemons.
#'
#' @section Differences from calling tune directly:
#'
#' There is no `control` formal, but a [tune::control_bayes()] passed through
#' `...` as `control` reaches the inner `tune_bayes()` in every fold, and in
#' the final fit that re-runs the result -- `control = control_bayes(no_improve
#' = 5, uncertain = 3)`, say, to stop a fold's search sooner. What runs is the
#' control passed, or tune's default when none is, with the slots this package
#' forces overwritten; the result records that effective control, `seed` left
#' out, as `attr(res, "procedure")$control`, which is what the recipe above
#' passes. Every slot of `control_bayes()` falls under one of six headings.
#'
#' **Forced: `allow_par`, `seed`.** `allow_par = FALSE` on both tune calls a
#' fold makes, because parallelism belongs over the outer folds; and `seed`,
#' set to the fold's tuning seed inside that seed's scope, as the section
#' above describes -- whatever the control carries for either.
#'
#' **Settable as its own argument: `event_level`.** As on [nested_tune_grid()]:
#' the argument is the one place the level is set, a control left at tune's
#' default takes it, and a control naming a level that is neither tune's
#' default nor the argument's is refused at entry, naming both. `iter`,
#' `initial`, `objective` and `eval_time` are [tune::tune_bayes()]'s own
#' arguments rather than control slots, offered here as arguments and reaching
#' it unchanged. `initial` is a count only: tune also accepts an earlier
#' `tune_grid()` result there, and this function refuses one, for the reason
#' the argument's description gives.
#'
#' **Refused: none.** No slot is refused on its own. What is refused at entry
#' is a control of another class -- a `control_grid()`, which tune itself
#' would accept here -- and the `event_level` conflict above.
#'
#' **Passed through: `no_improve`, `uncertain`, `time_limit`, `verbose`,
#' `verbose_iter`, `save_gp_scoring`, `pkgs`, `parallel_over`,
#' `workflow_size`.** Each reaches `tune_bayes()` as given. `no_improve` and
#' `uncertain` govern each fold's search as they would a direct call, so a
#' fold may stop short of `iter`, and its `.grid` records how far it went.
#' `time_limit` is a wall-clock stop, and a wall-clock stop makes the
#' candidate set depend on the machine: two runs under the same seed can stop
#' at different iterations, which is outside what the seed contract above can
#' promise. `verbose` and `verbose_iter` print from a serial run, and from a
#' mirai daemon where nothing shows it. `save_gp_scoring` writes its files to
#' the temporary directory of the process that tuned, a daemon's own on the
#' parallel path. `pkgs`, `parallel_over` and `workflow_size` behave as on
#' [nested_tune_grid()], `parallel_over` included: it changes the numbers a
#' stochastic engine produces even at `allow_par = FALSE`.
#'
#' **Not returned: `extract`, `save_pred`, `save_workflow`.** As on
#' [nested_tune_grid()]: each lands on the inner `tune_results` a fold record
#' discards, so setting them costs the work and returns nothing.
#'
#' **Inert: `backend_options`.** Options for a parallel backend, with no
#' backend to reach at `allow_par = FALSE`.
#'
#' @examples
#' \donttest{
#' if (rlang::is_installed(c("recipes", "yardstick"))) {
#'   data(mtcars)
#'
#'   # Two tunable steps, so the search has candidates to propose.
#'   rec <- recipes::step_pca(
#'     recipes::step_ns(
#'       recipes::recipe(mpg ~ ., data = mtcars),
#'       disp,
#'       deg_free = tune::tune()
#'     ),
#'     recipes::all_predictors(),
#'     num_comp = tune::tune()
#'   )
#'   wf <- workflows::workflow(rec, parsnip::linear_reg())
#'
#'   set.seed(1)
#'   folds <- nested_resamples(
#'     mtcars,
#'     outside = rsample::vfold_cv(v = 3),
#'     inside = rsample::vfold_cv(v = 3)
#'   )
#'
#'   set.seed(2)
#'   res <- nested_tune_bayes(wf, folds, iter = 2, initial = 3)
#'   collect_metrics(res)
#'
#'   # What each fold searched: the initial candidates at `.iter` 0, then one
#'   # proposal per iteration.
#'   res$.grid[[1]]
#' }
#' }
#'
#' @seealso [nested_tune_grid()], [nested_resamples()], [nested_final_fit()],
#'   [tune::tune_bayes()]
#' @export
nested_tune_bayes <- function(
  object,
  resamples,
  ...,
  iter = 10,
  param_info = NULL,
  metrics = NULL,
  initial = 5,
  objective = tune::exp_improve(),
  event_level = "first",
  eval_time = NULL
) {
  control <- check_dots_control(...)
  check_workflow(object)
  check_nested(resamples)
  check_iter(iter)
  check_initial(initial)
  check_objective(objective)
  check_metrics(metrics)
  check_param_info(param_info)
  check_event_level(event_level)
  check_eval_time(eval_time)
  control <- check_control(control, "tune_bayes", event_level)

  nested_loop(
    object,
    resamples,
    tuner = tuner_bayes(iter = iter, initial = initial, objective = objective),
    metrics = metrics,
    param_info = param_info,
    event_level = event_level,
    eval_time = eval_time,
    control = control,
    grid = NULL,
    call = rlang::current_env()
  )
}
