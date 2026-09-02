#' Run the nested cross-validation loop
#'
#' `nested_tune_grid()` drives the outer loop of nested cross-validation. For
#' each outer fold it tunes on that fold's inner resamples with
#' [tune::tune_grid()], selects the best candidate, finalizes the workflow, and
#' fits and scores it on the outer split with [tune::last_fit()]. Every step is
#' delegated to tune; what this function contributes is the loop, the
#' reproducibility contract, and a results object that keeps each fold's chosen
#' parameters rather than discarding them.
#'
#' The estimate this returns describes the whole tune-and-fit *procedure*, not
#' any single fitted model. It is not the performance of a model you can deploy,
#' and no final model is returned here: build that with [nested_final_fit()],
#' which takes this result and runs the procedure it recorded again with the
#' whole dataset in hand. The estimate from this function is what you report
#' for it.
#'
#' For a Bayesian inner loop -- [tune::tune_bayes()] proposing candidates one
#' at a time -- see [nested_tune_bayes()], which runs this same outer loop with
#' the inner tuner swapped.
#'
#' @param object A [workflows::workflow()] with at least one parameter marked
#'   for tuning with [tune::tune()].
#' @param ... A control object as `control` -- what [tune::control_grid()]
#'   returns for `nested_tune_grid()`, what [tune::control_bayes()] returns for
#'   `nested_tune_bayes()` -- and nothing else. It reaches the inner tuning
#'   call in every fold, and in the final fit, with the slots this package
#'   forces overwritten; the section on differences from tune says what
#'   becomes of each slot. Any other name is an error, as is an unnamed
#'   value: everything after `...` is matched by name, so a mistyped or
#'   unsupported argument is an error rather than a silent positional match.
#' @param resamples A nested resampling design, from [nested_resamples()] or
#'   [rsample::nested_cv()]. Its `splits` column must hold `rsplit` objects and
#'   its `inner_resamples` column an `rset` per outer fold. Both are checked
#'   before anything is fitted, because [rsample::nested_cv()] builds a design
#'   whatever its `inside` argument returned — so a specification that produces
#'   no `rset` gives a design that cannot be run, where [nested_resamples()]
#'   refuses one at construction.
#' @param param_info A [dials::parameters()] object, or `NULL` to let tune
#'   derive one from the workflow. Passed unchanged to [tune::tune_grid()] on
#'   every outer fold, so a restricted range restricts the grid every fold
#'   searches.
#' @param grid A data frame of candidate parameter values, or a positive whole
#'   number giving the size of a grid to generate. Passed to
#'   [tune::tune_grid()]. A data frame is checked against the workflow before
#'   anything is fitted: every column must name a parameter marked with
#'   [tune::tune()], and every such parameter must have a column.
#' @param metrics A [yardstick::metric_set()], or `NULL` to use tune's defaults
#'   for the model's mode. The first metric in the set selects the best inner
#'   candidate.
#' @param event_level `"first"` (the default) or `"second"`, naming which level
#'   of a two-class outcome factor is the event. It reaches both loops: the
#'   inner tuning run, where it decides which candidate is selected, and the
#'   outer scoring fit, where it decides what the reported metrics mean.
#'   Metrics that do not distinguish the two levels -- accuracy, `roc_auc`,
#'   `brier_class` -- are unaffected by it; `sens`, `spec`, `precision` and
#'   their relatives are not. Ignored for a regression model, as it is in tune.
#'
#' @param eval_time A numeric vector of evaluation times for a censored
#'   regression model, or `NULL` (the default) to leave the choice to tune. It
#'   reaches every tune call whose answer depends on it, so a dynamic or
#'   integrated survival metric -- `brier_survival()`, `roc_auc_survival()` and
#'   their relatives -- is measured at the times you name. It is ignored, with
#'   a warning from tune, whenever the metric set has no metric that reads it.
#'   tune keys that warning on the metrics rather than on the model's mode: a
#'   set with no survival metric draws one saying the argument is only used
#'   for censored regression, and a censored regression model scored only by a
#'   static metric such as `concordance_survival()` draws a different one,
#'   saying it is only used for dynamic or integrated survival metrics.
#'
#'   Refused here, ahead of tune: anything that is not numeric, an empty
#'   vector, and any element that is missing, negative or not finite. tune
#'   treats those unevenly, and only once a metric reads the times -- a
#'   character value that reads as a number, such as `"1"`, is coerced with
#'   `as.numeric()` and accepted, one that does not becomes missing; a
#'   missing, negative or infinite element is dropped with a warning; and an
#'   empty vector, or one that dropping has emptied, aborts -- and this package
#'   refuses them all at entry, before a whole run is paid for. Zero, repeated
#'   times and times out of order are accepted and passed on untouched, since
#'   tune normalizes those itself; a repeated time draws tune's warning that 0
#'   inappropriate evaluation time points were removed, once per tune call.
#'
#' @return An object of class `nested_results`: one row per outer fold, with the
#'   fold's split and id, the metrics scored on its assessment set
#'   (`.metrics`), the parameters chosen for it by inner tuning (`.selected`),
#'   the inner tuning run's own metrics (`.inner_metrics`), whether the fold
#'   finished (`.completed`), anything that went wrong (`.notes`), and the two
#'   seeds that reproduce it (`.tuning_seed`, `.outer_fit_seed`). Use
#'   [collect_metrics()] to summarize.
#'
#'   **Two records describe the grid, and they answer different questions.**
#'   `attr(x, "grid")` holds the `grid` argument **as it was given** — a
#'   positive whole number, not a table of candidates, whenever a size was
#'   passed. The `.inner_metrics` column holds what each outer fold's inner
#'   tuning actually scored: [tune::collect_metrics()] of that fold's tuning
#'   run, one table per fold with a column per tuned parameter, one row per
#'   candidate and metric, and tune's `.metric`, `.estimator`, `mean`, `n`,
#'   `std_err` and `.config` columns, with `.eval_time` beside them when a
#'   dynamic survival metric was scored. The candidates a fold searched are the
#'   table's distinct parameter rows. Ranking those rows on one metric by
#'   `mean` reproduces the fold's `.selected` except where candidates tie,
#'   which [tune::select_best()] resolved on the inner run in its own order;
#'   `.selected` records the candidate the fold's outer fit used.
#'
#'   The two diverge routinely, in both directions. A size is expanded by tune
#'   and may reach fewer candidates than were asked for — a request for 20 on a
#'   parameter with four reachable values evaluates four — and a candidate that
#'   fails scores nothing. Folds can also differ from *each other*: expanding a
#'   size draws from the generator, and each fold tunes under its own seed, so
#'   a continuous parameter gives every fold its own candidates. Printing says
#'   so when it happens.
#'
#'   One limit is worth stating plainly. `.inner_metrics` is tune's summary of
#'   the tuning run, and a candidate that failed on **every** inner resample
#'   scored nothing: it has no row there — `.notes` is where its failure is
#'   recorded. A candidate that failed on some inner resamples and scored on
#'   others has its rows, with `n` below the inner resample count. A fold that
#'   scored no candidate at all carries a zero-row table with a completed
#'   fold's columns, never `NULL`.
#'
#'   `attr(x, "metrics")` holds the `metrics` argument, and is absent rather
#'   than `NULL` when none was supplied. `.inner_metrics` is a column, so it
#'   travels with the fold it describes.
#'
#'   `attr(x, "procedure")` records what ran, on the result of either
#'   orchestrator: a named list giving the tuner (`"tune_grid"` here,
#'   `"tune_bayes"` from [nested_tune_bayes()]), that tuner's own arguments
#'   (`grid` here; `iter`, `initial` and `objective` there), and `param_info`,
#'   `event_level` and `eval_time` on both. A Bayesian result carries the
#'   `procedure` attribute and no `grid` attribute, and its `.inner_metrics`
#'   tables carry an `.iter` column; [nested_tune_bayes()] documents both.
#'
#'   **What an operation on the object may and may not do.** The result carries
#'   the invariants `tune` declares on its own results objects:
#'
#'   * rows may be reordered, but never added or removed;
#'   * columns may be added or reordered;
#'   * every column listed above must still be present, holding the values it
#'     held.
#'
#'   The columns the run is recorded in are the ones the resampling design
#'   named, and `nested_tune_grid()` records them when it builds the result. So
#'   a column you add afterwards is read as a fold label only when the design
#'   itself carries a column of that name — `id`, and `id2` for a repeated
#'   design. The name you pick decides nothing on its own: adding `id2` to a
#'   result from a plain v-fold design leaves the class, the record and the
#'   fold labels alone, exactly as adding `extra` does.
#'
#'   An operation that stays inside those rules — `arrange()`, `mutate()`
#'   adding a column, a join that matches one row apiece — returns a
#'   `nested_results` with the call's record intact. Anything else — `slice()`,
#'   a `filter()` that drops a fold, `bind_rows()`, `x[1, ]`, dropping one of
#'   the columns above — returns a bare tibble, with the record removed along
#'   with the class. A three-row object cannot honestly describe itself as the
#'   ten-fold design it was cut from, so it stops describing itself at all and
#'   hands back the data.
#'
#'   It is one rule, reached through four doors. dplyr's verbs and `[` reach it
#'   through a `dplyr_reconstruct()` method; **vctrs**' own verbs —
#'   `vec_slice()`, `vec_rbind()`, `vec_c()`, `vec_cbind()`, `vec_ptype()` and
#'   `vec_cast()` — reach it through `vec_restore()`; and `rbind()` and
#'   `rename()`, which reach neither generic, have methods of their own. So
#'   `rbind(x, x)` and a `rename()` that moves one of the columns above hand
#'   back a bare tibble, the same answer `slice()` gives, rather than an object
#'   whose record has stopped describing its own rows.
#'
#'   Combining is the one place the doors part. `vctrs::vec_rbind(x)` and
#'   `vctrs::vec_c(x)` hand back a bare tibble even with nothing to combine `x`
#'   with, where `dplyr::bind_rows(x)` returns a `nested_results`: vctrs asks
#'   for the common type before it asks the rule anything, and the common type
#'   of one results object is a plain table. Every combination of two or more
#'   returns a bare tibble through either door, which is the rule above.
#'
#'   Column-binding is the one place argument order shows. `bind_cols()` and
#'   `vec_cbind()` both build their answer on the first argument's type, so
#'   `bind_cols(x, extra)` and `vec_cbind(x, extra)` are a `nested_results`
#'   while `bind_cols(extra, x)` and `vec_cbind(extra, x)` are plain tibbles
#'   holding the same ten columns. Either verb answers the same way in either
#'   position.
#'
#'   Three verbs sit outside all of it. `group_by()`, `rowwise()` and
#'   `tibble::as_tibble()` return a grouped, a rowwise and a plain tibble
#'   respectively — none of them a `nested_results` — and each carries the
#'   attributes across, so `attr(dplyr::group_by(x, id), "outer_label")` still
#'   answers with the run's scheme. Nothing they hand back claims to be a
#'   results object; the record is along for the ride.
#'
#' @section Reproducibility:
#'
#' Seed the session before the call, as elsewhere in tidymodels; there is no
#' `seed` argument. On entry the function draws `2 * n` seeds in a single
#' `sample.int(.Machine$integer.max, 2 * n)` call, where `n` is the number of
#' outer folds. Fold `i` uses element `2 * i - 1` for its tuning step and
#' element `2 * i` for its outer fit, each applied with the generator kind
#' pinned. Because a fold's seed depends on its position and not on the order
#' folds are executed in, the result is the same however the loop is scheduled.
#'
#' This makes any single fold reproducible by hand. Fold `i` is exactly:
#'
#' ```
#' set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' tuned <- tune_grid(object, resamples$inner_resamples[[i]], grid = grid,
#'                    metrics = metrics, eval_time = eval_time,
#'                    control = attr(res, "procedure")$control)
#' final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
#' set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' last_fit(final, resamples$splits[[i]], metrics = metrics,
#'          eval_time = eval_time,
#'          control = control_last_fit(event_level = event_level))
#' ```
#'
#' The caller's RNG state and generator kind are restored on exit, including
#' when the call errors, so a seeded script that draws afterwards is unaffected
#' — the same contract [tune::tune_grid()] gives. One consequence worth knowing:
#' two consecutive calls with no `set.seed()` between them return identical
#' results, exactly as repeated `tune_grid()` calls do.
#'
#' This binds randomness that flows through R's generator. Engines that
#' randomize outside it — kernlab's SVMs, the deep-learning engines — cannot be
#' pinned by any R-side scheme, here or in tune.
#'
#' @section When a fold fails:
#'
#' A fold that fails does not end the run. The remaining folds still run, and
#' the fold that failed is recorded rather than discarded: `.completed` is
#' `FALSE` for it and `.notes` holds what went wrong, in the same shape tune
#' uses — one row naming the stage that failed (`"inner tuning"` or
#' `"outer fit"`), followed by tune's own notes about the underlying cause.
#' The number of folds attempted and the number completed are stored on the
#' object as the `folds_attempted` and `folds_completed` attributes.
#'
#' Both stages can fail quietly. Inner tuning raises only once every candidate
#' has failed, and the outer fit does not raise at all — it hands back a result
#' with no metrics. Both are recorded as failures here.
#'
#' A fold can also complete *and* carry notes. When only some of a fold's inner
#' resamples fail, tuning still returns a candidate and the fold finishes, but
#' its parameters were chosen on less of the inner design than was asked for.
#' Those notes are kept, so `.completed` being `TRUE` with a non-empty `.notes`
#' means exactly that: it worked, on less than the whole design.
#'
#' A failed fold still records the candidates it got as far as scoring, whatever
#' stage it failed at. A fold that died at the outer fit had already tuned, so
#' its `.inner_metrics` holds the full table — and so does one that tuned
#' successfully and then failed while selecting from the results. Only a fold
#' that never reached a scored candidate at all — tuning itself raised, or every
#' candidate failed — holds a zero-row table. No fold is reported as having
#' searched a grid it did not.
#'
#' Any operation outside the invariants stated under **Value** above returns a
#' bare tibble, and both counts go with the class rather than being recomputed
#' for whatever rows are left. Dropping the `.completed` column is one such
#' operation.
#'
#' The run warns when it finishes with any fold unfinished, and
#' [collect_metrics()] warns again, summarizing only the folds that ran and
#' reporting how many those were. It refuses outright when no fold completed:
#' an estimate is never reported for a design that did not execute.
#'
#' @section Parallel execution:
#'
#' The outer folds run in parallel when you have started mirai daemons, and
#' serially otherwise. There is no argument for this — start daemons before the
#' call and the loop uses them:
#'
#' ```
#' mirai::daemons(4)
#' res <- nested_tune_grid(wf, folds, grid = grid)
#' mirai::daemons(0)
#' ```
#'
#' Two or more daemons are needed before the loop dispatches; below that it
#' stays serial, the same threshold `tune` applies. Inner tuning always runs
#' serially whatever you set, because nested parallelism oversubscribes cores.
#'
#' **Results do not depend on how the loop ran.** The same seed gives the same
#' result serially and in parallel, at any number of daemons — each fold's seeds
#' are drawn up front and assigned by position, so a fold's outcome depends on
#' where it sits in the design and never on which worker took it or in what
#' order. One exception, and it carries no numbers: the backtraces stored in
#' `.notes` record where a fold executed, so a fold that failed on a daemon
#' carries that daemon's call stack rather than yours. The note text, its
#' location, and its type are the same either way, though a daemon wraps long
#' message lines to its own console width rather than your terminal's.
#'
#' **Each fold is sent one copy of the data, not one per inner split.** A
#' resampling split carries the whole frame it indexes, and sending a fold to a
#' daemon means serializing it — which does not preserve the single shared copy
#' the design holds in memory. Each fold's splits are therefore emptied before
#' dispatch and refilled on the worker, so what crosses is the fold's row
#' indices plus one copy of the data rather than one copy per split. On a design
#' built by [nested_resamples()] that is one copy per fold; a design from
#' [rsample::nested_cv()] materializes an analysis frame per outer fold, so each
#' fold also carries its own, still once rather than once per inner split.
#'
#' Two things this does not reach, both of them objects you supply rather than
#' anything the package builds. A recipe keeps a copy of the data it was created
#' with, and a formula carries the environment it was written in — so a workflow
#' built inside a function that holds a large object sends that object with
#' every fold. Building the workflow at the top level avoids the second.
#'
#' Daemons are **separate R processes**, which has consequences worth knowing:
#'
#' - They do not inherit your session's options, your `.libPaths()` changes, or
#'   environment variables you set after launching them. Set what a fold needs
#'   with [mirai::everywhere()], or start the daemons after setting it.
#' - They load nestedtune from an installed library. Running under
#'   `devtools::load_all()` is not enough — the daemons cannot see it, and the
#'   call stops rather than failing every fold with the same opaque note. During
#'   development, prime them with
#'   `mirai::everywhere(pkgload::load_all("<path>"))`.
#' - Before dispatching, the call asks **every** connected daemon whether it can
#'   load the package, and stops if any of them cannot. A pool whose daemons
#'   differ — one respawned, or started against a different library — therefore
#'   fails here, naming how many are affected, rather than as a run in which
#'   some folds come back as opaque worker failures.
#' - The same round trip asks each daemon which of this session's internal
#'   functions its own copy of the package defines, and stops if any are
#'   missing. A daemon holding an *older install* loads the package perfectly
#'   well and then fails every fold, because the worker resolves what it needs
#'   by name inside that daemon's copy. The error names the missing functions
#'   and asks you to reinstall and then restart the pool — a running daemon
#'   keeps the namespace it has already loaded, so reinstalling underneath one
#'   changes nothing until it is replaced.
#' - A daemon that does not answer at all is reported as a non-response, not as
#'   a missing package, so a merely slow daemon is never met with advice to
#'   install what you already have. The check waits 30 seconds by default; set
#'   `options(nestedtune.preflight_timeout = <milliseconds>)` to raise or lower
#'   that, to a single positive, finite number. Nothing statistical depends on
#'   it.
#' - The first parallel call after starting daemons is the slow one: the check
#'   is what makes every daemon load the package, and the whole tidymodels
#'   stack is not cheap to load. Because the check now waits for *all* of them
#'   rather than whichever answers first, a cold pool on a loaded machine can
#'   need more than the default 30 seconds — raise the option if you see a
#'   non-response you do not believe. Later calls in the same session reuse
#'   what the daemons already loaded.
#' - That check is bounded; the folds themselves are not. If every daemon dies
#'   *after* folds are dispatched, the call blocks waiting for results that will
#'   never arrive, and you interrupt it. No per-fold timeout is imposed, because
#'   no time limit is defensible for an arbitrary model fit — a slow fold and a
#'   dead one would be indistinguishable.
#'
#' A fold whose worker dies is recorded as a failed fold, exactly like any other
#' failure: the run finishes, the other folds keep their results, and `.notes`
#' names the worker as the stage.
#'
#' Stopping a run is not a fold failure. A fold that was never given a chance to
#' run has not been attempted, so recording it as one would describe a design
#' that did not execute. Stopping the dispatched tasks therefore aborts the call
#' and returns nothing, raising a `nestedtune_cancelled` condition. That class
#' inherits from `nestedtune_interrupted`, which is what a task interrupted on
#' its own daemon raises, so a handler for the general case catches both and one
#' that cares can tell them apart. Either way the caller's RNG state is restored
#' on the way out.
#'
#' Interrupting the call at your own console is not one of these. It unwinds the
#' blocking wait before any worker's return value is classified, so an ordinary
#' interrupt propagates and no nestedtune condition class is attached — the RNG
#' state is still restored, but do not write a handler expecting one.
#'
#' An interrupt also asks the folds it leaves behind to stop. However the call
#' is left once its folds are dispatched — an interrupt, or an error — the
#' outstanding ones are cancelled on the way out, so the pool goes idle shortly
#' after rather than computing folds whose results nobody will read. Two limits
#' are worth knowing. Cancelling needs mirai's dispatcher, which
#' `mirai::daemons(n)` starts by default; on a pool started with
#' `dispatcher = FALSE` the request cannot reach the workers at all and the
#' folds run to completion. You are told so at dispatch rather than left to
#' discover it: such a pool raises a warning of class
#' `nestedtune_pool_not_cancellable`, once per call, naming the remedy. The pool
#' is not refused, because its results are correct — what it lacks is the
#' ability to stop. And stopping is a request rather than a guarantee:
#' a fold already inside a compiled fitting routine may not be interruptible,
#' and one that has nearly finished may simply finish.
#'
#' One case cannot be told apart, and is documented rather than guessed at:
#' calling `mirai::daemons(0)` while folds are outstanding produces exactly the
#' value a daemon dying mid-fold produces — same code, same classes, nothing to
#' separate them. Tearing the pool down that way is therefore recorded as fold
#' failures rather than treated as a cancellation, because the alternative would
#' discard every completed fold whenever a single worker died.
#'
#' @section Differences from calling tune directly:
#'
#' There is no `control` formal, but a [tune::control_grid()] passed through
#' `...` as `control` reaches the inner `tune_grid()` in every fold, and in
#' the final fit that re-runs the result. What runs is the control passed, or
#' tune's default when none is, with the slots this package forces
#' overwritten; the result records that effective control as
#' `attr(res, "procedure")$control`, which is what the recipe above passes.
#' Every slot of `control_grid()` falls under one of six headings.
#'
#' **Forced: `allow_par`.** Both tune calls a fold makes -- the inner tuning
#' run and the outer scoring fit -- run at `allow_par = FALSE`, whatever the
#' control carries. Parallelism belongs over the outer folds, as above, and
#' leaving that to a caller would put two pools in contention.
#'
#' **Settable as its own argument: `event_level`.** The argument reaches the
#' inner `control_grid()` and the outer `control_last_fit()` alike, and is the
#' one place the level is set: a control left at tune's default takes the
#' argument's level, and a control naming a level that is neither tune's
#' default nor the argument's is refused at entry, naming both. `eval_time`
#' is offered the same way, though it is not a control slot in tune either --
#' it is an argument of both `tune_grid()` and `last_fit()` -- and for the
#' same reason: it changes a number the caller is shown.
#'
#' **Refused: none.** No slot is refused on its own. What is refused at entry
#' is a control of another class -- a `control_bayes()`, which tune itself
#' would accept here -- and the `event_level` conflict above. The class is
#' the contract: tune gives [tune::control_resamples()] and
#' [tune::control_last_fit()] the `control_grid` class, so either is accepted
#' as what `control_grid()` returns, its slots read under these headings.
#'
#' **Passed through: `verbose`, `pkgs`, `parallel_over`, `workflow_size`.**
#' Each reaches `tune_grid()` as given. `verbose` prints from a serial run,
#' beside the progress the outer loop reports, and from a mirai daemon where
#' nothing shows it. `pkgs` is required before fitting on the serial path as
#' on the parallel one, where the daemon pre-flight has already required this
#' package's namespace in every worker. `parallel_over` is not inert at
#' `allow_par = FALSE`: it still chooses how tune loops over resamples and
#' candidates, and with it the seed each model fit starts from, so a
#' stochastic engine's numbers differ between `"resamples"` and
#' `"everything"`; left `NULL`, tune takes `"resamples"` when there is more
#' than one inner resample. `workflow_size` is the size past which tune
#' remarks on a workflow `save_workflow` keeps, so it speaks only beside that
#' slot, and only where the run it lands on is kept.
#'
#' **Not returned: `extract`, `save_pred`, `save_workflow`.** Each lands on
#' the inner `tune_results`. A fold record discards that run once the fold
#' succeeds -- the fold keeps its metrics, its selection and the candidates it
#' scored -- so on a nested run setting them costs the work and returns
#' nothing. The final fit is the exception: [nested_final_fit()] re-runs the
#' recorded control and keeps its tuning run as `$tuning`, where
#' [extract_tune_results()] reaches what these saved.
#'
#' **Inert: `backend_options`.** Options for a parallel backend, with no
#' backend to reach at `allow_par = FALSE`.
#'
#' Not passed on: `select_best()` is called without `eval_time`. Left unset it
#' selects at the first of the evaluation times the tuning run was built with,
#' which are the ones named here, so naming them twice would change no choice
#' and would repeat tune's message about which time it took.
#'
#' @examples
#' \donttest{
#' if (rlang::is_installed(c("recipes", "yardstick"))) {
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
#'     inside = rsample::vfold_cv(v = 3)
#'   )
#'
#'   set.seed(2)
#'   res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
#'   collect_metrics(res)
#'
#'   # What each fold chose -- disagreement here is selection instability, and
#'   # it is information, not noise.
#'   res$.selected
#' }
#' }
#'
#' @seealso [nested_tune_bayes()], [nested_resamples()], [nested_final_fit()],
#'   [tune::tune_grid()]
#' @export
nested_tune_grid <- function(
  object,
  resamples,
  ...,
  param_info = NULL,
  grid = 10,
  metrics = NULL,
  event_level = "first",
  eval_time = NULL
) {
  control <- check_dots_control(capture_dots(...))
  check_workflow(object)
  check_nested(resamples)
  check_grid(grid)
  check_grid_params(object, grid)
  check_metrics(metrics)
  check_param_info(param_info)
  check_event_level(event_level)
  check_eval_time(eval_time)
  control <- check_control(control, "tune_grid", event_level)

  nested_loop(
    object,
    resamples,
    tuner = tuner_grid(grid),
    metrics = metrics,
    param_info = param_info,
    event_level = event_level,
    eval_time = eval_time,
    control = control,
    grid = grid,
    call = rlang::current_env()
  )
}

