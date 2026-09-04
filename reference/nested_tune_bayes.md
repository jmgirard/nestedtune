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
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html):
  a data frame whose `splits` column holds one `rsplit` per outer fold,
  whose `inner_resamples` column holds one `rset` with at least one row
  per outer fold, and whose every other column labels the outer folds. A
  label column must be named `id`, or `id` followed by a digit from 1 to
  9 (the names rsample and tune read id columns by), and hold character
  or factor values; taken together, the label columns must give every
  outer fold a distinct label with no `NA`. Inside each inner `rset`,
  every element of its `splits` column is an `rsplit`; all of a fold's
  inner splits carry one frame, either the outer split's own data frame
  (what
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  builds) or that split's analysis set (what
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds); and an inner split carrying the outer data frame indexes, in
  its `in_id` and any non-`NA` `out_id`, only rows the outer split's
  `in_id` holds, so that no inner analysis or assessment set reaches a
  row the outer fold holds out. A design breaking any of this, or using
  a bootstrap for the outer loop, is refused at the call, before
  anything is fitted, with condition class `nestedtune_bad_design` and
  every offending row, column, inner split or index named. The checks
  exist because
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds a design whatever its `inside` argument returned — a
  specification that produces no `rset`, or an empty one, gives a design
  that cannot be run, where
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  refuses one at construction — and because a design assembled by hand
  can index rows its outer fold never sees.

- ...:

  A control object as `control` – what
  [`tune::control_grid()`](https://tune.tidymodels.org/reference/control_grid.html)
  returns for
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  what
  [`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)
  returns for `nested_tune_bayes()` – and nothing else. It reaches the
  inner tuning call in every fold, and in the final fit, with the slots
  this package forces overwritten; the section on differences from tune
  says what becomes of each slot. Any other name is an error, as is an
  unnamed value: everything after `...` is matched by name, so a
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
  and every proposal stays inside them. A parameter whose range is
  unknown until the data is seen is not finalized here:
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  refuses it before any frame is read ("must be a object without
  unknowns"), which every outer fold records as its failure. Finalize it
  first with
  [`dials::finalize()`](https://dials.tidymodels.org/reference/finalize.html)
  on the data. Where
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and the finetune procedures do finalize, it is on the outer fold's
  analysis rows.

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

Each fold's `.inner_metrics` – its inner search's own metrics – carries
an `.iter` column after `.config`: `0` for the initial candidates and
`i` for the candidate the `i`-th iteration proposed, so the search's
trajectory can be drawn from it. Every candidate that scored on at least
one inner resample has its rows, so a fold that stopped early holds the
iterations it reached. As on the grid path, a candidate that failed on
every inner resample is absent, and its failure is in `.notes`.

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
before reaching it. Here the control is given `seed` inside the fold's
seed scope, set to the fold's tuning seed, the same number
`.tuning_seed` reports; the recorded control carries no `seed` for that
reason. Fold `i` is exactly:

    set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    control <- attr(res, "procedure")$control
    control$seed <- res$.tuning_seed[[i]]
    tuned <- tune_bayes(object, resamples$inner_resamples[[i]],
                        iter = iter, initial = initial, objective = objective,
                        param_info = param_info, metrics = metrics,
                        eval_time = eval_time, control = control)
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

There is no `control` formal, but a
[`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)
passed through `...` as `control` reaches the inner `tune_bayes()` in
every fold, and in the final fit that re-runs the result –
`control = control_bayes(no_improve = 5, uncertain = 3)`, say, to stop a
fold's search sooner. What runs is the control passed, or tune's default
when none is, with the slots this package forces overwritten; the result
records that effective control, `seed` left out, as
`attr(res, "procedure")$control`, which is what the recipe above passes.
Every slot of `control_bayes()` falls under one of six headings.

**Forced: `allow_par`, `seed`.** `allow_par = FALSE` on both tune calls
a fold makes, because parallelism belongs over the outer folds; and
`seed`, set to the fold's tuning seed inside that seed's scope, as the
section above describes – whatever the control carries for either.

**Settable as its own argument: `event_level`.** As on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
the argument is the one place the level is set, a control left at tune's
default takes it, and a control naming a level that is neither tune's
default nor the argument's is refused at entry, naming both. `iter`,
`initial`, `objective` and `eval_time` are
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)'s
own arguments rather than control slots, offered here as arguments and
reaching it unchanged. `initial` is a count only: tune also accepts an
earlier `tune_grid()` result there, and this function refuses one, for
the reason the argument's description gives.

**Refused: none.** No slot is refused on its own. What is refused at
entry is a control of another class – a `control_grid()`, which tune
itself would accept here – and the `event_level` conflict above.

**Passed through: `no_improve`, `uncertain`, `time_limit`, `verbose`,
`verbose_iter`, `save_gp_scoring`, `pkgs`, `parallel_over`,
`workflow_size`.** Each reaches `tune_bayes()` as given. `no_improve`
and `uncertain` govern each fold's search as they would a direct call,
so a fold may stop short of `iter`, and its `.inner_metrics` records how
far it went. `time_limit` is a wall-clock stop, and a wall-clock stop
makes the candidate set depend on the machine: two runs under the same
seed can stop at different iterations, which is outside what the seed
contract above can promise. `verbose` and `verbose_iter` print from a
serial run, and from a mirai daemon where nothing shows it.
`save_gp_scoring` writes its files to the temporary directory of the
process that tuned, a daemon's own on the parallel path. `pkgs`,
`parallel_over` and `workflow_size` behave as on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
`parallel_over` included: it changes the numbers a stochastic engine
produces even at `allow_par = FALSE`.

**Not returned: `extract`, `save_pred`, `save_workflow`.** As on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
each lands on the inner `tune_results` a fold record discards, so on a
nested run setting them costs the work and returns nothing; the final
fit keeps its tuning run as `$tuning`, where what they saved is
reachable.

**Inert: `backend_options`.** Options for a parallel backend, with no
backend to reach at `allow_par = FALSE`.

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

  # What each fold searched and how each candidate scored: the initial
  # candidates at `.iter` 0, then one proposal per iteration.
  res$.inner_metrics[[1]]
}
#> # A tibble: 10 × 9
#>    deg_free num_comp .metric .estimator  mean     n std_err .config    
#>       <int>    <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>      
#>  1        1        4 rmse    standard   3.63      3  0.648  pre1_mod0_…
#>  2        1        4 rsq     standard   0.838     3  0.0713 pre1_mod0_…
#>  3        8        1 rmse    standard   5.04      3  0.522  pre2_mod0_…
#>  4        8        1 rsq     standard   0.742     3  0.0515 pre2_mod0_…
#>  5       15        2 rmse    standard   4.88      3  0.585  pre3_mod0_…
#>  6       15        2 rsq     standard   0.766     3  0.0241 pre3_mod0_…
#>  7        1        3 rmse    standard   3.45      3  0.619  iter1      
#>  8        1        3 rsq     standard   0.826     3  0.0499 iter1      
#>  9        1        1 rmse    standard   5.04      3  0.522  iter2      
#> 10        1        1 rsq     standard   0.742     3  0.0515 iter2      
#> # ℹ 1 more variable: .iter <int>
# }
```
