# Collect the metrics from a nested resampling run

Collect the metrics from a nested resampling run

## Usage

``` r
# S3 method for class 'nested_results'
collect_metrics(x, summarize = TRUE, ...)
```

## Arguments

- x:

  A `nested_results` object from
  [`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md).

- summarize:

  Whether to average the per-fold metrics (`TRUE`, the default) or
  return them one row per outer fold (`FALSE`).

- ...:

  Not used.

## Value

A tibble. Summarized, one row per metric with the mean across outer
folds, the number of folds, and the standard error of that mean.
Unsummarized, one row per outer fold and metric.

## Details

The summarized value is the nested cross-validation estimate: what the
tune-and-fit procedure achieves on data it never saw. It is not the
performance of any model you have in hand.

Only the outer folds that completed are summarized, and `n` counts them,
so a run with failures never reports its estimate as though the whole
design had run. Those folds are dropped with a warning naming them; when
no fold completed at all, this errors instead of returning `NA`.

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

collect_metrics(res)
#> # A tibble: 2 × 5
#>   .metric .estimator  mean     n std_err
#>   <chr>   <chr>      <dbl> <int>   <dbl>
#> 1 rmse    standard   3.23      3   0.316
#> 2 rsq     standard   0.722     3   0.112
collect_metrics(res, summarize = FALSE)
#> # A tibble: 6 × 4
#>   id    .metric .estimator .estimate
#>   <chr> <chr>   <chr>          <dbl>
#> 1 Fold1 rmse    standard       3.25 
#> 2 Fold1 rsq     standard       0.499
#> 3 Fold2 rmse    standard       2.67 
#> 4 Fold2 rsq     standard       0.806
#> 5 Fold3 rmse    standard       3.77 
#> 6 Fold3 rsq     standard       0.859
```