# The outer loop, shared by both orchestrators (D-040): what differs between
# them is the tuner description and the entry checks, and both of those are
# settled before this is reached. Every argument has been forced by the
# caller's `check_*()` calls, so the RNG snapshot below is taken after the
# caller's own evaluation is complete and nothing lazy can draw inside it. The
# one argument whose evaluation may draw and whose draw is thrown away -- an
# inline `control_bayes()` -- is forced under `capture_dots()`'s own
# snapshot, so its draw is undone before this one is taken.
#
# `call` is the orchestrator's frame, so the run's warnings and the daemon
# pre-flight's refusals name the function the user called rather than this one.
# `control` is the effective control `check_control()` returned, shared by
# every fold and recorded as it is. `grid` is recorded on the object as it was
# given, for the grid path alone; the Bayesian path passes NULL and carries no
# such attribute.
nested_loop <- function(
  object,
  resamples,
  tuner,
  metrics,
  param_info,
  event_level,
  eval_time,
  control,
  grid,
  call
) {
  n <- nrow(resamples)

  # Snapshot before drawing, so what is restored is the caller's state on
  # entry rather than its state after our own draw. `.Random.seed` does not
  # exist until something draws, so a fresh session has nothing to snapshot;
  # sample.int() below initializes it, and we leave that valid state alone.
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_kind <- RNGkind()
  old_seed <- if (had_seed) get(".Random.seed", envir = globalenv())
  on.exit(restore_rng(had_seed, old_kind, old_seed), add = TRUE)

  seeds <- sample.int(.Machine$integer.max, 2L * n)

  # One self-contained payload per fold. Each carries only what that fold needs,
  # so a worker is never sent the rest of the design.
  payloads <- lapply(seq_len(n), function(i) {
    list(
      split = resamples$splits[[i]],
      inner = resamples$inner_resamples[[i]],
      seeds = seeds[c(2L * i - 1L, 2L * i)]
    )
  })

  folds <- dispatch_folds(
    payloads,
    object = object,
    tuner = tuner,
    metrics = metrics,
    param_info = param_info,
    event_level = event_level,
    eval_time = eval_time,
    control = control,
    call = call
  )

  procedure <- new_procedure(
    tuner,
    param_info = param_info,
    event_level = event_level,
    eval_time = eval_time,
    control = control
  )
  out <- new_nested_results(resamples, folds, seeds, grid, metrics, procedure)
  warn_failed_folds(out, call = call)
  out
}

