# The final-fit path.
#
# What the nested estimate describes is a procedure: given a dataset, resample
# it by the inner specification, tune, select, fit. The deployment target of
# that procedure is the whole dataset, so the final model is produced by running
# the procedure again with every row in hand -- the refit step, one level up
# from the ordinary "cross-validate, then refit on everything" convention
# (RR02 Q1).
#
# It is a separate function returning a separate object because the estimate
# characterizes the procedure and never the model (IP3). Nothing here computes
# a performance number, and the object deliberately answers no generic that
# would produce one.

#' Fit the final model after nested cross-validation
#'
#' `nested_final_fit()` runs the tuning procedure once more with the whole
#' dataset in hand: it re-evaluates the design's inner resampling specification
#' against every row, tunes with [tune::tune_grid()], selects the best
#' candidate, finalizes the workflow, and fits it on all the data. The result is
#' the model to deploy.
#'
#' @param object A [workflows::workflow()] with at least one parameter marked
#'   for tuning with [tune::tune()]. Ordinarily the same workflow passed to
#'   [nested_tune_grid()].
#' @param resamples A nested resampling design, from [nested_resamples()] or
#'   [rsample::nested_cv()]. Only its inner specification and its data are used:
#'   the outer folds play no part in a final fit.
#' @param grid A data frame of candidate parameter values, or a positive whole
#'   number giving the size of a grid to generate. Passed to
#'   [tune::tune_grid()].
#' @param metrics A [yardstick::metric_set()], or `NULL` to use tune's defaults
#'   for the model's mode. The first metric in the set selects the best
#'   candidate.
#'
#' @return An object of class `nested_final_fit` with elements `workflow` (the
#'   trained workflow, better reached with [extract_workflow()]), `selected`
#'   (the parameters chosen), `tuning` (the tuning run they were chosen from),
#'   and `tuning_seed` and `fit_seed` (the two seeds that reproduce it).
#'
#' @details
#' The procedure a nested estimate describes is "resample this dataset by the
#' inner specification, tune, select, fit", and the dataset that procedure is
#' meant to be applied to is all of yours. So the final model comes from running
#' it again with nothing held out — the same convention as cross-validating a
#' model and then refitting on everything, one level up.
#'
#' The outer folds play no part. Their selections are not pooled or voted on:
#' they belong to the estimate, which describes the procedure across the
#' instability those selections reveal, and not to this model.
#'
#' @section What to report:
#'
#' Report the estimate from [collect_metrics()] on the [nested_tune_grid()]
#' result as this model's performance. That number is an approximately
#' unbiased — if anything slightly conservative — estimate of how the whole
#' tune-and-fit procedure that produced this model performs on new data from the
#' same population, measured on data no part of the procedure ever touched.
#'
#' The model in hand has no honest number of its own. Everything computable from
#' its training data was consumed by selection or by fitting, **including the
#' resampling metrics inside the tuning run stored on this object**: those are
#' selection-time quantities, optimistically biased as a performance claim, and
#' `collect_metrics()` on `x$tuning` will hand them over without saying so. They
#' are kept because they are the record of what selection saw, not because they
#' describe this model.
#'
#' Two things the nested estimate does not say. It is marginal over selection,
#' not conditional on the parameters this model happens to carry, so it is not a
#' claim about this configuration specifically. And it describes new data drawn
#' like your training data — not a different population, and not a model
#' retrained at a different size.
#'
#' If the outer folds disagreed about the best parameters, report that too.
#'
#' @section Reproducibility:
#'
#' Seed the session before the call, as elsewhere in tidymodels; there is no
#' `seed` argument. On entry the function draws two seeds in a single
#' `sample.int(.Machine$integer.max, 2)` call. The first covers building the
#' inner resamples *and* tuning; the second covers the final fit. Both are
#' applied with the generator kind pinned, and both are returned on the object.
#'
#' The run is reproducible by hand from those two seeds alone:
#'
#' ```
#' set.seed(fit$tuning_seed, kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' inner <- <the design's `inside` specification>(data)
#' tuned <- tune_grid(object, inner, grid = grid, metrics = metrics,
#'                    control = control_grid(allow_par = FALSE))
#' final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
#' set.seed(fit$fit_seed, kind = "Mersenne-Twister",
#'          normal.kind = "Inversion", sample.kind = "Rejection")
#' fit(final, data)
#' ```
#'
#' Building the resamples sits *inside* the first seed's scope, not before it:
#' constructing an `rset` draws from the generator, so a version that built them
#' earlier would still be reproducible from the session seed but no longer from
#' the two seeds above.
#'
#' The caller's RNG state and generator kind are restored on exit, including
#' when the call errors. One consequence worth knowing: two consecutive calls
#' with no `set.seed()` between them return identical results, exactly as
#' repeated [tune::tune_grid()] calls do.
#'
#' This binds randomness that flows through R's generator. Engines that
#' randomize outside it — kernlab's SVMs, the deep-learning engines — cannot be
#' pinned by any R-side scheme, here or in tune.
#'
#' @section The inner specification is re-evaluated:
#'
#' A nested design stores its `inside` argument as an unevaluated call, and this
#' function evaluates it again — against the whole dataset, in the environment
#' you call from, not the one the design was built in.
#'
#' Write it with literal arguments. `inside = vfold_cv(v = 5)` is re-evaluated
#' identically anywhere. `inside = vfold_cv(v = k)` is not: if `k` is gone by
#' the time you call this, you get an error naming the specification, and if
#' some *other* `k` is in scope you silently get a different design. Building a
#' design inside a function that parameterizes its resampling is the common way
#' to meet this.
#'
#' @examplesIf rlang::is_installed(c("recipes", "yardstick"))
#' data(mtcars)
#'
#' rec <- recipes::step_pca(
#'   recipes::recipe(mpg ~ ., data = mtcars),
#'   recipes::all_predictors(),
#'   num_comp = tune::tune()
#' )
#' wf <- workflows::workflow(rec, parsnip::linear_reg())
#'
#' set.seed(1)
#' folds <- nested_resamples(
#'   mtcars,
#'   outside = rsample::vfold_cv(v = 3),
#'   inside = rsample::vfold_cv(v = 3)
#' )
#'
#' # The estimate: what the procedure achieves.
#' set.seed(2)
#' res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
#' collect_metrics(res)
#'
#' # The model: what you deploy. Report the estimate above for it.
#' set.seed(3)
#' final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))
#' final
#'
#' predict(extract_workflow(final), new_data = mtcars[1:3, ])
#'
#' @seealso [nested_tune_grid()], [extract_workflow()]
#' @export
nested_final_fit <- function(object, resamples, grid = 10, metrics = NULL) {
  check_workflow(object)
  check_nested(resamples)
  check_grid(grid)
  check_grid_params(object, grid)
  check_metrics(metrics)
  inside <- check_inside_spec(resamples)

  env <- rlang::caller_env()
  data <- split_data(resamples)

  # The same snapshot-and-restore contract the loop gives (D-011): what is put
  # back is the caller's state on entry, and `sample.int()` below initializes a
  # fresh session's state, which is left valid rather than removed.
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_kind <- RNGkind()
  old_seed <- if (had_seed) get(".Random.seed", envir = globalenv())
  on.exit(restore_rng(had_seed, old_kind, old_seed), add = TRUE)

  seeds <- sample.int(.Machine$integer.max, 2L)

  final_fit_worker(inside, data, env, seeds, object, grid, metrics)
}

