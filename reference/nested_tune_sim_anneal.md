# Run the nested cross-validation loop with simulated annealing inside

`nested_tune_sim_anneal()` drives the outer loop of nested
cross-validation with
[`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)
as the inner tuner. For each outer fold it scores an initial set of
candidates on that fold's inner resamples, then for `iter` iterations
perturbs the current candidate, scores the perturbation and keeps it or
falls back by finetune's annealing rule, selects the best, finalizes the
workflow, and fits and scores it on the outer split with
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).
It is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
with the inner tuner swapped, and
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)'s
sibling: the loop, the seeds, the results object and its methods are the
same, and the grid function's help page is the reference for everything
the orchestrators share – what a failed fold records, how the folds run
in parallel, and what an operation on the result may do.

## Usage

``` r
nested_tune_sim_anneal(
  object,
  resamples,
  ...,
  iter = 10,
  param_info = NULL,
  metrics = NULL,
  initial = 1,
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

  A control object as `control` – what
  [`finetune::control_sim_anneal()`](https://finetune.tidymodels.org/reference/control_sim_anneal.html)
  returns – and nothing else. It reaches the inner search in every fold,
  and in the final fit, with the slots this package forces overwritten;
  the section on differences from finetune says what becomes of each
  slot. Any other name is an error, as is an unnamed value.

- iter:

  The number of search iterations, passed to
  [`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html).
  A single whole number of at least 1. Each iteration perturbs the
  current candidate and scores the result on the fold's inner resamples.
  `0` is refused: finetune 1.3.0 iterates over
  `(existing_iter + 1):iter`, which at `iter = 0` is `1:0`, so it runs
  two iterations rather than none – where
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  at `iter = 0` proposes nothing, and
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  accepts it. finetune stops a fold's search early after `no_improve`
  consecutive iterations without improvement (`Inf` by default, so
  never, unless the control sets it) or when `time_limit` is reached;
  the fold completes with the candidates scored so far, and nothing
  about the early stop reaches `.notes`.

- param_info:

  A
  [`dials::parameters()`](https://dials.tidymodels.org/reference/parameters.html)
  object, or `NULL` to let tune derive one from the workflow. Passed
  unchanged to
  [`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)
  on every outer fold: the initial candidates are drawn from its ranges,
  and every perturbation stays inside them. A parameter whose range is
  unknown until the data is seen is finalized by finetune on the outer
  fold's analysis rows, never on the rows that fold holds out, as
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  describes;
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  finalizes on the full data.

- metrics:

  A
  [`yardstick::metric_set()`](https://yardstick.tidymodels.org/reference/metric_set.html),
  or `NULL` to use tune's defaults for the model's mode. The first
  metric in the set selects the best inner candidate.

- initial:

  The number of candidates to score before the first iteration: a single
  whole number of at least 1, finetune's default. Each fold generates
  its own space-filling set of that size from the parameter ranges with
  [`dials::grid_space_filling()`](https://dials.tidymodels.org/reference/grid_space_filling.html)
  and scores it with
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  under the fold's own tuning seed. A `tune_results` object, which
  [`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)
  also accepts here, is refused: one tuning run cannot serve every outer
  fold, and its candidates were scored on resamples that may hold a
  fold's assessment rows.

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
documents. Two things differ from a grid run, as they do for
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md).

Each fold's `.inner_metrics` – its inner search's own metrics – carries
an `.iter` column after `.config`: `0` for the initial candidates, whose
`.config` finetune prefixes `initial_`, and `i` for the candidate the
`i`-th iteration scored, labelled `Iter<i>`, so the search's trajectory
can be drawn from it. Every candidate that scored on at least one inner
resample has its rows, so a fold that stopped early holds the iterations
it reached. As on the grid path, a candidate that failed on every inner
resample is absent, and its failure is in `.notes`.

There is no `grid` attribute: `attr(x, "grid")` is `NULL`, because
nothing was asked for as a grid. What was asked for is on the
`procedure` attribute: a named list giving the tuner
(`"tune_sim_anneal"`), its own arguments `iter` and `initial`, and
`param_info`, `event_level`, `eval_time` and the effective control, as
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
describes. `attr(x, "metrics")` holds the `metrics` argument as on the
grid path, absent when none was given.

## Details

The estimate this returns describes the whole search-and-fit
*procedure*, not any single fitted model, exactly as for
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md);
report it for that procedure. No final model is returned here: build
that with
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
which takes this result and runs the search it recorded again with the
whole dataset in hand.

finetune must be installed; a missing package is refused at entry,
before any fold runs.

## Reproducibility

The seed contract is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)'s:
seed the session before the call, there is no `seed` argument, `2 * n`
seeds are drawn in one `sample.int(.Machine$integer.max, 2 * n)` call on
entry, and fold `i` tunes under element `2 * i - 1` and fits under
element `2 * i`, each applied with the generator kind pinned.

Annealing draws from the generator even with a deterministic engine: the
initial candidates are a space-filling design drawn under the fold's
tuning seed, and each perturbation is drawn from the stream that seed
started.
[`finetune::control_sim_anneal()`](https://finetune.tidymodels.org/reference/control_sim_anneal.html)
has no seed slot, so nothing is injected into the control; the fold's
tuning seed alone governs the search. Fold `i` is exactly (with
`resamples$inner_resamples[[i]]` read as
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)'s
reproducibility section reads it):

    set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    control <- attr(res, "procedure")$control
    tuned <- tune_sim_anneal(object, resamples$inner_resamples[[i]],
                             iter = iter, initial = initial,
                             param_info = param_info, metrics = metrics,
                             eval_time = eval_time, control = control)
    final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
    set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    last_fit(final, resamples$splits[[i]], metrics = metrics,
             eval_time = eval_time,
             control = control_last_fit(event_level = event_level))

and `res$.inner_metrics[[i]]` is `collect_metrics(tuned)`,
`res$.selected[[i]]` the `select_best()` above.

The caller's RNG state and generator kind are restored on exit,
including when the call errors. The same seed gives the same result
serially and in parallel, at any number of daemons – provided every
daemon's library holds finetune, which the loop attaches in each daemon
before the first fold is sent and warns about where it cannot.

## Differences from calling finetune directly

There is no `control` formal, but a
[`finetune::control_sim_anneal()`](https://finetune.tidymodels.org/reference/control_sim_anneal.html)
passed through `...` as `control` reaches the inner search in every
fold, and in the final fit that re-runs the result –
`control = control_sim_anneal( no_improve = 5, verbose_iter = FALSE)`,
say, to stop a fold's search sooner and keep the console quiet. What
runs is the control passed, or finetune's default when none is, with the
slots this package forces overwritten; the result records that effective
control as `attr(res, "procedure")$control`, which is what the recipe
above passes. Every slot of `control_sim_anneal()` falls under one of
six headings.

**Forced: `allow_par`.** Both tune calls a fold makes – the inner search
and the outer scoring fit – run at `allow_par = FALSE`, whatever the
control carries. Parallelism belongs over the outer folds, and leaving
that to a caller would put two pools in contention.

**Settable as its own argument: `event_level`.** As on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
the argument is the one place the level is set, a control left at
finetune's default takes it, and a control naming a level that is
neither finetune's default nor the argument's is refused at entry,
naming both. `iter`, `initial` and `eval_time` are
[`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)'s
own arguments rather than control slots, offered here as arguments and
reaching it unchanged. `initial` is a count only: finetune also accepts
an earlier tuning result there, and this function refuses one, for the
reason the argument's description gives.

**Refused: none.** No slot is refused on its own. What is refused at
entry is a control of another class – a `control_bayes()`, which
finetune itself would run under – and the `event_level` conflict above.

**Passed through: `no_improve`, `restart`, `radius`, `flip`,
`cooling_coef`, `time_limit`, `verbose`, `verbose_iter`, `pkgs`,
`parallel_over`, `workflow_size`.** Each reaches `tune_sim_anneal()` as
given. `no_improve`, `restart`, `radius`, `flip` and `cooling_coef`
govern each fold's search as they would a direct call: when a search
stops or restarts from its best candidate, how far and how a
perturbation moves, and how the acceptance probability cools.
`time_limit` is a wall-clock stop, and a wall-clock stop makes the
candidate set depend on the machine: two runs under the same seed can
stop at different iterations, which is outside what the seed contract
above can promise. `verbose_iter`, `TRUE` in finetune's default, prints
the annealing log from every fold of a serial run, one log per fold, and
from a mirai daemon where nothing shows it; pass
`control = control_sim_anneal(verbose_iter = FALSE)` for a quiet run.
`verbose` likewise. `pkgs`, `parallel_over` and `workflow_size` behave
as on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
`parallel_over` included: it changes the numbers a stochastic engine
produces even at `allow_par = FALSE`.

**Not returned: `extract`, `save_pred`, `save_workflow`,
`save_history`.** The first three as on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
each lands on the inner `tune_results` a fold record discards, so on a
nested run setting them costs the work and returns nothing; the final
fit keeps its tuning run as `$tuning`, where what they saved is
reachable. `save_history` writes finetune's search history to
`sa_history.RData` in the temporary directory of the process that tuned
– a daemon's own on the parallel path – and every fold overwrites the
last one's; nothing of it reaches the result.

**Inert: `backend_options`.** Options for a parallel backend, with no
backend to reach at `allow_par = FALSE`.

## See also

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
[`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)

## Examples

``` r
# \donttest{
if (rlang::is_installed(c("finetune", "recipes", "yardstick"))) {
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
  res <- nested_tune_sim_anneal(
    wf,
    folds,
    iter = 3,
    initial = 2,
    control = finetune::control_sim_anneal(verbose_iter = FALSE)
  )
  collect_metrics(res)

  # What each fold searched and how each candidate scored: the initial
  # candidates at `.iter` 0, then one perturbation per iteration.
  res$.inner_metrics[[1]]
}
#> # A tibble: 10 × 8
#>    num_comp .metric .estimator  mean     n std_err .config        .iter
#>       <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>          <int>
#>  1        2 rmse    standard   3.39      6  0.316  initial_pre1_…     0
#>  2        2 rsq     standard   0.815     6  0.0532 initial_pre1_…     0
#>  3        4 rmse    standard   3.52      3  0.536  initial_pre2_…     0
#>  4        4 rsq     standard   0.806     3  0.0777 initial_pre2_…     0
#>  5        3 rmse    standard   3.46      3  0.554  Iter1              1
#>  6        3 rsq     standard   0.807     3  0.0798 Iter1              1
#>  7        1 rmse    standard   3.39      3  0.468  Iter2              2
#>  8        1 rsq     standard   0.818     3  0.0853 Iter2              2
#>  9        2 rmse    standard   3.39      6  0.316  Iter3              3
#> 10        2 rsq     standard   0.815     6  0.0532 Iter3              3
# }
```
