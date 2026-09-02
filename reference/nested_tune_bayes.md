# Run the nested cross-validation loop with Bayesian optimization inside

`nested_tune_bayes()` drives the outer loop of nested cross-validation
with
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
as the inner tuner. For each outer fold it scores an initial set of
candidates on that fold's inner resamples, lets a Gaussian process
propose the next `iter` candidates one at a time, selects the best,
finalizes the workflow, and fits and scores it on the outer split with
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).
It is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
with the inner tuner swapped: the loop, the seeds, the results object
and its methods are the same, and that function's help page is the
reference for everything the two share – what a failed fold records, how
the folds run in parallel, and what an operation on the result may do.

## Usage

``` r
nested_tune_bayes(
  object,
  resamples,
  ...,
  iter = 10,
  param_info = NULL,
  metrics = NULL,
  initial = 5,
  objective = tune::exp_improve(),
  event_level = "first",
  eval_time = NULL
)
```

## Arguments

- object:

  A
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  with at least one parameter marked for tuning with
  [`tune::tune()`](https://hardhat.tidymodels.org/reference/tune.html).

- resamples:

  A nested resampling design, from
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  or
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html).
  Its `splits` column must hold `rsplit` objects and its
  `inner_resamples` column an `rset` per outer fold. Both are checked
  before anything is fitted, because
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds a design whatever its `inside` argument returned — so a
  specification that produces no `rset` gives a design that cannot be
  run, where
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  refuses one at construction.

- ...:

  Not used; must be empty. Everything after it is matched by name, so a
  mistyped or unsupported argument is an error rather than a silent
  positional match.

- iter:

  The maximum number of search iterations, passed to
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html).
  A single non-negative whole number. Each iteration proposes one
  candidate and scores it on the fold's inner resamples. `0` scores the
  initial candidates and proposes nothing, which makes the run the same
  as
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  on the space-filling grid those candidates form. tune stops a fold's
  search early when no unscored candidate remains, saying so on the
  console and keeping what it has, and after ten consecutive iterations
  without improvement (its `no_improve` default, not settable here); the
  fold completes with the candidates scored so far, and nothing about
  the early stop reaches `.notes`.