# The final fit itself, once the seeds exist.
#
# Split from the entry point for the same reason `nested_fold_fit()` is:
# everything it needs is an argument, so what it produces depends on the two
# seeds and on nothing ambient. That is what makes the kind-independence
# property testable -- from a user-visible seed it is not, because the entry
# draw above reads the caller's stream and that draw is itself kind-dependent
# (M05, deviating from RR02's BC6 as literally written).
final_fit_worker <- function(inside, data, env, seeds, object, grid, metrics) {
  # D-016: the tuning seed's scope is "construct the resamples and tune", so
  # the specification is evaluated *after* the seed is set. Building an rset
  # draws from the RNG, and a draw made outside this scope would leave the run
  # reproducible from the entry state but not from the two seeds -- the
  # property the seeds exist to provide -- while every same-seed test went on
  # passing.
  set_fold_seed(seeds[[1L]])
  inner <- eval_inside_spec(inside, data, env)
  tuned <- tune::tune_grid(
    object,
    resamples = inner,
    grid = grid,
    metrics = metrics,
    control = tune::control_grid(allow_par = FALSE)
  )
  # Resolved from the tuned object rather than from `metrics`, so the same code
  # answers whether the caller supplied a metric set or let tune pick.
  metric_name <- tune::.get_tune_metric_names(tuned)[[1L]]
  selected <- tune::select_best(tuned, metric = metric_name)
  final_wf <- tune::finalize_workflow(object, selected)

  set_fold_seed(seeds[[2L]])
  fitted <- parsnip::fit(final_wf, data = data)

  new_nested_final_fit(fitted, selected, tuned, seeds)
}

# The final-fit object.
#
# A plain list, not a tibble: there is one model here, not one row per fold.
# It carries the tuning run it came from because that run is the record of what
# selection saw -- the analog of `nested_results` keeping `.selected` -- and
# because the package's own oracle reads it. What it deliberately does not
# carry is any method that would turn that run into a performance claim: tune's
# ranking and collecting generics are left unregistered, so they error rather
# than answer, exactly as they do for `nested_results` (D-010, RR02 Q7).
new_nested_final_fit <- function(workflow, selected, tuning, seeds) {
  structure(
    list(
      workflow = workflow,
      selected = selected,
      tuning = tuning,
      tuning_seed = seeds[[1L]],
      fit_seed = seeds[[2L]]
    ),
    class = "nested_final_fit"
  )
}

#' @importFrom tune extract_workflow
#' @export
extract_workflow.nested_final_fit <- function(x, ...) {
  x$workflow
}
