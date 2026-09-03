# Run the nested cross-validation loop with racing inside

`nested_tune_race_anova()` and `nested_tune_race_win_loss()` drive the
outer loop of nested cross-validation with finetune's two racing tuners,
[`finetune::tune_race_anova()`](https://finetune.tidymodels.org/reference/tune_race_anova.html)
and
[`finetune::tune_race_win_loss()`](https://finetune.tidymodels.org/reference/tune_race_win_loss.html),
as the inner tuner. For each outer fold the race scores every candidate
in `grid` on the first `burn_in` inner resamples, drops the candidates
that are already clearly worse than the best – by a repeated-measures
ANOVA, or by a Bradley-Terry model of pairwise wins and losses – and
scores the survivors on the remaining resamples, dropping more as the
evidence comes in; the fold then selects the best, finalizes the
workflow, and fits and scores it on the outer split with
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).
Each is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
with the inner tuner swapped: the arguments, the loop, the seeds, the
results object and its methods are the same, and that function's help
page is the reference for everything the three share – what a failed
fold records, how the folds run in parallel, and what an operation on
the result may do.

## Usage

``` r
nested_tune_race_anova(
  object,
  resamples,
  ...,
  param_info = NULL,
  grid = 10,
  metrics = NULL,
  event_level = "first",
  eval_time = NULL
)

nested_tune_race_win_loss(
  object,
  resamples,
  ...,
  param_info = NULL,
  grid = 10,
  metrics = NULL,
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
  [`finetune::control_race()`](https://finetune.tidymodels.org/reference/control_race.html)
  returns – and nothing else. It reaches the inner race in every fold,
  and in the final fit, with the slots this package forces overwritten;
  the section on differences from finetune says what becomes of each
  slot. Any other name is an error, as is an unnamed value.

- param_info:

  A
  [`dials::parameters()`](https://dials.tidymodels.org/reference/parameters.html)
  object, or `NULL` to let tune derive one from the workflow. Passed
  unchanged to
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
  on every outer fold, so a restricted range restricts the grid every
  fold searches. A parameter whose range is unknown until the data is
  seen (`mtry()`, or a `min_n()` finalized by row count) is finalized by
  tune on the outer fold's analysis rows – never on the rows that fold
  holds out – so on a
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  design the inner call receives the fold's inner resamples re-pointed
  at its analysis set rather than the design's own `inner_resamples`
  element, which indexes the whole data. A design from
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  already carries the analysis set and is passed as it is, as is the
  design's element under an outer split that repeats a row (an evaluated
  [`rsample::manual_rset()`](https://rsample.tidymodels.org/reference/manual_rset.html)),
  where the re-pointing is ambiguous.
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  finalizes on the full data.

- grid:

  A data frame of candidate parameter values, or a positive whole number
  giving the size of a grid to generate: the design the race is offered.
  Passed to the racing function, which scores every candidate on the
  burn-in resamples and only the survivors after that. A data frame is
  checked against the workflow before anything is fitted, as on
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md).

- metrics:

  A
  [`yardstick::metric_set()`](https://yardstick.tidymodels.org/reference/metric_set.html),
  or `NULL` to use tune's defaults for the model's mode. The first
  metric in the set selects the best inner candidate.

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
documents. One thing differs from a grid run, and it is the point of
racing.

Each fold's `.inner_metrics` holds every candidate its race scored,
eliminated candidates included –
`tune::collect_metrics(<the race>, all_configs = TRUE)`, where
finetune's own default keeps the survivors alone – and `n` is the number
of inner resamples each candidate was scored on: the full inner resample
count for a candidate that survived to the end, and fewer for one
eliminated along the way. The recorded `grid`, on the `procedure`
attribute and as `attr(x, "grid")`, is the design the race was
*offered*, exactly as given; what each candidate *ran* is `n`. A
candidate that failed on every inner resample is absent, and its failure
is in `.notes`, as on the grid path.

`attr(x, "procedure")` names the tuner (`"tune_race_anova"` or
`"tune_race_win_loss"`) and holds the `grid`, `param_info`,
`event_level`, `eval_time` and the effective control, as
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
describes.

## Details

The estimate this returns describes the whole race-and-fit *procedure*,
not any single fitted model, exactly as for
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md);
report it for that procedure. No final model is returned here: build
that with
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
which takes this result and races the same grid again with the whole
dataset in hand.

Both functions need finetune installed; `nested_tune_race_anova()` also
needs lme4, which fits the ANOVA, and `nested_tune_race_win_loss()`
BradleyTerry2, which fits the win/loss model. A missing package is
refused at entry, before any fold runs.

## Reproducibility

The seed contract is
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)'s:
seed the session before the call, there is no `seed` argument, `2 * n`
seeds are drawn in one `sample.int(.Machine$integer.max, 2 * n)` call on
entry, and fold `i` races under element `2 * i - 1` and fits under
element `2 * i`, each applied with the generator kind pinned.

A race draws from the generator even with a deterministic engine: with
`randomize = TRUE` (finetune's default) the inner resamples are shuffled
before the burn-in, so which resamples the burn-in uses, and with it
which candidates are eliminated when, comes from the fold's tuning seed.
Fold `i` is exactly (with `resamples$inner_resamples[[i]]` read as
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)'s
reproducibility section reads it):

    set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    control <- attr(res, "procedure")$control
    raced <- tune_race_anova(object, resamples$inner_resamples[[i]],
                             grid = grid, param_info = param_info,
                             metrics = metrics, eval_time = eval_time,
                             control = control)   # or tune_race_win_loss()
    final <- finalize_workflow(object, select_best(raced, metric = <first metric>))
    set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    last_fit(final, resamples$splits[[i]], metrics = metrics,
             eval_time = eval_time,
             control = control_last_fit(event_level = event_level))

and `res$.inner_metrics[[i]]` is
`collect_metrics(raced, all_configs = TRUE)`, `res$.selected[[i]]` the
`select_best()` above.

The caller's RNG state and generator kind are restored on exit,
including when the call errors. The same seed gives the same result
serially and in parallel, at any number of daemons – provided every
daemon's library holds finetune, which the loop attaches in each daemon
before the first fold is sent and warns about where it cannot.

## Differences from calling finetune directly

There is no `control` formal, but a
[`finetune::control_race()`](https://finetune.tidymodels.org/reference/control_race.html)
passed through `...` as `control` reaches the inner race in every fold,
and in the final fit that re-runs the result –
`control = control_race(burn_in = 2)`, say, on a design with three inner
resamples. What runs is the control passed, or finetune's default when
none is, with the slots this package forces overwritten; the result
records that effective control as `attr(res, "procedure")$control`,
which is what the recipe above passes. Every slot of `control_race()`
falls under one of six headings.

**Forced: `allow_par`.** Both tune calls a fold makes – the inner race
and the outer scoring fit – run at `allow_par = FALSE`, whatever the
control carries. Parallelism belongs over the outer folds, and leaving
that to a caller would put two pools in contention.

**Settable as its own argument: `event_level`.** As on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
the argument is the one place the level is set, a control left at
finetune's default takes it, and a control naming a level that is
neither finetune's default nor the argument's is refused at entry,
naming both. `grid` and `eval_time` are the racing functions' own
arguments rather than control slots, offered here as arguments and
reaching them unchanged.

**Refused: none.** No slot is refused on its own. What is refused at
entry is a control of another class – a `control_grid()`, which finetune
itself would accept here – the `event_level` conflict above, and a
`burn_in` no fold's inner design can meet: finetune refuses a race whose
resample count is not greater than `burn_in`, and this package refuses
the whole call before any fold runs when any outer fold's inner `rset`
would be, naming the count and the burn-in. `control_race()` defaults
`burn_in` to 3, so a design with three inner resamples needs
`control = control_race(burn_in = 2)` or fewer.

**Passed through: `burn_in`, `alpha`, `num_ties`, `randomize`,
`verbose_elim`, `verbose`, `pkgs`, `parallel_over`, `workflow_size`.**
Each reaches the race as given. `burn_in`, `alpha`, `num_ties` and
`randomize` govern each fold's race as they would a direct call: how
many resamples every candidate is scored on before elimination starts,
the significance level an elimination needs, how many rounds two tied
survivors are given before one is dropped, and whether the resamples are
shuffled first – the draw the section above describes. `verbose_elim`
prints finetune's elimination log from a serial run, once per fold, and
from a mirai daemon where nothing shows it; `verbose` likewise. `pkgs`,
`parallel_over` and `workflow_size` behave as on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
`parallel_over` included: it changes the numbers a stochastic engine
produces even at `allow_par = FALSE`.

**Not returned: `extract`, `save_pred`, `save_workflow`.** As on
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md):
each lands on the inner race result a fold record discards, so on a
nested run setting them costs the work and returns nothing; the final
fit keeps its race as `$tuning`, where what they saved is reachable.

**Inert: `backend_options`.** Options for a parallel backend, with no
backend to reach at `allow_par = FALSE`.

## See also

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
[`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md),
[`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
[`finetune::tune_race_anova()`](https://finetune.tidymodels.org/reference/tune_race_anova.html),
[`finetune::tune_race_win_loss()`](https://finetune.tidymodels.org/reference/tune_race_win_loss.html)

## Examples

``` r
# \donttest{
if (rlang::is_installed(c("finetune", "lme4", "recipes", "yardstick"))) {
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
    inside = rsample::vfold_cv(v = 5)
  )

  set.seed(2)
  res <- nested_tune_race_anova(
    wf,
    folds,
    grid = data.frame(num_comp = 1:4),
    control = finetune::control_race(burn_in = 2, verbose_elim = FALSE)
  )
  collect_metrics(res)

  # Every candidate the first fold's race scored, and on how many inner
  # resamples: `n` below 5 is a candidate the race eliminated.
  res$.inner_metrics[[1]]
}
#> # A tibble: 8 × 7
#>   num_comp .metric .estimator  mean     n std_err .config        
#>      <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>          
#> 1        1 rmse    standard   3.12      5  0.328  pre1_mod0_post0
#> 2        1 rsq     standard   0.792     5  0.0585 pre1_mod0_post0
#> 3        2 rmse    standard   3.37      5  0.403  pre2_mod0_post0
#> 4        2 rsq     standard   0.783     5  0.0575 pre2_mod0_post0
#> 5        3 rmse    standard   3.21      3  0.662  pre3_mod0_post0
#> 6        3 rsq     standard   0.707     3  0.0649 pre3_mod0_post0
#> 7        4 rmse    standard   3.22      3  0.663  pre4_mod0_post0
#> 8        4 rsq     standard   0.713     3  0.0628 pre4_mod0_post0
# }
```
