# Run the nested cross-validation loop

`nested_tune_grid()` drives the outer loop of nested cross-validation.
For each outer fold it tunes on that fold's inner resamples with
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
selects the best candidate, finalizes the workflow, and fits and scores
it on the outer split with
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).
Every step is delegated to tune; what this function contributes is the
loop, the reproducibility contract, and a results object that keeps each
fold's chosen parameters rather than discarding them.

## Usage

``` r
nested_tune_grid(object, resamples, grid = 10, metrics = NULL)
```

## Arguments

- object:

  A
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  with at least one parameter marked for tuning with
  [`tune::tune()`](https://hardhat.tidymodels.org/reference/tune.html).

- resamples:

  A nested resampling design, from
  [`nested_resamples()`](https://jmgirard.github.io/nestedtune/reference/nested_resamples.md)
  or
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html).
  Its `splits` column must hold `rsplit` objects and its
  `inner_resamples` column an `rset` per outer fold. Both are checked
  before anything is fitted, because
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds a design whatever its `inside` argument returned — so a
  specification that produces no `rset` gives a design that cannot be
  run, where
  [`nested_resamples()`](https://jmgirard.github.io/nestedtune/reference/nested_resamples.md)
  refuses one at construction.

- grid:

  A data frame of candidate parameter values, or a positive whole number
  giving the size of a grid to generate. Passed to
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html).
  A data frame is checked against the workflow before anything is
  fitted: every column must name a parameter marked with
  [`tune::tune()`](https://hardhat.tidymodels.org/reference/tune.html),
  and every such parameter must have a column.

- metrics:

  A
  [`yardstick::metric_set()`](https://yardstick.tidymodels.org/reference/metric_set.html),
  or `NULL` to use tune's defaults for the model's mode. The first
  metric in the set selects the best inner candidate.

## Value

An object of class `nested_results`: one row per outer fold, with the
fold's split and id, the metrics scored on its assessment set
(`.metrics`), the parameters chosen for it by inner tuning
(`.selected`), the candidates its inner tuning actually scored
(`.grid`), whether the fold finished (`.completed`), anything that went
wrong (`.notes`), and the two seeds that reproduce it (`.tuning_seed`,
`.outer_fit_seed`). Use
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
to summarize.

**Two records describe the grid, and they answer different questions.**
`attr(x, "grid")` holds the `grid` argument **as it was given** — a
positive whole number, not a table of candidates, whenever a size was
passed. The `.grid` column holds what each outer fold's inner tuning
actually scored, one table per fold with a column per tuned parameter.

The two diverge routinely, in both directions. A size is expanded by
tune and may reach fewer candidates than were asked for — a request for
20 on a parameter with four reachable values evaluates four — and a
candidate that fails scores nothing. Folds can also differ from *each
other*: expanding a size draws from the generator, and each fold tunes
under its own seed, so a continuous parameter gives every fold its own
candidates. Printing says so when it happens.

One limit is worth stating plainly. `.grid` is derived from the tuning
run's own metrics, because that is the only place tune records
candidates at all. A candidate that failed on **every** inner resample
scored nothing and is therefore absent from `.grid` — `.notes` is where
its failure is recorded. A fold that scored no candidate at all carries
a zero-row table, never `NULL`.

`attr(x, "metrics")` holds the `metrics` argument, and is absent rather
than `NULL` when none was supplied. Subsetting rows carries both
attributes unchanged, since they describe the call rather than the rows
kept; `.grid` is a column, so it travels with the fold it describes.

## Details

The estimate this returns describes the whole tune-and-fit *procedure*,
not any single fitted model. It is not the performance of a model you
can deploy, and no final model is returned here: build that with
[`nested_final_fit()`](https://jmgirard.github.io/nestedtune/reference/nested_final_fit.md),
which runs the same procedure again with the whole dataset in hand. The
estimate from this function is what you report for it.

## Reproducibility

Seed the session before the call, as elsewhere in tidymodels; there is
no `seed` argument. On entry the function draws `2 * n` seeds in a
single `sample.int(.Machine$integer.max, 2 * n)` call, where `n` is the
number of outer folds. Fold `i` uses element `2 * i - 1` for its tuning
step and element `2 * i` for its outer fit, each applied with the
generator kind pinned. Because a fold's seed depends on its position and
not on the order folds are executed in, the result is the same however
the loop is scheduled.

This makes any single fold reproducible by hand. Fold `i` is exactly:

    set.seed(res$.tuning_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    tuned <- tune_grid(object, resamples$inner_resamples[[i]], grid = grid,
                       metrics = metrics, control = control_grid(allow_par = FALSE))
    final <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
    set.seed(res$.outer_fit_seed[[i]], kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    last_fit(final, resamples$splits[[i]], metrics = metrics)

The caller's RNG state and generator kind are restored on exit,
including when the call errors, so a seeded script that draws afterwards
is unaffected — the same contract
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
gives. One consequence worth knowing: two consecutive calls with no
[`set.seed()`](https://rdrr.io/r/base/Random.html) between them return
identical results, exactly as repeated `tune_grid()` calls do.

This binds randomness that flows through R's generator. Engines that
randomize outside it — kernlab's SVMs, the deep-learning engines —
cannot be pinned by any R-side scheme, here or in tune.

## When a fold fails

A fold that fails does not end the run. The remaining folds still run,
and the fold that failed is recorded rather than discarded: `.completed`
is `FALSE` for it and `.notes` holds what went wrong, in the same shape
tune uses — one row naming the stage that failed (`"inner tuning"` or
`"outer fit"`), followed by tune's own notes about the underlying cause.
The number of folds attempted and the number completed are stored on the
object as the `folds_attempted` and `folds_completed` attributes.

Both stages can fail quietly. Inner tuning raises only once every
candidate has failed, and the outer fit does not raise at all — it hands
back a result with no metrics. Both are recorded as failures here.

A fold can also complete *and* carry notes. When only some of a fold's
inner resamples fail, tuning still returns a candidate and the fold
finishes, but its parameters were chosen on less of the inner design
than was asked for. Those notes are kept, so `.completed` being `TRUE`
with a non-empty `.notes` means exactly that: it worked, on less than
the whole design.

A failed fold still records the candidates it got as far as scoring,
whatever stage it failed at. A fold that died at the outer fit had
already tuned, so its `.grid` holds the full set — and so does one that
tuned successfully and then failed while selecting from the results.
Only a fold that never reached a scored candidate at all — tuning itself
raised, or every candidate failed — holds a zero-row table. No fold is
reported as having searched a grid it did not.

Subsetting rows recomputes `folds_attempted` and `folds_completed` for
the rows kept, so the counts always describe the object in hand.
Dropping the `.completed` column drops the `nested_results` class with
it.

The run warns when it finishes with any fold unfinished, and
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
warns again, summarizing only the folds that ran and reporting how many
those were. It refuses outright when no fold completed: an estimate is
never reported for a design that did not execute.

## Parallel execution

The outer folds run in parallel when you have started mirai daemons, and
serially otherwise. There is no argument for this — start daemons before
the call and the loop uses them:

    mirai::daemons(4)
    res <- nested_tune_grid(wf, folds, grid = grid)
    mirai::daemons(0)

Two or more daemons are needed before the loop dispatches; below that it
stays serial, the same threshold `tune` applies. Inner tuning always
runs serially whatever you set, because nested parallelism
oversubscribes cores.

**Results do not depend on how the loop ran.** The same seed gives the
same result serially and in parallel, at any number of daemons — each
fold's seeds are drawn up front and assigned by position, so a fold's
outcome depends on where it sits in the design and never on which worker
took it or in what order. One exception, and it carries no numbers: the
backtraces stored in `.notes` record where a fold executed, so a fold
that failed on a daemon carries that daemon's call stack rather than
yours. The note text, its location, and its type are the same either
way, though a daemon wraps long message lines to its own console width
rather than your terminal's.

**Each fold is sent one copy of the data, not one per inner split.** A
resampling split carries the whole frame it indexes, and sending a fold
to a daemon means serializing it — which does not preserve the single
shared copy the design holds in memory. Each fold's splits are therefore
emptied before dispatch and refilled on the worker, so what crosses is
the fold's row indices plus one copy of the data rather than one copy
per split. On a design built by
[`nested_resamples()`](https://jmgirard.github.io/nestedtune/reference/nested_resamples.md)
that is one copy per fold; a design from
[`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
materializes an analysis frame per outer fold, so each fold also carries
its own, still once rather than once per inner split.

Two things this does not reach, both of them objects you supply rather
than anything the package builds. A recipe keeps a copy of the data it
was created with, and a formula carries the environment it was written
in — so a workflow built inside a function that holds a large object
sends that object with every fold. Building the workflow at the top
level avoids the second.

Daemons are **separate R processes**, which has consequences worth
knowing:

- They do not inherit your session's options, your
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html) changes, or
  environment variables you set after launching them. Set what a fold
  needs with
  [`mirai::everywhere()`](https://mirai.r-lib.org/reference/everywhere.html),
  or start the daemons after setting it.

- They load nestedtune from an installed library. Running under
  `devtools::load_all()` is not enough — the daemons cannot see it, and
  the call stops rather than failing every fold with the same opaque
  note. During development, prime them with
  `mirai::everywhere(pkgload::load_all("<path>"))`.

- Before dispatching, the call asks **every** connected daemon whether
  it can load the package, and stops if any of them cannot. A pool whose
  daemons differ — one respawned, or started against a different library
  — therefore fails here, naming how many are affected, rather than as a
  run in which some folds come back as opaque worker failures.

- The same round trip asks each daemon which of this session's internal
  functions its own copy of the package defines, and stops if any are
  missing. A daemon holding an *older install* loads the package
  perfectly well and then fails every fold, because the worker resolves
  what it needs by name inside that daemon's copy. The error names the
  missing functions and asks you to reinstall and then restart the pool
  — a running daemon keeps the namespace it has already loaded, so
  reinstalling underneath one changes nothing until it is replaced.

- A daemon that does not answer at all is reported as a non-response,
  not as a missing package, so a merely slow daemon is never met with
  advice to install what you already have. The check waits 30 seconds by
  default; set `options(nestedtune.preflight_timeout = <milliseconds>)`
  to raise or lower that, to a single positive, finite number. Nothing
  statistical depends on it.

- The first parallel call after starting daemons is the slow one: the
  check is what makes every daemon load the package, and the whole
  tidymodels stack is not cheap to load. Because the check now waits for
  *all* of them rather than whichever answers first, a cold pool on a
  loaded machine can need more than the default 30 seconds — raise the
  option if you see a non-response you do not believe. Later calls in
  the same session reuse what the daemons already loaded.

- That check is bounded; the folds themselves are not. If every daemon
  dies *after* folds are dispatched, the call blocks waiting for results
  that will never arrive, and you interrupt it. No per-fold timeout is
  imposed, because no time limit is defensible for an arbitrary model
  fit — a slow fold and a dead one would be indistinguishable.

A fold whose worker dies is recorded as a failed fold, exactly like any
other failure: the run finishes, the other folds keep their results, and
`.notes` names the worker as the stage.

Stopping a run is not a fold failure. A fold that was never given a
chance to run has not been attempted, so recording it as one would
describe a design that did not execute. Stopping the dispatched tasks
therefore aborts the call and returns nothing, raising a
`nestedtune_cancelled` condition. That class inherits from
`nestedtune_interrupted`, which is what a task interrupted on its own
daemon raises, so a handler for the general case catches both and one
that cares can tell them apart. Either way the caller's RNG state is
restored on the way out.

Interrupting the call at your own console is not one of these. It
unwinds the blocking wait before any worker's return value is
classified, so an ordinary interrupt propagates and no nestedtune
condition class is attached — the RNG state is still restored, but do
not write a handler expecting one.

An interrupt also asks the folds it leaves behind to stop. However the
call is left once its folds are dispatched — an interrupt, or an error —
the outstanding ones are cancelled on the way out, so the pool goes idle
shortly after rather than computing folds whose results nobody will
read. Two limits are worth knowing. Cancelling needs mirai's dispatcher,
which `mirai::daemons(n)` starts by default; on a pool started with
`dispatcher = FALSE` the request cannot reach the workers at all and the
folds run to completion. You are told so at dispatch rather than left to
discover it: such a pool raises a warning of class
`nestedtune_pool_not_cancellable`, once per call, naming the remedy. The
pool is not refused, because its results are correct — what it lacks is
the ability to stop. And stopping is a request rather than a guarantee:
a fold already inside a compiled fitting routine may not be
interruptible, and one that has nearly finished may simply finish.

One case cannot be told apart, and is documented rather than guessed at:
calling `mirai::daemons(0)` while folds are outstanding produces exactly
the value a daemon dying mid-fold produces — same code, same classes,
nothing to separate them. Tearing the pool down that way is therefore
recorded as fold failures rather than treated as a cancellation, because
the alternative would discard every completed fold whenever a single
worker died.

## Differences from calling tune directly

Inner tuning always runs with `control_grid(allow_par = FALSE)`, forced
rather than left to chance, and there is deliberately no `control`
argument to override it. Parallelism belongs over the outer folds, as
above.

## See also

[`nested_resamples()`](https://jmgirard.github.io/nestedtune/reference/nested_resamples.md),
[`nested_final_fit()`](https://jmgirard.github.io/nestedtune/reference/nested_final_fit.md),
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)

## Examples

``` r
# \donttest{
if (rlang::is_installed(c("recipes", "yardstick"))) {
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
  collect_metrics(res)

  # What each fold chose -- disagreement here is selection instability, and
  # it is information, not noise.
  res$.selected
}
#> [[1]]
#> # A tibble: 1 × 2
#>   num_comp .config        
#>      <int> <chr>          
#> 1        2 pre2_mod0_post0
#> 
#> [[2]]
#> # A tibble: 1 × 2
#>   num_comp .config        
#>      <int> <chr>          
#> 1        1 pre1_mod0_post0
#> 
#> [[3]]
#> # A tibble: 1 × 2
#>   num_comp .config        
#>      <int> <chr>          
#> 1        1 pre1_mod0_post0
#> 
# }
```
