# Extract the tuning run a final fit was selected from

Returns the
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
result that
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
chose its parameters from — the record of what selection saw when the
procedure was re-run on the complete dataset.

## Usage

``` r
extract_tune_results(x, ...)
```

## Arguments

- x:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

## Value

The stored `tune_results` object, unchanged. It is tune's own object, so
tune's generics apply to it directly.

## What its numbers are, and are not

The returned object answers
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
and will hand its metrics over without qualifying them. Every one of
them is a **selection-time** quantity: it was computed on the resamples
that chose the candidate it describes, which makes it optimistically
biased as a claim about the model this final fit produced. Nothing in
that object is this model's performance.

Report the nested estimate instead —
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
on the
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
result. That number is measured on data no part of the tune-and-fit
procedure ever saw, which is what makes it an honest description of the
procedure that produced your model.

The run is kept because it is the record of what selection saw, not
because it describes the model.

## See also

[`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md),
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

set.seed(3)
final <- nested_final_fit(wf, folds, grid = data.frame(num_comp = 1:3))

extract_tune_results(final)
#> # Tuning results
#> # 3-fold cross-validation 
#> # A tibble: 3 × 4
#>   splits          id    .metrics         .notes          
#>   <list>          <chr> <list>           <list>          
#> 1 <split [21/11]> Fold1 <tibble [6 × 5]> <tibble [0 × 4]>
#> 2 <split [21/11]> Fold2 <tibble [6 × 5]> <tibble [0 × 4]>
#> 3 <split [22/10]> Fold3 <tibble [6 × 5]> <tibble [0 × 4]>
```
