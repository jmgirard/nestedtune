# Fit the final model after nested cross-validation

`nested_final_fit()` runs the tuning procedure a nested run recorded
once more, with the whole dataset in hand: it re-evaluates the design's
inner resampling specification against every row, tunes with
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html),
one of finetune's racers or
[`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)
under the arguments the results object carries, selects the best
candidate, finalizes the workflow, and fits it on all the data. The
result is the model to deploy, built by the same search the estimate you
report describes.

## Usage

``` r
nested_final_fit(object, results, ...)
```

## Arguments

- object:

  A
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  with at least one parameter marked for tuning with
  [`tune::tune()`](https://hardhat.tidymodels.org/reference/tune.html):
  the workflow the nested run was built around. For a grid or a racing
  procedure it is checked against the recorded grid the way
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  checked it, so a different workflow is refused here rather than by
  tune one tuning run later.

- results:

  The `nested_results` object from
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
  [`nested_tune_race_anova()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md),
  [`nested_tune_race_win_loss()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
  or
  [`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md)
  whose estimate you will report for this model. Everything the re-run
  needs is read from it: the design's inner resampling specification,
  recorded on the result as the design stored it; the data, which every
  split references; and the procedure – the tuner and its own arguments
  (`grid`; `iter`, `initial` and `objective`; or `iter` and `initial`)
  with `param_info`, `event_level` and `eval_time`, and the metric set.
  A results object that carries no such record (one built by an earlier
  version of nestedtune, or from a design assembled by hand rather than
  by
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  or
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)),
  one that is no longer a `nested_results` (an operation that added or
  removed rows returns a plain tibble), and one with no rows are each
  refused before any fitting, with condition class
  `nestedtune_bad_results`. A results object in which no outer fold
  completed is refused next, with condition class
  `nestedtune_no_completed_folds`: there is no estimate to report a
  model with, and [`summary()`](https://rdrr.io/r/base/summary.html) on
  the object lists the stage each fold failed at. That is the class
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
  [autoplot()](https://nestedtune.tidymodels.org/reference/autoplot.nested_results.md)
  and
  [`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md)
  refuse the same object with. A run in which some folds failed is
  fitted; its estimate is
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)'s,
  with that function's partial-run warning.

- ...:

  Not used; must be empty. An argument passed here is an error rather
  than silently ignored – in particular the former `grid`, `param_info`,
  `metrics`, `event_level` and `eval_time` arguments, which now come
  from `results`.

## Value

An object of class `nested_final_fit` with elements `workflow` (the
trained workflow; the object answers
[predict()](https://nestedtune.tidymodels.org/reference/predict.nested_final_fit.md)
and [`augment()`](https://generics.r-lib.org/reference/augment.html)
directly, and
[`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)
returns the workflow itself), `selected` (the parameters chosen),
`tuning` (the tuning run they were chosen from), `tuning_seed` and
`fit_seed` (the two seeds that reproduce it), and `procedure` (the
record re-run, as `results` carried it).

## Details

The procedure a nested estimate describes is "resample this dataset by
the inner specification, tune, select, fit", and the dataset that
procedure is meant to be applied to is all of yours. So the final model
comes from running it again with nothing held out — the same convention
as cross-validating a model and then refitting on everything, one level
up.

The outer folds play no part. Their selections are not pooled or voted
on: they belong to the estimate, which describes the procedure across
the instability those selections reveal, and not to this model.

## What to report

Report the estimate from
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
on the results object you handed over – the result of
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
or one of its siblings – as this model's performance. The model and the
estimate come from one search by construction: the procedure is read
from that object and cannot be restated here. That number estimates the
k-fold test error of the whole tune-and-fit procedure that produced this
model, measured on data no part of the procedure ever touched. Expect it
to run slightly pessimistic: each outer fold trains on its analysis rows
alone, so every model it scores is built on less data than this one.
Varma and Simon (2006) measured a 4.2-point overshoot from that effect
at n = 40, and Wilimitis and Walsh (2023) about 1-2% of AUROC on 41,121
records. The offset shrinks with fold size and is not a correction to
apply.

The model in hand has no honest number of its own. Everything computable
from its training data was consumed by selection or by fitting,
**including the resampling metrics inside the tuning run stored on this
object**: those are selection-time quantities, optimistically biased as
a performance claim, and
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
on `x$tuning` will hand them over without saying so. They are kept
because they are the record of what selection saw, not because they
describe this model.

Two things the nested estimate does not say. It is marginal over
selection, not conditional on the parameters this model happens to
carry, so it is not a claim about this configuration specifically. And
it describes new data drawn like your training data — not a different
population, and not a model retrained at a different size.

If the outer folds disagreed about the best parameters, report that too.

## Reproducibility

Seed the session before the call, as elsewhere in tidymodels; there is
no `seed` argument. On entry the function draws two seeds in a single
`sample.int(.Machine$integer.max, 2)` call. The first covers building
the inner resamples *and* tuning; the second covers the final fit. Both
are applied with the generator kind pinned, and both are returned on the
object.

The run is reproducible by hand from those two seeds and the record on
`fit$procedure`, every value below being one that record holds (or, for
`metrics`, `attr(results, "metrics")`); the tuning call is the one the
record names, and `control` is the record's own – the control the run
was given, or tune's default, with the slots the orchestrator forces
already applied:

    set.seed(fit$tuning_seed, kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    inner <- <the design's `inside` specification>(data)
    control <- fit$procedure$control
    # a grid procedure
    tuned <- tune_grid(object, inner, grid = grid, param_info = param_info,
      metrics = metrics, eval_time = eval_time, control = control)
    # a Bayesian procedure: the Gaussian process is seeded from the tuning
    # seed, the rule nested_tune_bayes() fixes for every fold, so the
    # recorded control -- which carries no seed -- takes it here
    control$seed <- fit$tuning_seed
    tuned <- tune_bayes(object, inner, iter = iter, initial = initial,
      objective = objective, param_info = param_info, metrics = metrics,
      eval_time = eval_time, control = control)
    final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
    set.seed(fit$fit_seed, kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    fit(final, data)

Building the resamples sits *inside* the first seed's scope, not before
it: constructing an `rset` draws from the generator, so a version that
built them earlier would still be reproducible from the session seed but
no longer from the two seeds above.

The caller's RNG state and generator kind are restored on exit,
including when the call errors. One consequence worth knowing: two
consecutive calls with no
[`set.seed()`](https://rdrr.io/r/base/Random.html) between them return
identical results, exactly as repeated
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
calls do.

This binds randomness that flows through R's generator. Engines that
randomize outside it — kernlab's SVMs, the deep-learning engines —
cannot be pinned by any R-side scheme, here or in tune.

## The inner specification is re-evaluated

A nested design stores its `inside` argument as an unevaluated call, the
nested run records it on its result, and this function evaluates it
again — against the whole dataset, in the environment you call from, not
the one the design was built in.

Write it with literal arguments. `inside = vfold_cv(v = 5)` is
re-evaluated identically anywhere. `inside = vfold_cv(v = k)` is not: if
`k` is gone by the time you call this, you get an error naming the
specification, and if some *other* `k` is in scope you silently get a
different design. Building a design inside a function that parameterizes
its resampling is the common way to meet this.

## References

Varma, S., & Simon, R. (2006). Bias in error estimation when using
cross-validation for model selection. *BMC Bioinformatics*, 7, 91.

Wilimitis, D., & Walsh, C. G. (2023). Practical considerations and
applied examples of cross-validation for model development and
evaluation in health care: Tutorial. *JMIR AI*, 2, e49023.

## See also

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
[`predict.nested_final_fit()`](https://nestedtune.tidymodels.org/reference/predict.nested_final_fit.md),
[`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)

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

# The estimate: what the procedure achieves.
set.seed(2)
res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
collect_metrics(res)
#> # A tibble: 2 × 5
#>   .metric .estimator  mean     n std_err
#>   <chr>   <chr>      <dbl> <int>   <dbl>
#> 1 rmse    standard   3.23      3   0.316
#> 2 rsq     standard   0.722     3   0.112

# The model: what you deploy. Report the estimate above for it.
set.seed(3)
final <- nested_final_fit(wf, res)
final
#> 
#> ── Nested cross-validation final fit ──────────────────────────────────
#> Procedure: grid search, 3 candidates scored
#> Selected: num_comp = 1
#> 
#> ℹ This model has no performance estimate of its own. Report the nested
#>   estimate from `collect_metrics()` on the results object this fit was
#>   built from, which describes the procedure that produced it.
#> ℹ Compare the parameters above with `.selected` from that run. Outer
#>   folds choosing differently is selection instability, and it is
#>   information about the procedure rather than noise.
#> ℹ `extract_tune_results()` returns the tuning run selection came from,
#>   and `extract_scored_candidates()` the candidates it scored. Any
#>   metric reachable through the first is a selection-time quantity,
#>   optimistically biased as a claim about this model.

predict(final, new_data = mtcars[1:3, ])
#> # A tibble: 3 × 1
#>   .pred
#>   <dbl>
#> 1  23.1
#> 2  23.1
#> 3  25.2
```
