# Extract the candidates a final fit actually scored

Returns the candidate parameter settings that
[`nested_final_fit()`](https://jmgirard.github.io/nestedtune/reference/nested_final_fit.md)'s
tuning run actually evaluated — the full-data counterpart of the `.grid`
column
[`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md)
records for each outer fold.

## Usage

``` r
extract_scored_candidates(x, ...)
```

## Arguments

- x:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://jmgirard.github.io/nestedtune/reference/nested_final_fit.md).

- ...:

  Not used.

## Value

A tibble with one row per candidate scored, carrying one column per
tuned parameter plus tune's `.config` label for the candidate. It is the
same shape as one element of
[`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md)'s
`.grid` column, so the two can be compared directly.

This is what was **scored**, not what was **asked for**. A `grid` given
as a size is expanded by tune and may reach fewer candidates than the
number requested; a candidate that failed everywhere scored nothing. See
the `.grid` discussion in
[`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md)
for the full account of how the two records diverge, which holds here
too — this record is derived the same way.

One pointer there does **not** carry over. A candidate that failed on
every inner resample is missing from this table, and on a
[`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md)
result its failure is recorded in that object's `.notes` column. A
`nested_final_fit` has no such column. Look instead inside the tuning
run itself — `tune::collect_notes(extract_tune_results(x))`.

## See also

[`extract_tune_results()`](https://jmgirard.github.io/nestedtune/reference/extract_tune_results.md),
[`nested_final_fit()`](https://jmgirard.github.io/nestedtune/reference/nested_final_fit.md),
[`nested_tune_grid()`](https://jmgirard.github.io/nestedtune/reference/nested_tune_grid.md)

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

set.seed(3)
final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))

extract_scored_candidates(final)
#> # A tibble: 3 × 2
#>   num_comp .config        
#>      <int> <chr>          
#> 1        1 pre1_mod0_post0
#> 2        2 pre2_mod0_post0
#> 3        3 pre3_mod0_post0
```
