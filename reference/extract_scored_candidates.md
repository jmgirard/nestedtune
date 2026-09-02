# Extract the candidates a final fit actually scored

Returns the candidate parameter settings that
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)'s
tuning run actually evaluated — the full-data counterpart of the
candidate set each outer fold's `.inner_metrics` table describes on a
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
or
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
result, derived the same way from the run's
[`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
table, so a Bayesian final fit's table carries the `.iter` column that
path's tables do.

## Usage

``` r
extract_scored_candidates(x, ...)
```

## Arguments

- x:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

## Value

A tibble with one row per candidate scored, carrying one column per
tuned parameter plus tune's `.config` label for the candidate, and
`.iter` on a Bayesian fit. It is the distinct parameter rows of the
run's
[`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
table with those labels — the same shape one element of a result's
`.inner_metrics` column reduces to when its metric columns are dropped —
so the two can be compared directly. Everything tune wrote per metric is
dropped: `.metric`, `.estimator`, `mean`, `n`, `std_err`, and on a fit
that scored a dynamic survival metric the `.eval_time` column, so a
candidate has one row here however many evaluation times it was scored
at. The times and the scores are in
`collect_metrics(extract_tune_results(x))`.

This is what was **scored**, not what was **asked for**. A `grid` given
as a size is expanded by tune and may reach fewer candidates than the
number requested; a candidate that failed everywhere scored nothing. See
the `.inner_metrics` discussion in
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
for the full account of how the two records diverge, which holds here
too — this record is derived the same way.

One pointer there does **not** carry over. A candidate that failed on
every inner resample is missing from this table, and on a
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
result its failure is recorded in that object's `.notes` column. A
`nested_final_fit` has no such column. Look instead inside the tuning
run itself — `tune::collect_notes(extract_tune_results(x))`.

## See also

[`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)

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

extract_scored_candidates(final)
#> # A tibble: 3 × 2
#>   num_comp .config        
#>      <int> <chr>          
#> 1        1 pre1_mod0_post0
#> 2        2 pre2_mod0_post0
#> 3        3 pre3_mod0_post0
```
