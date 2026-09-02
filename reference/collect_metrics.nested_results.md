# Collect the metrics from a nested resampling run

Collect the metrics from a nested resampling run

## Usage

``` r
# S3 method for class 'nested_results'
collect_metrics(x, ..., summarize = TRUE)
```

## Arguments

- x:

  A `nested_results` object from
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  or
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

- summarize:

  Whether to average the per-fold metrics (`TRUE`, the default) or
  return them one row per outer fold (`FALSE`).

## Value

A tibble. Summarized, one row per metric – and, for a metric measured at
evaluation times, per evaluation time – with the mean across outer
folds, the number of folds contributing, and the standard error of that
mean. Unsummarized, one row per outer fold and metric – and per
evaluation time, where a metric was measured at several. Both carry a
`.eval_time` column exactly when the run was scored by a dynamic or
integrated survival metric, as tune's own
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
does; on a static metric's row beside one, it is `NA`.

## Details

The summarized value is the nested cross-validation estimate: what the
tune-and-fit procedure achieves on data it never saw. It is not the
performance of any model you have in hand.

Only the outer folds that completed are summarized, and `n` counts the
folds contributing to each row, so a run with failures never reports its
estimate as though the whole design had run. Those folds are dropped
with a warning naming them; when no fold completed at all, this errors
instead of returning `NA`.

A metric measured at several evaluation times (`eval_time` on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md))
is summarized per time, never averaged across them: each row's `mean` is
over the fold estimates at the time it names.

## Reading `std_err`

`std_err` is the standard error of the mean across outer folds: the
standard deviation of the per-fold scores divided by the square root of
how many there were. It is the precision of that mean, not the
fold-to-fold spread, which is larger by the same square-root factor. It
is **not** a confidence interval for the estimate, and one should not be
built from it.

That is a limit of the statistics rather than of this implementation.
Outer fold scores are not independent — any two folds share most of
their training rows — so a standard error computed as though they were
can misstate the uncertainty, typically downward. Bengio and Grandvalet
(2004) proved there is no universally unbiased estimator of a k-fold
cross-validation estimate's variance to put in its place. Gauran, Ombao
and Yu (2025) measured what that costs inside a nested design: several
of their test statistics built on a variance-based denominator rejected
a true null far more often than the nominal 5% they were run at — 36%
and 40% in the worst cells they report — and they recommend against such
denominators outright.

Both results are about closely related quantities rather than this
column exactly: Bengio and Grandvalet study the variance of a k-fold
estimate built from per-observation losses, and Gauran and colleagues
work inside ridge and LASSO designs. Neither gap rescues the column — no
interval here is oracle-backed, which is the practical point.

The column is reported because `tune` reports it and users expect the
shape; no inferential claim is made with it.

## References

Bengio, Y., & Grandvalet, Y. (2004). No unbiased estimator of the
variance of K-fold cross-validation. *Journal of Machine Learning
Research*, 5, 1089–1105.

Gauran, I. I., Ombao, H., & Yu, Z. (2025). Predictive performance test
based on the exhaustive nested cross-validation for high-dimensional
data. *arXiv:2408.03138*.

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
