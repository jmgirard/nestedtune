# Summarize a nested cross-validation result

Answers what the run means: how much of the requested outer design ran,
which outer folds failed and at which stage, what each fold's inner
tuning selected, and the estimate across the folds that completed.

The selection lines are the part nothing else in the ecosystem shows.
When outer folds choose different parameters, the tuning procedure is
unstable on this data — averaging the metrics hides that, so the summary
marks it.

Summarizing a run that only partly completed warns, and still returns
the summary: the folds that ran are described, and the warning says the
design asked for more. A run where every fold failed is the same case —
it warns and still returns, describing a failed run rather than refusing
to answer. That is where this differs from
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
which aborts when no outer fold completed.

## Usage

``` r
# S3 method for class 'nested_results'
summary(object, ...)

# S3 method for class 'summary.nested_results'
print(x, ...)
```

## Arguments

- object:

  A `nested_results` object from
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md).

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored.

- x:

  A `summary.nested_results` object from `summary.nested_results()`.

## Value

An object of class `summary.nested_results`: a list holding the outer
resampling scheme's label, the outer design's requested and completed
fold counts, the failed folds with the stage each failed at, the
parameter values the completed folds selected, the candidate grid each
completed fold searched, and the metric estimates averaged across them.
Printing it is what most callers want; the components are there for a
caller that needs a number rather than a line of text.

[`print()`](https://rdrr.io/r/base/print.html) returns `x`, invisibly.

## See also

[`print.nested_results()`](https://nestedtune.tidymodels.org/reference/print.nested_results.md),
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