# One outer fold, start to finish.
#
# Everything this needs is an argument: the split, the inner resamples, the two
# seeds, the tuner description and the static inputs. Nothing is read from the
# enclosing loop and
# nothing is drawn here, so the fold's result depends on its position in the
# design and not on when or where it runs -- which is what makes the loop safe
# to reorder or, later, to parallelize (IP2).
nested_fold_fit <- function(
  split,
  inner,
  seeds,
  object,
  tuner,
  metrics,
  param_info = NULL,
  event_level = "first",
  eval_time = NULL,
  control = NULL
) {
  # The zero-row inner table a fold that scores nothing records (M49). Built
  # here, before anything can fail, from the workflow rather than from a run:
  # a fold whose tuning raised has no run to read columns off, and one whose
  # every candidate failed has a run `collect_metrics()` raises on (M03).
  prototype <- empty_inner_metrics(object, tuner, metrics, param_info)
  set_fold_seed(seeds[[1L]])

  # `tuned` is assigned inside the tryCatch expression, which evaluates in this
  # frame -- so when select_best() is what errors, tune's own notes explaining
  # why every model failed are still in hand to record.
  tuned <- NULL
  selected <- tryCatch(
    {
      # The tuner's own call -- `tune_grid()` or `tune_bayes()` -- assembled
      # from the description the orchestrator built (R/tuner.R). The fold's
      # tuning seed goes in with it, because `control_bayes()` is seeded from
      # it and has to be built inside this seed's scope.
      tuned <- run_tuner(
        tuner,
        object = object,
        resamples = inner,
        param_info = param_info,
        metrics = metrics,
        eval_time = eval_time,
        event_level = event_level,
        control = control,
        seed = seeds[[1L]]
      )
      # Resolved from the tuned object rather than from `metrics`, so the same
      # code answers whether the caller supplied a metric set or let tune pick.
      metric_name <- tune::.get_tune_metric_names(tuned)[[1L]]
      # `eval_time` is deliberately not passed on (D-038). Left NULL,
      # `tune:::choose_eval_time()` reads the evaluation times off `tuned` --
      # which are the ones this run was tuned at, because the argument reached
      # `tune_grid()` above -- and `tune:::first_eval_time()` takes element one
      # of them, the same element passing the argument would name. Selection is
      # therefore identical either way, and passing it would repeat tune's
      # "First evaluation time" message once per fold.
      tune::select_best(tuned, metric = metric_name)
    },
    error = function(cnd) cnd
  )
  if (inherits(selected, "condition")) {
    return(failed_fold(
      "inner tuning",
      selected,
      tuned,
      tuned = tuned,
      prototype = prototype
    ))
  }

  # Finalizing and seeding sit inside the guard rather than between the two
  # guarded regions. An error anywhere between selection and the fit is still
  # this fold's failure, and leaving them outside left a path that could abort
  # the whole run -- the one outcome this function exists to prevent.
  fitted <- tryCatch(
    {
      final_wf <- tune::finalize_workflow(object, selected)
      set_fold_seed(seeds[[2L]])
      # The outer fit had no control object at all until M35, so its metrics
      # were computed at tune's default event level whatever the inner run had
      # been told -- the one place the setting had to reach for a reported
      # number to move. `allow_par = FALSE` is stated rather than left to
      # tune, whose `control_last_fit()` defaults it off today: the outer fit
      # runs inside a mirai daemon on the parallel path, and "keep tune serial
      # within the outer loop" is this package's convention to hold, not an
      # upstream default's to keep.
      tune::last_fit(
        final_wf,
        split = split,
        metrics = metrics,
        eval_time = eval_time,
        control = tune::control_last_fit(
          event_level = event_level,
          allow_par = FALSE
        )
      )
    },
    error = function(cnd) cnd
  )
  if (inherits(fitted, "condition")) {
    return(failed_fold(
      "outer fit",
      fitted,
      NULL,
      tuned = tuned,
      prototype = prototype
    ))
  }

  # last_fit() does not raise when the fit fails: it returns NULL metrics and
  # files the reason in its notes. Catching only thrown errors would record
  # this fold as a success carrying nothing.
  fold_metrics <- tryCatch(
    tune::collect_metrics(fitted),
    error = function(cnd) NULL
  )
  if (is.null(fold_metrics) || nrow(fold_metrics) == 0L) {
    return(failed_fold(
      "outer fit",
      NULL,
      fitted,
      tuned = tuned,
      prototype = prototype
    ))
  }

  # A fold can complete and still have had trouble: tune_grid() returns a usable
  # result when only some inner splits fail, and select_best() then chooses from
  # the survivors. Discarding those notes would report a selection made on a
  # truncated inner design as though the whole design had run (IP4), and would
  # drop notes tune itself kept (GP1).
  list(
    completed = TRUE,
    metrics = fold_metrics,
    selected = selected,
    inner_metrics = inner_metrics(tuned, prototype),
    notes = bind_notes(
      tune_notes(tuned, "inner tuning"),
      tune_notes(fitted, "outer fit")
    )
  )
}

