# Predict with the final model

[`predict()`](https://rdrr.io/r/stats/predict.html) and
[`augment()`](https://generics.r-lib.org/reference/augment.html) on a
`nested_final_fit` are the trained workflow's own methods, reached
without extracting it first: each returns what the same call on
[`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)`(x)`
returns.

## Usage

``` r
# S3 method for class 'nested_final_fit'
predict(object, new_data, type = NULL, opts = list(), ...)

# S3 method for class 'nested_final_fit'
augment(x, new_data, eval_time = NULL, ...)
```

## Arguments

- object, x:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md).

- new_data:

  A data frame of new observations to predict.

- type, opts:

  Passed to the workflow's
  [predict()](https://workflows.tidymodels.org/reference/predict-workflow.html)
  method unchanged; `type` selects the prediction type (`"numeric"`,
  `"class"`, `"prob"`, `"survival"`, ...), with the workflow's default
  when `NULL`.

- ...:

  For [`predict()`](https://rdrr.io/r/stats/predict.html), further
  arguments passed on to the model's predict method through the workflow
  – `level` with `type = "conf_int"` for an interval, or `eval_time`
  with `type = "survival"`; a name outside parsnip's own short list of
  predict arguments is refused by parsnip, and a listed one the model
  cannot use for the `type` asked is passed on and may be ignored. For
  [`augment()`](https://generics.r-lib.org/reference/augment.html), not
  used; must be empty. Here the two diverge: workflows' own
  [`augment()`](https://generics.r-lib.org/reference/augment.html)
  method passes an unknown argument on to parsnip, which ignores it, so
  this method refuses it instead of letting it vanish.

- eval_time:

  For censored-regression models, the time or times at which to evaluate
  survival probabilities; passed to the workflow's
  [`augment()`](https://generics.r-lib.org/reference/augment.html)
  method. Ignored otherwise.

## Value

[`predict()`](https://rdrr.io/r/stats/predict.html) returns the tibble
of predictions the workflow's
[`predict()`](https://rdrr.io/r/stats/predict.html) method returns for
`type`. [`augment()`](https://generics.r-lib.org/reference/augment.html)
returns the workflow's prediction columns followed by the columns of
`new_data`, with a `.resid` column where the outcome is present and the
model is a regression.

## Residuals on the training rows are not performance

Augmenting the rows this model was fit on gives in-sample residuals.
They describe how the model fits the data it has already seen, and are
not this model's performance on data it has not. The number to report is
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
on the results object the fit was built from – the result of
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
or one of its siblings – which estimates the error of the whole
tune-and-fit procedure on rows no part of it touched. See
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
for why the model has no honest number of its own.

## See also

[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html),
[`workflows::predict.workflow()`](https://workflows.tidymodels.org/reference/predict-workflow.html),
[`workflows::augment.workflow()`](https://workflows.tidymodels.org/reference/augment.workflow.html)

## Examples

``` r
data(mtcars)

rec <- recipes::step_pca(
  recipes::recipe(mpg ~ ., data = mtcars),
  recipes::all_predictors(),
  num_comp = tune::tune()
)
wf <- workflows::workflow(rec, parsnip::linear_reg())

set.seed(1)
folds <- nested_resamples(
  mtcars,
  outside = rsample::vfold_cv(v = 3),
  inside = rsample::vfold_cv(v = 3)
)

set.seed(2)
res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
set.seed(3)
final <- nested_final_fit(wf, res)

predict(final, new_data = mtcars[1:3, ])
#> # A tibble: 3 × 1
#>   .pred
#>   <dbl>
#> 1  23.1
#> 2  23.1
#> 3  25.2
predict(final, new_data = mtcars[1:3, ], type = "conf_int", level = 0.9)
#> # A tibble: 3 × 2
#>   .pred_lower .pred_upper
#>         <dbl>       <dbl>
#> 1        22.1        24.2
#> 2        22.1        24.2
#> 3        23.9        26.5
augment(final, new_data = mtcars[1:3, ])
#> # A tibble: 3 × 13
#>   .pred .resid   mpg   cyl  disp    hp  drat    wt  qsec    vs    am
#> * <dbl>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1  23.1  -2.14  21       6   160   110  3.9   2.62  16.5     0     1
#> 2  23.1  -2.14  21       6   160   110  3.9   2.88  17.0     0     1
#> 3  25.2  -2.38  22.8     4   108    93  3.85  2.32  18.6     1     1
#> # ℹ 2 more variables: gear <dbl>, carb <dbl>
```
