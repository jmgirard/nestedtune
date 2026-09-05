# Stack a per-fold column of a nested resampling run across the outer folds

A `nested_results` object keeps three of its records as one table per
outer fold, in list columns: what went wrong (`.notes`), what the fold's
inner tuning selected (`.selected`), and everything that tuning scored
(`.inner_metrics`). These three readers stack one such column into a
single table, with the columns the design labelled its folds with placed
first, so the rows of every fold are read at once and each row says
which fold it came from.

- [`collect_notes()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  stacks `.notes` over every outer fold, failed folds included – a
  failed fold's notes are the reason to ask.

- `collect_selections()` stacks `.selected` over the folds that
  completed: one row per completed fold.

- `collect_inner_metrics()` stacks `.inner_metrics` over the folds that
  completed: one row per candidate (and per metric, and per iteration
  where the tuner iterates) that each fold's inner tuning scored.

## Usage

``` r
collect_selections(x, ...)

# S3 method for class 'nested_results'
collect_selections(x, ...)

collect_inner_metrics(x, ...)

# S3 method for class 'nested_results'
collect_inner_metrics(x, ...)

# S3 method for class 'nested_results'
collect_notes(x, ...)
```

## Arguments

- x:

  A `nested_results` object from
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  or one of its siblings.

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

## Value

A tibble. The first columns are the design's fold labels, read from the
object's record rather than recognized by name: `id` on a plain v-fold
design, `id` and `id2` on a repeated one. Then the columns of the
stacked tables, as the list column holds them, over the union of the
columns any stacked fold carries; a fold lacking one of them holds `NA`
there, in the same way as a fold whose recorded value is `NA`, so the
two are not told apart. For
[`collect_notes()`](https://tune.tidymodels.org/reference/collect_predictions.html)
those are tune's `location`, `type`, `note` and `trace`, and a run that
recorded no note gives zero rows with the same columns. A stacked table
carrying a column named like a fold label column (a parameter given the
id `id`) is refused with condition class
`nestedtune_collect_name_collision`.

## Details

`collect_selections()` and `collect_inner_metrics()` read the folds that
completed, the rule
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
and
[`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md)
follow. A run in which some outer folds failed is stacked over the folds
that completed, with one warning of class `nestedtune_partial_summary`
saying which folds are missing; a run in which no fold completed is an
error with condition class `nestedtune_no_completed_folds`, the class
every summary of such an object refuses with.
[`collect_notes()`](https://tune.tidymodels.org/reference/collect_predictions.html)
reads every fold and warns about none of them.

The `.config` column of a selection or an inner-metrics row is kept as
the fold recorded it. It labels a candidate within *that fold's own*
inner tuning run – a selected row's `.config` is found among the same
fold's rows in `collect_inner_metrics()` – and is not an identity across
folds, which can search different candidate sets. That is why
[`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md)
leaves it out and these readers keep it.

A user of tune will recognize
[`collect_notes()`](https://tune.tidymodels.org/reference/collect_predictions.html):
it is tune's generic, and this method answers for a `nested_results` the
way tune's answers for a `tune_results`.

## See also

[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
[`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md),
[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)

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

collect_selections(res)
#> # A tibble: 3 × 3
#>   id    num_comp .config        
#>   <chr>    <int> <chr>          
#> 1 Fold1        2 pre2_mod0_post0
#> 2 Fold2        1 pre1_mod0_post0
#> 3 Fold3        1 pre1_mod0_post0
collect_inner_metrics(res)
#> # A tibble: 18 × 8
#>    id    num_comp .metric .estimator  mean     n std_err .config       
#>    <chr>    <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>         
#>  1 Fold1        1 rmse    standard   3.39      3  0.468  pre1_mod0_pos…
#>  2 Fold1        1 rsq     standard   0.818     3  0.0853 pre1_mod0_pos…
#>  3 Fold1        2 rmse    standard   3.39      3  0.500  pre2_mod0_pos…
#>  4 Fold1        2 rsq     standard   0.815     3  0.0841 pre2_mod0_pos…
#>  5 Fold1        3 rmse    standard   3.46      3  0.554  pre3_mod0_pos…
#>  6 Fold1        3 rsq     standard   0.807     3  0.0798 pre3_mod0_pos…
#>  7 Fold2        1 rmse    standard   3.78      3  0.500  pre1_mod0_pos…
#>  8 Fold2        1 rsq     standard   0.663     3  0.166  pre1_mod0_pos…
#>  9 Fold2        2 rmse    standard   4.17      3  0.319  pre2_mod0_pos…
#> 10 Fold2        2 rsq     standard   0.610     3  0.177  pre2_mod0_pos…
#> 11 Fold2        3 rmse    standard   4.55      3  0.161  pre3_mod0_pos…
#> 12 Fold2        3 rsq     standard   0.642     3  0.138  pre3_mod0_pos…
#> 13 Fold3        1 rmse    standard   3.20      3  0.349  pre1_mod0_pos…
#> 14 Fold3        1 rsq     standard   0.725     3  0.0725 pre1_mod0_pos…
#> 15 Fold3        2 rmse    standard   3.61      3  0.507  pre2_mod0_pos…
#> 16 Fold3        2 rsq     standard   0.664     3  0.0548 pre2_mod0_pos…
#> 17 Fold3        3 rmse    standard   3.33      3  0.323  pre3_mod0_pos…
#> 18 Fold3        3 rsq     standard   0.714     3  0.0527 pre3_mod0_pos…
collect_notes(res)
#> # A tibble: 0 × 5
#> # ℹ 5 variables: id <chr>, location <chr>, type <chr>, note <chr>,
#> #   trace <list>
```