# The inner run's metrics, as tune summarizes them (M49, IP4).
#
# `tune::collect_metrics()` of the tuning run, verbatim: one row per candidate
# and metric, with the mean, the resample count `n` and its standard error,
# tune's `.config` label, and the `.iter` a Bayesian run scored it in. A
# candidate that scored on some inner resamples and failed on others is a row
# with `n` below the resample count; one that failed on every resample left no
# metric row anywhere and is absent -- present in the fold's notes instead.
#
# A run in which nothing scored gets the prototype rather than a call:
# `collect_metrics()` raises on such a run (the M03 lesson), and this runs
# inside the failure paths too, where `tuned` is whatever tune handed back
# before giving up and may be NULL. The tryCatch is insurance against a shape
# not thought of, on the same asymmetry M21 recorded: an empty table
# understates one fold, a raise discards every other fold's completed work.
inner_metrics <- function(tuned, prototype) {
  if (!scored_anything(tuned)) {
    return(prototype)
  }
  tryCatch(collect_inner_metrics(tuned), error = function(cnd) prototype)
}

# The one `collect_metrics()` call behind every reader of an inner run (M50,
# D-043): tune's summary, and on a race every candidate the race scored --
# `all_configs = TRUE` -- where finetune's default keeps the survivors alone.
# IP4 records what ran, and an eliminated candidate ran on `n` resamples.
collect_inner_metrics <- function(tuned) {
  if (inherits(tuned, "tune_race")) {
    return(tune::collect_metrics(tuned, all_configs = TRUE))
  }
  tune::collect_metrics(tuned)
}

