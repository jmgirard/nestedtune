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
#' and no final model is returned here — fit that separately on the full data
#' once you are satisfied with the procedure.
#'
#' @param object A [workflows::workflow()] with at least one parameter marked
#'   for tuning with [tune::tune()].
#' @param resamples A nested resampling design, from [nested_resamples()] or
#'   [rsample::nested_cv()].
#' @param grid A data frame of candidate parameter values, or a positive whole
#'   number giving the size of a grid to generate. Passed to
#'   [tune::tune_grid()].
#' @param metrics A [yardstick::metric_set()], or `NULL` to use tune's defaults
#'   for the model's mode. The first metric in the set selects the best inner
#'   candidate.
#'
#' @return An object of class `nested_results`: one row per outer fold, with the
#'   fold's split and id, the metrics scored on its assessment set
#'   (`.metrics`), the parameters chosen for it by inner tuning (`.selected`),
#'   and the two seeds that reproduce it (`.tuning_seed`, `.outer_fit_seed`).
#'   Use [collect_metrics()] to summarize.
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
#' @section Differences from calling tune directly:
#'
#' Inner tuning always runs with `control_grid(allow_par = FALSE)`. Nested
#' parallelism oversubscribes cores, so parallelism belongs over the outer folds
#' rather than inside them; the setting is forced rather than left to chance,
#' and there is deliberately no `control` argument to override it.
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
#' @seealso [nested_resamples()], [tune::tune_grid()]
#' @export
nested_tune_grid <- function(object, resamples, grid = 10, metrics = NULL) {
  check_workflow(object)
  check_nested(resamples)
  check_grid(grid)
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

  folds <- lapply(seq_len(n), function(i) {
    nested_fold_fit(
      split = resamples$splits[[i]],
      inner = resamples$inner_resamples[[i]],
      seeds = seeds[c(2L * i - 1L, 2L * i)],
      object = object,
      grid = grid,
      metrics = metrics
    )
  })

  new_nested_results(resamples, folds, seeds, grid, metrics)
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
  selected <- tune::select_best(tuned, metric = metric_name)
  final_wf <- tune::finalize_workflow(object, selected)

  set_fold_seed(seeds[[2L]])
  fitted <- tune::last_fit(final_wf, split = split, metrics = metrics)

  list(
    metrics = tune::collect_metrics(fitted),
    selected = selected
  )
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
