# Print a nested cross-validation result

Reports how much of the requested outer design actually ran, which outer
folds failed and at which stage, what each fold's inner tuning selected,
and the estimate across the folds that completed.

The selection lines are the part nothing else in the ecosystem shows.
When outer folds choose different parameters, the tuning procedure is
unstable on this data — averaging the metrics hides that, so printing
marks it.

Printing also says when the folds were not choosing from the same menu.
A grid given as a size is expanded per fold, under that fold's own seed,
so a continuous parameter leaves every fold with its own candidates —
which changes how the selection lines above should be read. The line
reports each fold's candidate count and appears only when the sets
actually differ.

## Usage

``` r
# S3 method for class 'nested_results'
print(x, ...)
```

## Arguments

- x:

  A `nested_results` object from
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md).

- ...:

  Not used.

## Value

`x`, invisibly.

## See also

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)

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

res
#> 
#> ── Nested cross-validation results ─────────────────────────────────────────────
#> Outer resamples: 3-fold cross-validation
#> Outer folds: 3 requested, 3 completed
#> 
#> ── Selected parameters ──
#> 
#> ! num_comp: 2, 1, 1 (folds disagree)
#> 
#> ── Estimate (3 of 3 outer folds) ──
#> 
#> rmse (standard): 3.23
#> rsq (standard): 0.722
#> 
#> ℹ A nested estimate describes the tune-and-fit procedure, not a model you can
#>   deploy. Build that with `nested_final_fit()`, and report this estimate as
#>   what its procedure achieves.
```