# Whether at least one candidate scored on at least one inner resample, read
# off the per-resample metric frames a `tune_results` carries. Anything that
# is not that shape scored nothing.
scored_anything <- function(tuned) {
  metrics <- if (is.list(tuned)) tuned[[".metrics"]] else NULL
  is.list(metrics) &&
    any(vapply(
      metrics,
      function(m) is.data.frame(m) && nrow(m) > 0L,
      logical(1)
    ))
}

# The zero-row table a fold that scored nothing records: a completed fold's
# columns, name for name and type for type, so stacking the folds' tables
# never meets one whose columns differ. Each column is typed from what tune
# types it from. A parameter column takes the grid data frame's type when one
# was given -- tune passes a grid's columns through as typed, a double grid
# over an integer parameter scoring as double -- else the dials object
# `param_info` supplies, else the workflow's own; an engine parameter with no
# dials object reaches the last and is typed by the grid alone. The summary
# columns are the ones `collect_metrics()` writes; `.eval_time` is among them
# for a dynamic survival metric only -- an `eval_time` given beside a static
# or an integrated metric draws tune's warning and no column -- and `.iter`
# only on the Bayesian path (each measured 2026-09-02, tune 2.1.0).
empty_inner_metrics <- function(
  object,
  tuner,
  metrics = NULL,
  param_info = NULL
) {
  cols <- empty_param_columns(object, tuner, param_info)
  cols[[".metric"]] <- character(0)
  cols[[".estimator"]] <- character(0)
  if (has_dynamic_metric(object, metrics)) {
    cols[[".eval_time"]] <- numeric(0)
  }
  cols[["mean"]] <- numeric(0)
  cols[["n"]] <- integer(0)
  cols[["std_err"]] <- numeric(0)
  cols[[".config"]] <- character(0)
  if (!is.null(tuner) && isTRUE(tuner_entry(tuner$tuner)$iterates)) {
    cols[[".iter"]] <- integer(0)
  }
  new_tbl(cols)
}

