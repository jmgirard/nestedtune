# Prediction on the final fit.
#
# Both methods hand the call to the trained workflow the object carries, so
# what comes back is what `extract_workflow(x)` would give -- the object gains
# no prediction behavior of its own. What it deliberately still lacks is any
# generic that would produce a performance number (D-014, IP3): augmenting the
# training rows yields residuals, and the help page below says what those are
# not.
#
# The two treat `...` differently, on purpose (GP1). `predict()` forwards it,
# because parsnip's `check_pred_type_dots()` refuses any name outside its own
# short list of predict arguments on the way through, so an unknown argument
# is an error there rather than a silent no-op here (a listed name the model
# cannot use, `level` without `type = "conf_int"` say, is passed on and may be
# ignored -- parsnip's behavior, not this method's). `augment()` fences it, because
# `workflows::augment.workflow()` passes its dots on unread and parsnip's
# `augment()` methods ignore them, so a fence here is the only place the
# argument would be refused at all (both verified 2026-09-02, workflows 1.3.0,
# parsnip 1.6.0).

#' Predict with the final model
#'
#' `predict()` and `augment()` on a `nested_final_fit` are the trained
#' workflow's own methods, reached without extracting it first: each returns
#' what the same call on [extract_workflow()]`(x)` returns.
#'
#' @param object,x A `nested_final_fit` object from [nested_final_fit()].
#' @param new_data A data frame of new observations to predict.
#' @param type,opts Passed to the workflow's [predict()][workflows::predict.workflow]
#'   method unchanged; `type` selects the prediction type (`"numeric"`,
#'   `"class"`, `"prob"`, `"survival"`, ...), with the workflow's default
#'   when `NULL`.
#' @param eval_time For censored-regression models, the time or times at
#'   which to evaluate survival probabilities; passed to the workflow's
#'   `augment()` method. Ignored otherwise.
#' @param ... For `predict()`, further arguments passed on to the model's
#'   predict method through the workflow -- `level` with `type = "conf_int"`
#'   for an interval, or `eval_time` with `type = "survival"`; a name outside
#'   parsnip's own short list of predict arguments is refused by parsnip, and
#'   a listed one the model cannot use for the `type` asked is passed on and
#'   may be ignored. For `augment()`, not used;
#'   must be empty. Here the two diverge: workflows' own `augment()` method
#'   passes an unknown argument on to parsnip, which ignores it, so this
#'   method refuses it instead of letting it vanish.
#'
#' @return `predict()` returns the tibble of predictions the workflow's
#'   `predict()` method returns for `type`. `augment()` returns the workflow's
#'   prediction columns followed by the columns of `new_data`, with a `.resid`
#'   column where the outcome is present and the model is a regression.
#'
#' @section Residuals on the training rows are not performance:
#'
#' Augmenting the rows this model was fit on gives in-sample residuals. They
#' describe how the model fits the data it has already seen, and are not
#' this model's performance on data it has not. The number to report is
#' [collect_metrics()] on the results object the fit was built from -- the
#' result of [nested_tune_grid()] or one of its siblings -- which estimates
#' the error of the whole tune-and-fit procedure on rows no part of it
#' touched. See [nested_final_fit()] for why the model has no honest number
#' of its own.
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
#' set.seed(2)
#' res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
#' set.seed(3)
#' final <- nested_final_fit(wf, res)
#'
#' predict(final, new_data = mtcars[1:3, ])
#' predict(final, new_data = mtcars[1:3, ], type = "conf_int", level = 0.9)
#' augment(final, new_data = mtcars[1:3, ])
#'
#' @seealso [nested_final_fit()], [extract_workflow()],
#'   [workflows::predict.workflow()], [workflows::augment.workflow()]
#' @name predict.nested_final_fit
#' @export
predict.nested_final_fit <- function(
  object,
  new_data,
  type = NULL,
  opts = list(),
  ...
) {
  stats::predict(
    object$workflow,
    new_data = new_data,
    type = type,
    opts = opts,
    ...
  )
}

#' @rdname predict.nested_final_fit
#' @importFrom tune augment
#' @export
augment.nested_final_fit <- function(x, new_data, eval_time = NULL, ...) {
  rlang::check_dots_empty()
  augment(x$workflow, new_data = new_data, eval_time = eval_time)
}
