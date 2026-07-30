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
#' which runs the same procedure again with the whole dataset in hand. The
#' estimate from this function is what you report for it.
#'
#' @param object A [workflows::workflow()] with at least one parameter marked
#'   for tuning with [tune::tune()].
#' @param resamples A nested resampling design, from [nested_resamples()] or
#'   [rsample::nested_cv()]. Its `splits` column must hold `rsplit` objects and
#'   its `inner_resamples` column an `rset` per outer fold. Both are checked
#'   before anything is fitted, because [rsample::nested_cv()] builds a design
#'   whatever its `inside` argument returned — so a specification that produces
#'   no `rset` gives a design that cannot be run, where [nested_resamples()]
#'   refuses one at construction.
#' @param grid A data frame of candidate parameter values, or a positive whole
#'   number giving the size of a grid to generate. Passed to
#'   [tune::tune_grid()]. A data frame is checked against the workflow before
#'   anything is fitted: every column must name a parameter marked with
#'   [tune::tune()], and every such parameter must have a column.
#' @param metrics A [yardstick::metric_set()], or `NULL` to use tune's defaults
#'   for the model's mode. The first metric in the set selects the best inner
#'   candidate.
#'
#' @return An object of class `nested_results`: one row per outer fold, with the
#'   fold's split and id, the metrics scored on its assessment set
#'   (`.metrics`), the parameters chosen for it by inner tuning (`.selected`),
#'   the candidates its inner tuning actually scored (`.grid`), whether the fold
#'   finished (`.completed`), anything that went wrong (`.notes`), and the two
#'   seeds that reproduce it (`.tuning_seed`, `.outer_fit_seed`). Use
#'   [collect_metrics()] to summarize.
#'
#'   **Two records describe the grid, and they answer different questions.**
#'   `attr(x, "grid")` holds the `grid` argument **as it was given** — a
#'   positive whole number, not a table of candidates, whenever a size was
#'   passed. The `.grid` column holds what each outer fold's inner tuning
#'   actually scored, one table per fold with a column per tuned parameter.
#'
#'   The two diverge routinely, in both directions. A size is expanded by tune
#'   and may reach fewer candidates than were asked for — a request for 20 on a
#'   parameter with four reachable values evaluates four — and a candidate that
#'   fails scores nothing. Folds can also differ from *each other*: expanding a
#'   size draws from the generator, and each fold tunes under its own seed, so
#'   a continuous parameter gives every fold its own candidates. Printing says
#'   so when it happens.
#'
#'   One limit is worth stating plainly. `.grid` is derived from the tuning
#'   run's own metrics, because that is the only place tune records candidates
#'   at all. A candidate that failed on **every** inner resample scored nothing
#'   and is therefore absent from `.grid` — `.notes` is where its failure is
#'   recorded. A fold that scored no candidate at all carries a zero-row table,
#'   never `NULL`.
#'
#'   `attr(x, "metrics")` holds the `metrics` argument, and is absent rather
#'   than `NULL` when none was supplied. Subsetting rows carries both
#'   attributes unchanged, since they describe the call rather than the rows
#'   kept; `.grid` is a column, so it travels with the fold it describes.
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
#'                    metrics = metrics, control = control_grid(allow_par = FALSE))
#' final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
#' set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' last_fit(final, resamples$splits[[i]], metrics = metrics)
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
#' A failed fold still records the candidates it got as far as scoring. One that
#' died at the outer fit had already tuned, so its `.grid` holds the full set;
#' one whose inner tuning failed outright holds a zero-row table. Neither is
#' reported as having searched a grid it did not.
#'
#' Subsetting rows recomputes `folds_attempted` and `folds_completed` for the
#' rows kept, so the counts always describe the object in hand. Dropping the
#' `.completed` column drops the `nested_results` class with it.
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
#' folds run to completion. And stopping is a request rather than a guarantee:
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
#' Inner tuning always runs with `control_grid(allow_par = FALSE)`, forced
#' rather than left to chance, and there is deliberately no `control` argument
#' to override it. Parallelism belongs over the outer folds, as above.
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
#' @seealso [nested_resamples()], [nested_final_fit()], [tune::tune_grid()]
#' @export
nested_tune_grid <- function(object, resamples, grid = 10, metrics = NULL) {
  check_workflow(object)
  check_nested(resamples)
  check_grid(grid)
  check_grid_params(object, grid)
  check_metrics(metrics)

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
    grid = grid,
    metrics = metrics,
    call = rlang::current_env()
  )

  out <- new_nested_results(resamples, folds, seeds, grid, metrics)
  warn_failed_folds(out, call = rlang::current_env())
  out
}

