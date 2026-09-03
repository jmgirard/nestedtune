# Print a final fit

Reports which parameters the full-data tuning run selected, says where
this model's performance estimate actually comes from, and names the
accessors that reach what selection saw.

No performance number is shown. The tuning run stored on the object has
metrics, but they were consumed by selection and are optimistically
biased as a claim about this model; the nested estimate on the results
object the fit was built from – the result of
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
or one of its siblings – is the one to report (IP3).

The procedure line says what the full-data search was, as what ran
beside what was asked for: for a grid or a racing procedure the
candidates scored, the search named; for a Bayesian one the initial
candidates scored and requested, and the iterations completed and
requested, since
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
may score fewer initial candidates than `initial` names and stop short
of `iter`.

## Usage

``` r
# S3 method for class 'nested_final_fit'
print(x, ...)
```

## Arguments

- x:

  A `nested_final_fit` object from
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

## Value

`x`, invisibly.

## See also

[`summary.nested_final_fit()`](https://nestedtune.tidymodels.org/reference/summary.nested_final_fit.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md),
[`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