# One zero-length column per tuned parameter, in the workflow's order. The
# workflow names the parameters; the grid data frame, then `param_info`, then
# the workflow's dials set type them.
empty_param_columns <- function(object, tuner, param_info) {
  params <- tryCatch(
    tune::extract_parameter_set_dials(object),
    error = function(cnd) NULL
  )
  # The grid, where the tuner takes one: the raced tuners' description holds
  # a `grid` exactly as `tune_grid()`'s does (R/tuner.R).
  grid <- if (!is.null(tuner) && tuner_takes_grid(tuner$tuner)) {
    tuner$args$grid
  }
  ids <- if (is.data.frame(params)) {
    params$id
  } else if (is.data.frame(grid)) {
    names(grid)
  } else {
    character(0)
  }
  cols <- list()
  for (id in ids) {
    cols[[id]] <- if (is.data.frame(grid) && id %in% names(grid)) {
      grid[[id]][0L]
    } else {
      dials_object <- param_object(id, param_info)
      if (is.null(dials_object)) {
        dials_object <- param_object(id, params)
      }
      empty_param_column(dials_object)
    }
  }
  cols
}

# The dials object a parameter set holds for `id`, or NULL: a set records a
# parameter with no object as a bare NA in its `object` column.
param_object <- function(id, params) {
  if (!is.data.frame(params) || !id %in% params$id) {
    return(NULL)
  }
  object <- params$object[[match(id, params$id)]]
  if (is.list(object)) object else NULL
}