# One outer fold, start to finish.
#
# Everything this needs is an argument: the split, the inner resamples, the two
# seeds, and the static inputs. Nothing is read from the enclosing loop and
# nothing is drawn here, so the fold's result depends on its position in the
# design and not on when or where it runs -- which is what makes the loop safe
# to reorder or, later, to parallelize (IP2).
nested_fold_fit <- function(split, inner, seeds, object, grid, metrics) {
  set_fold_seed(seeds[[1L]])

  # `tuned` is assigned inside the tryCatch expression, which evaluates in this
  # frame -- so when select_best() is what errors, tune's own notes explaining
  # why every model failed are still in hand to record.
  tuned <- NULL
  selected <- tryCatch(
    {
      tuned <- tune::tune_grid(
        object,
        resamples = inner,
        grid = grid,
        metrics = metrics,
        control = tune::control_grid(allow_par = FALSE)
      )
      # Resolved from the tuned object rather than from `metrics`, so the same
      # code answers whether the caller supplied a metric set or let tune pick.
      metric_name <- tune::.get_tune_metric_names(tuned)[[1L]]
      tune::select_best(tuned, metric = metric_name)
    },
    error = function(cnd) cnd
  )
  if (inherits(selected, "condition")) {
    return(failed_fold("inner tuning", selected, tuned, tuned = tuned))
  }

  # Finalizing and seeding sit inside the guard rather than between the two
  # guarded regions. An error anywhere between selection and the fit is still
  # this fold's failure, and leaving them outside left a path that could abort
  # the whole run -- the one outcome this function exists to prevent.
  fitted <- tryCatch(
    {
      final_wf <- tune::finalize_workflow(object, selected)
      set_fold_seed(seeds[[2L]])
      tune::last_fit(final_wf, split = split, metrics = metrics)
    },
    error = function(cnd) cnd
  )
  if (inherits(fitted, "condition")) {
    return(failed_fold("outer fit", fitted, NULL, tuned = tuned))
  }

  # last_fit() does not raise when the fit fails: it returns NULL metrics and
  # files the reason in its notes. Catching only thrown errors would record
  # this fold as a success carrying nothing.
  fold_metrics <- tryCatch(tune::collect_metrics(fitted), error = function(cnd) NULL)
  if (is.null(fold_metrics) || nrow(fold_metrics) == 0L) {
    return(failed_fold("outer fit", NULL, fitted, tuned = tuned))
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
    grid = scored_candidates(tuned),
    notes = bind_notes(
      tune_notes(tuned, "inner tuning"),
      tune_notes(fitted, "outer fit")
    )
  )
}

# The candidates a tuning run actually scored (IP4's "the grid actually
# evaluated").
#
# Derived rather than read, because there is nothing to read: a `tune_results`
# carries only `parameters`, `metrics`, `outcomes` and `rset_info`, and none of
# them is the expanded grid (measured at M21's plan gate, tune 2.1.0). The
# candidates survive only in the per-resample metrics, which has one consequence
# worth stating plainly -- a candidate that failed on EVERY inner resample left
# no metric row anywhere and cannot be recovered here. It is absent from this
# record and present in the fold's notes; `@return` says so.
#
# Unioned across the inner resamples rather than taken from the first. A
# candidate that failed on some inner splits and scored on others did run, and
# reading one element would keep or drop it according to which element was read.
scored_candidates <- function(tuned) {
  # Total by construction, because of where it is called from: both call sites
  # sit outside every tryCatch in this file, so anything raised here would abort
  # the whole run -- the one outcome M03 exists to prevent, and triggered by
  # bookkeeping rather than by a fit. No raising input is known: the obvious
  # candidate, `order()` on a list-valued parameter column, was tried at M21 and
  # does NOT raise (it sorts and returns both candidates, asserted below in
  # test-nested-tune-grid-failures.R). This is insurance against a shape not
  # thought of rather than a fix for one that was, and it is worth a line
  # because the trade is asymmetric: failing to an empty record understates one
  # fold, while raising discards every other fold's completed work.
  tryCatch(scored_candidates_impl(tuned), error = function(cnd) empty_candidates())
}

scored_candidates_impl <- function(tuned) {
  frames <- scored_metric_frames(tuned)
  if (length(frames) == 0L) {
    return(empty_candidates())
  }
  pooled <- do.call(rbind, lapply(frames, as.data.frame))

  # Everything tune adds per metric goes; what remains is one column per tuned
  # parameter plus the `.config` label naming the candidate.
  keep <- setdiff(names(pooled), c(".metric", ".estimator", ".estimate"))
  if (length(keep) == 0L) {
    return(empty_candidates())
  }
  candidates <- pooled[, keep, drop = FALSE]

  # `.config` is one label per candidate, so it is the key. Falling back to the
  # parameter values themselves keeps this working on a shape that carries no
  # such column rather than returning every metric's row as a candidate.
  key <- if (".config" %in% keep) {
    candidates[[".config"]]
  } else {
    do.call(paste, c(unname(as.list(candidates)), list(sep = "\r")))
  }
  first <- !duplicated(key)

  # Ordered by the key so the record does not depend on which inner resample
  # happened to score a candidate first: a candidate missing from the first
  # resample and present in the second would otherwise land last. tune
  # zero-pads `.config` past nine candidates, so ordering it lexically is
  # ordering it numerically.
  ordered <- order(key[first])
  new_tbl(lapply(candidates[first, , drop = FALSE], function(col) col[ordered]))
}

# The per-resample metric frames that hold at least one scored candidate.
# Anything that is not the expected shape yields none rather than raising: this
# runs on the failure paths, where `tuned` is whatever tune handed back before
# giving up and may be NULL.
scored_metric_frames <- function(tuned) {
  metrics <- if (is.list(tuned)) tuned[[".metrics"]] else NULL
  if (!is.list(metrics)) {
    return(list())
  }
  Filter(function(m) is.data.frame(m) && nrow(m) > 0L, metrics)
}

# A fold that scored no candidate at all. Bare rather than typed: a fold that
# failed before tuning returned has no result to read parameter names off, and
# deriving them from the workflow would be machinery whose only job is to
# furnish an empty record (M21 plan gate).
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
failed_fold <- function(stage, cnd, result, message = NULL, tuned = NULL) {
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
    grid = scored_candidates(tuned),
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
