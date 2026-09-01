# Print a nested cross-validation result

Shows the object: its outer folds as the tibble rows they are, the outer
resampling scheme it came from, how many folds did not complete, and a
pointer to
[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)
for what the run means.

Printing also says when the folds were not choosing from the same menu.
A grid given as a size is expanded per fold, under that fold's own seed,
so a continuous parameter leaves every fold with its own candidates —
which changes how the selections
[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)
reports should be read. The line reports each fold's candidate count and
appears only when the sets actually differ.

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

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

## Value

`x`, invisibly.

## See also

[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md),
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
#> ── Nested cross-validation results ────────────────────────────────────
#> Outer resamples: 3-fold cross-validation
#> # A tibble: 3 × 9
#>   splits          id    .metrics .selected .grid    .notes   .completed
#>   <list>          <chr> <list>   <list>    <list>   <list>   <lgl>     
#> 1 <split [21/11]> Fold1 <tibble> <tibble>  <tibble> <tibble> TRUE      
#> 2 <split [21/11]> Fold2 <tibble> <tibble>  <tibble> <tibble> TRUE      
#> 3 <split [22/10]> Fold3 <tibble> <tibble>  <tibble> <tibble> TRUE      
#> # ℹ 2 more variables: .tuning_seed <int>, .outer_fit_seed <int>
#> ℹ Use `summary()` for what the run means: which folds failed, what
#>   each one selected, and the estimate across them.
```