# Whether the inner run's metrics table carries `.eval_time`: the metric set
# holds a dynamic survival metric, or none was given and the workflow's mode
# is censored regression, where tune's default is the dynamic Brier score
# (`tune:::check_metrics_arg()`, tune 2.1.0, read 2026-09-02) and every other
# mode's default is static.
has_dynamic_metric <- function(object, metrics) {
  if (is.null(metrics)) {
    mode <- tryCatch(
      workflows::extract_spec_parsnip(object)$mode,
      error = function(cnd) NULL
    )
    return(identical(mode, "censored regression"))
  }
  any(vapply(
    attr(metrics, "metrics"),
    inherits,
    logical(1),
    what = "dynamic_survival_metric"
  ))
}

empty_param_column <- function(param) {
  type <- if (is.list(param)) param[["type"]] else NULL
  switch(
    if (is.character(type) && length(type) == 1L) type else "",
    double = numeric(0),
    integer = integer(0),
    character = character(0),
    logical = logical(0),
    logical(0)
  )
}

# The candidates a tuning run actually scored (IP4's "the grid actually
# evaluated"), on the final fit's own run: the candidate set derived from its
# `collect_metrics()` table, the same derivation the fold readers apply to
# each fold's `.inner_metrics` (D-043).
#
# Total by construction, because of where it is called from: the accessor sits
# outside every tryCatch, so anything raised here would abort a call that has
# a fitted model to hand back. `collect_metrics()` raises on a run in which
# every candidate failed, and that run scored no candidate -- the empty record
# is the true answer, not a fallback.
scored_candidates <- function(tuned) {
  tryCatch(
    candidate_set(collect_inner_metrics(tuned)),
    error = function(cnd) empty_candidates()
  )
}

