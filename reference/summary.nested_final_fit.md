# Summarize a final fit

Answers what the final fit means: the full-data tuning run the selection
came from, which procedure ran it and at what counts, how many
candidates that run scored, which parameter values it selected, and
where this model's honest performance estimate lives.

The estimate component is always `NULL`, and that is the point. The
tuning run stored on the object has metrics, but selection consumed them
and they are optimistically biased as a claim about this model; the
nested estimate on the results object the fit was built from – the
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
or
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
result – is the one to report (IP3). The absence is carried as a
component rather than left out, so a caller reading the summary meets a
recorded fact instead of a missing name; the four Bayesian counts are
carried as `NULL` on a grid fit for the same reason.

## Usage

``` r
# S3 method for class 'nested_final_fit'
summary(object, ...)

# S3 method for class 'summary.nested_final_fit'
print(x, ...)
```

## Arguments

- object:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

- x:

  A `summary.nested_final_fit` object from `summary.nested_final_fit()`.

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns an object of
class `summary.nested_final_fit`: a list holding the full-data tuning
run's resampling label (`tuning_label`), the tuner that ran (`tuner`:
`"tune_grid"`, `"tune_bayes"`, `"tune_race_anova"`,
`"tune_race_win_loss"` or `"tune_sim_anneal"`), the number of candidates
that run scored (`candidates`), the iterating tuners' counts (`initial`
and `initial_requested`, `iterations_completed` and
`iterations_requested`, each `NULL` on a grid or a racing fit; the
scored figures are read from the candidate record, the requested ones
from the procedure, and a run whose candidate record cannot be derived
reports its scored figures as zero rather than failing to print), the
parameter values selection chose (`selection`), and an `estimate`
component that is always `NULL`. Printing it is what most callers want;
the components are there for a caller that needs a value rather than a
line of text.

[`print()`](https://rdrr.io/r/base/print.html) returns `x`, invisibly.

## See also

[`print.nested_final_fit()`](https://nestedtune.tidymodels.org/reference/print.nested_final_fit.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`summary.nested_results()`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md),
[`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md)

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

summary(final)
#> 
#> ── Nested cross-validation final fit ──────────────────────────────────
#> Full-data tuning: 3-fold cross-validation
#> Procedure: grid search, 3 candidates scored
#> Candidates scored: 3
#> 
#> ── Selected parameters ──
#> 
#> num_comp: 1
#> 
#> ── Estimate ──
#> 
#> ℹ This model has no performance estimate of its own. Report the nested
#>   estimate from `collect_metrics()` on the results object this fit was
#>   built from, which describes the procedure that produced it.
#> ℹ The tuning run above has metrics, but selection consumed them.
#>   `extract_tune_results()` reaches them, and every one is a
#>   selection-time quantity, optimistically biased as a claim about this
#>   model.
```