- param_info:

  A
  [`dials::parameters()`](https://dials.tidymodels.org/reference/parameters.html)
  object, or `NULL` to let tune derive one from the workflow. Passed
  unchanged to
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  on every outer fold: the initial candidates are drawn from its ranges,
  and every proposal stays inside them.

- metrics:

  A
  [`yardstick::metric_set()`](https://yardstick.tidymodels.org/reference/metric_set.html),
  or `NULL` to use tune's defaults for the model's mode. The first
  metric in the set selects the best inner candidate.

- initial:

  The number of candidates to score before the first iteration: a single
  whole number of at least 2. Each fold generates its own space-filling
  set of that size from the parameter ranges with
  [`dials::grid_space_filling()`](https://dials.tidymodels.org/reference/grid_space_filling.html)
  and scores it with
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  under the fold's own tuning seed. A `tune_results` object, which
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  also accepts here, is refused: one tuning run cannot serve every outer
  fold, and its candidates were scored on resamples that may hold a
  fold's assessment rows.

- objective:

  An acquisition function from tune, deciding which candidate the
  Gaussian process proposes next:
  [`tune::exp_improve()`](https://tune.tidymodels.org/reference/prob_improve.html)
  (the default),
  [`tune::prob_improve()`](https://tune.tidymodels.org/reference/prob_improve.html)
  or
  [`tune::conf_bound()`](https://tune.tidymodels.org/reference/prob_improve.html).

- event_level:

  `"first"` (the default) or `"second"`, naming which level of a
  two-class outcome factor is the event. It reaches both loops: the
  inner tuning run, where it decides which candidate is selected, and
  the outer scoring fit, where it decides what the reported metrics
  mean. Metrics that do not distinguish the two levels – accuracy,
  `roc_auc`, `brier_class` – are unaffected by it; `sens`, `spec`,
  `precision` and their relatives are not. Ignored for a regression
  model, as it is in tune.

- eval_time:

  A numeric vector of evaluation times for a censored regression model,
  or `NULL` (the default) to leave the choice to tune. It reaches every
  tune call whose answer depends on it, so a dynamic or integrated
  survival metric – `brier_survival()`, `roc_auc_survival()` and their
  relatives – is measured at the times you name. It is ignored, with a
  warning from tune, whenever the metric set has no metric that reads
  it. tune keys that warning on the metrics rather than on the model's
  mode: a set with no survival metric draws one saying the argument is
  only used for censored regression, and a censored regression model
  scored only by a static metric such as `concordance_survival()` draws
  a different one, saying it is only used for dynamic or integrated
  survival metrics.

  Refused here, ahead of tune: anything that is not numeric, an empty
  vector, and any element that is missing, negative or not finite. tune
  treats those unevenly, and only once a metric reads the times – a
  character value that reads as a number, such as `"1"`, is coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) and accepted,
  one that does not becomes missing; a missing, negative or infinite
  element is dropped with a warning; and an empty vector, or one that
  dropping has emptied, aborts – and this package refuses them all at
  entry, before a whole run is paid for. Zero, repeated times and times
  out of order are accepted and passed on untouched, since tune
  normalizes those itself; a repeated time draws tune's warning that 0
  inappropriate evaluation time points were removed, once per tune call.

## Value

An object of class `nested_results`, one row per outer fold, with the
columns
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
documents. Two things differ from a grid run.

Each fold's `.grid` – the candidates its inner search actually scored –
carries an `.iter` column beside the parameter columns and `.config`:
`0` for the initial candidates and `i` for the candidate the `i`-th
iteration proposed. Every candidate that scored on at least one inner
resample is a row, so a fold that stopped early holds the rows it
reached. As on the grid path, a candidate that failed on every inner
resample is absent, and its failure is in `.notes`.

There is no `grid` attribute: `attr(x, "grid")` is `NULL`, because
nothing was asked for as a grid. What was asked for is on the
`procedure` attribute, which every result of either orchestrator
carries: a named list giving the tuner (`"tune_bayes"` here,
`"tune_grid"` there), that tuner's own arguments (`iter`, `initial` and
`objective` here, `grid` there), and `param_info`, `event_level` and
`eval_time` on both. `attr(x, "metrics")` holds the `metrics` argument
as on the grid path, absent when none was given. The record describes
the call, so it travels with the class through every dplyr and vctrs
door the grid path's help page describes, and is shed with the class by
the operations that shed it.

## Details

The estimate this returns describes the whole search-and-fit
*procedure*, not any single fitted model, exactly as for
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md);
report it for that procedure. No final model is returned here: build
that with
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
which takes this result and runs the search it recorded again with the
whole dataset in hand.

## Reproducibility

The seed contract is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)'s:
seed the session before the call, there is no `seed` argument, `2 * n`
seeds are drawn in one `sample.int(.Machine$integer.max, 2 * n)` call on
entry, and fold `i` tunes under element `2 * i - 1` and fits under
element `2 * i`, each applied with the generator kind pinned.

One rule is this function's own.
[`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)
has a `seed` slot that drives the Gaussian-process proposals, and tune
draws it from the stream when it is not given – so left alone, a fold's
proposals would depend on how much of the stream tune had consumed
before reaching it. Here the control is built inside the fold's seed
scope with `seed` set to the fold's tuning seed, the same number
`.tuning_seed` reports. Fold `i` is exactly:

    set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    tuned <- tune_bayes(object, resamples$inner_resamples[[i]],
                        iter = iter, initial = initial, objective = objective,
                        param_info = param_info, metrics = metrics,
                        eval_time = eval_time,
                        control = control_bayes(allow_par = FALSE,
                                                event_level = event_level,
                                                seed = res$.tuning_seed[[i]]))
    final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
    set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    last_fit(final, resamples$splits[[i]], metrics = metrics,
             eval_time = eval_time,
             control = control_last_fit(event_level = event_level))

The caller's RNG state and generator kind are restored on exit,
including when the call errors. The same seed gives the same result
serially and in parallel, at any number of daemons.

## Differences from calling tune directly

There is no `control` argument. What
[`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)
settles is settled here by the arguments above, or forced.

Settable: `iter`, `initial` and `objective`, which are
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)'s
own arguments and reach it unchanged; `event_level`, which reaches the
inner `control_bayes()` and the outer `control_last_fit()` alike; and
`eval_time`, which reaches the inner `tune_bayes()` and the outer
`last_fit()`.

`initial` is a count only. tune also accepts an earlier `tune_grid()`
result there, and this function refuses one, for the reason the
argument's description gives.

Forced: `allow_par = FALSE` on both tune calls a fold makes, because
parallelism belongs over the outer folds; and `seed`, set to the fold's
tuning seed and built inside that seed's scope, as the section above
describes.

Not offered: `no_improve`, `uncertain` and `time_limit`, which keep
[`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)'s
defaults – a fold's search stops once ten consecutive iterations have
brought no improvement (`no_improve = 10`), takes no uncertainty sample
(`uncertain = Inf`) and runs under no time limit (`time_limit = NA`) –
so a fold may stop short of `iter`, and its `.grid` records how far it
went; `save_gp_scoring`, `verbose` and `verbose_iter`, which write to a
daemon's temporary directory or print where nothing collects it; and the
slots that would have nothing to act on here, for the reasons
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
gives.

## See also

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)

## Examples

``` r
# \donttest{
if (rlang::is_installed(c("recipes", "yardstick"))) {
  data(mtcars)

  # Two tunable steps, so the search has candidates to propose.
  rec <- recipes::step_pca(
    recipes::step_ns(
      recipes::recipe(mpg ~ ., data = mtcars),
      disp,
      deg_free = tune::tune()
    ),
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
  res <- nested_tune_bayes(wf, folds, iter = 2, initial = 3)
  collect_metrics(res)

  # What each fold searched: the initial candidates at `.iter` 0, then one
  # proposal per iteration.
  res$.grid[[1]]
}
#> # A tibble: 5 × 4
#>   deg_free num_comp .config         .iter
#>      <int>    <int> <chr>           <int>
#> 1        1        4 pre1_mod0_post0     0
#> 2        8        1 pre2_mod0_post0     0
#> 3       15        2 pre3_mod0_post0     0
#> 4        1        3 iter1               1
#> 5        1        1 iter2               2
# }
```