# The candidate set a metrics table describes: one row per candidate scored,
# with a column per tuned parameter, tune's `.config` label and, on a Bayesian
# table, the `.iter` it was proposed in. Everything `collect_metrics()` adds
# per metric goes, and the rows are made distinct on `.config`, one label per
# candidate.
#
# Ordered by `.iter` first, so a Bayesian run's initial candidates come before
# the proposals and the proposals follow in the order they were made -- tune
# labels those `iter1`, `iter2`, ... without padding, and the iteration number
# is what puts the tenth after the ninth -- then by the label, which tune
# zero-pads past nine candidates, so ordering it lexically is ordering it
# numerically. A grid table carries no `.iter`, and its order is the label's
# alone. The ordering never touches a parameter column: `order()` raises on a
# list-valued one, which is why `candidate_key()` in nested-results-print.R
# renders rows before ordering them (M21 review F1).
candidate_set <- function(metrics) {
  if (!is.data.frame(metrics)) {
    return(empty_candidates())
  }
  keep <- setdiff(
    names(metrics),
    c(".metric", ".estimator", ".eval_time", "mean", "n", "std_err")
  )
  if (length(keep) == 0L) {
    return(empty_candidates())
  }
  candidates <- as.data.frame(metrics)[, keep, drop = FALSE]

  # `.config` is one label per candidate, so it is the key. Falling back to the
  # parameter values themselves keeps this working on a shape that carries no
  # such column rather than returning every metric's row as a candidate.
  key <- if (".config" %in% keep) {
    candidates[[".config"]]
  } else {
    do.call(paste, c(unname(as.list(candidates)), list(sep = "\r")))
  }
  first <- !duplicated(key)
  kept <- candidates[first, , drop = FALSE]
  ordered <- if (".iter" %in% keep) {
    order(kept[[".iter"]], key[first])
  } else {
    order(key[first])
  }
  new_tbl(lapply(kept, function(col) col[ordered]))
}

# A candidate set holding nothing. Bare rather than typed: the final fit's
# run may have raised before recording a parameter name, and deriving names
# from the workflow would be machinery whose only job is to furnish an empty
# record (M21 plan gate).
empty_candidates <- function() {
  structure(
    list(),
    names = character(0),
    class = c("tbl_df", "tbl", "data.frame"),
    row.names = integer(0)
  )
}

# A fold that did not finish. `result` is whatever tune handed back before
# giving up, which is where the actual cause lives -- our own note names the
# stage, tune's notes say what happened (GP1).
#
# `tuned` is separate from `result` because on the outer-fit path they are
# different objects -- `result` is the last_fit() result whose notes explain the
# failure, while the tuning run that chose the candidate is still in hand. A
# fold that failed there DID evaluate a grid, and recording it as having
# evaluated none would be the same IP4 error in the other direction.
# `prototype` is the zero-row inner table for a fold that scored nothing; the
# default is for the worker-failure path, which has no workflow in hand.
failed_fold <- function(
  stage,
  cnd,
  result,
  message = NULL,
  tuned = NULL,
  prototype = empty_inner_metrics(NULL, NULL)
) {
  # `message` is supplied only by the worker-failure path, where there is no
  # condition to read: mirai's failure values are not conditions and one of them
  # raises on conditionMessage() (M07-D2).
  if (is.null(message)) {
    message <- if (is.null(cnd)) {
      "The outer fit produced no metrics."
    } else {
      conditionMessage(cnd)
    }
  }
  list(
    completed = FALSE,
    metrics = empty_metrics(),
    selected = NULL,
    inner_metrics = inner_metrics(tuned, prototype),
    notes = bind_notes(own_note(stage, message), tune_notes(result, stage))
  )
}

own_note <- function(stage, message) {
  new_tbl(list(
    location = stage,
    type = "error",
    note = message,
    trace = list(NULL)
  ))
}

# tune's notes, verbatim, relabelled with the stage they came from. The `id`
# column is present for a tune_grid() result and absent for a last_fit() one,
# so it is folded into the location rather than assumed.
tune_notes <- function(result, stage) {
  notes <- tryCatch(tune::collect_notes(result), error = function(cnd) NULL)
  if (is.null(notes) || nrow(notes) == 0L) {
    return(empty_notes())
  }
  inner_id <- if ("id" %in% names(notes)) paste0(" (", notes$id, ")") else ""
  new_tbl(list(
    location = paste0(stage, inner_id, ": ", notes$location),
    type = notes$type,
    note = notes$note,
    trace = notes$trace
  ))
}

bind_notes <- function(a, b) {
  new_tbl(list(
    location = c(a$location, b$location),
    type = c(a$type, b$type),
    note = c(a$note, b$note),
    trace = c(a$trace, b$trace)
  ))
}

empty_notes <- function() {
  new_tbl(list(
    location = character(0),
    type = character(0),
    note = character(0),
    trace = list()
  ))
}

# A failed fold contributes no rows rather than a NULL, so every downstream
# assembly over `.metrics` keeps working without a special case.
empty_metrics <- function() {
  new_tbl(list(
    .metric = character(0),
    .estimator = character(0),
    .estimate = numeric(0),
    .config = character(0)
  ))
}

# tune warns at the end of a run that had issues; so does this (GP1). A user
# who never calls collect_metrics() still hears about it.
warn_failed_folds <- function(x, call = rlang::caller_env()) {
  failed <- fold_ids(x)[!x$.completed]
  if (length(failed) == 0L) {
    return(invisible(x))
  }
  n <- attr(x, "folds_attempted")
  cli::cli_warn(
    c(
      "!" = "{length(failed)} of {n} outer fold{?s} failed.",
      x = "Failed: {.val {failed}}.",
      i = "See {.code x$.notes} for what went wrong."
    ),
    class = "nestedtune_failed_folds",
    call = call
  )
  invisible(x)
}

# The generator kind is pinned, not just the seed. set.seed() seeds whichever
# kind happens to be active, so a caller who has selected a non-default kind
# would get one set of numbers serially and another from a fresh parallel
# worker that starts on the default -- the same seed, different results.
set_fold_seed <- function(seed) {
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
}

# Assigning `.Random.seed` restores the generator kind with it: the kind triple
# is encoded in its first element. The other branch is a session that had no
# RNG state when we were called -- there is nothing to restore, and removing
# the state we created would leave the session worse than we found it, so only
# the kind goes back.
restore_rng <- function(had_seed, kind, seed) {
  if (had_seed) {
    assign(".Random.seed", seed, envir = globalenv())
  } else {
    RNGkind(kind[[1L]], kind[[2L]], kind[[3L]])
  }
  invisible(NULL)
}
