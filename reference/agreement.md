# Tabulate how often each candidate was selected across the outer folds

Each outer fold of a nested resampling run tunes on its own inner
resamples and selects one candidate. `agreement()` counts those
selections: one row per distinct combination of selected parameter
values, with how many completed outer folds chose it and what proportion
of them that is, most frequent first.

The most frequent combination is **not** the final model's parameters.
The outer folds describe how stable the tuning procedure's choice is;
the model to deploy comes from
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
which runs the same procedure once more on the whole dataset and selects
for itself.

## Usage

``` r
agreement(x, ...)
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

## Value

A tibble with one column per parameter any completed fold's selection
recorded, holding the values as the folds selected them, followed by
`n`, the number of completed outer folds that selected that combination,
and `prop`, `n` divided by the number of completed outer folds. Rows are
ordered by `n` decreasing, ties in the order the combination first
appears among the object's rows. Every completed fold is counted once,
so when the table has rows `sum(n)` is the number of completed folds.
tune's `.config` label is not a column: it names a candidate within one
fold's own tuning run, and folds can search different grids.

A completed fold whose selection carries no value for a parameter is
counted under `NA` for that parameter, in the same row as a fold that
selected `NA` for it;
[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)
reports the two apart. A workflow with nothing to tune gives a tibble
with columns `n` and `prop` and no rows. A parameter whose id is `n` or
`prop` cannot be tabulated, because its column would collide with the
counts, and is an error.

A run in which some outer folds failed is tabulated over the folds that
completed, with a warning saying so; a run in which no fold completed is
an error, as it is for
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html).

## See also

[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md),
[`autoplot.nested_results()`](https://nestedtune.tidymodels.org/reference/autoplot.nested_results.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)

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

agreement(res)
#> # A tibble: 2 × 3
#>   num_comp     n  prop
#>      <int> <int> <dbl>
#> 1        1     2 0.667
#> 2        2     1 0.333
```
