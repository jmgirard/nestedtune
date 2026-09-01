# Changelog

## nestedtune 0.0.0.9000

- Breaking: an operation that changes which outer folds a
  `nested_results` holds now returns a plain tibble instead of a
  `nested_results`. `slice()`,
  [`head()`](https://rdrr.io/r/utils/head.html), `x[1, ]`, `x[-1, ]`, a
  [`filter()`](https://rdrr.io/r/stats/filter.html) that drops a failed
  fold and `bind_rows()` all take this branch, and so does dropping any
  of the columns the run is recorded in. Previously `dplyr::slice(x, 1)`
  returned a one-row object still headed
  `Outer resamples: 3-fold cross-validation` and still reporting three
  outer folds attempted, and `x[1, ]` returned a one-row object that
  went on claiming to be a results object.

  Operations that leave the set of folds alone keep the class and the
  run’s record: reordering rows with `arrange()`, adding a column with
  `mutate()` or `bind_cols()`, reordering columns with `relocate()`, and
  a `left_join()` that matches one row apiece. These are the invariants
  `tune` declares on its own results objects.

- Breaking: the same rule now covers the vctrs verbs and base
  [`rbind()`](https://rdrr.io/r/base/cbind.html).
  `vctrs::vec_slice(x, 1)`, `vctrs::vec_rbind(x, x)`,
  `vctrs::vec_c(x, x)` and `rbind(x, x)` each return a plain tibble.
  Previously all four handed back an object still carrying the class and
  still reporting the fold counts of the object it was built from —
  `rbind(x, x)` gave six rows still headed as a 3-fold run. Reordering
  rows with `vctrs::vec_slice(x, c(2, 1, 3))` keeps the class, and so
  does adding a column with
  [`vctrs::vec_cbind()`](https://vctrs.r-lib.org/reference/vec_bind.html),
  which now answers exactly as
  [`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html)
  does. Both build on the first argument’s type, so
  `vec_cbind(x, extra)` and `bind_cols(x, extra)` keep the class while
  `vec_cbind(extra, x)` and `bind_cols(extra, x)` return plain tibbles
  holding the same columns.
  [`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
  and [`vctrs::vec_c()`](https://vctrs.r-lib.org/reference/vec_c.html)
  return a plain tibble even when given one argument and nothing to
  combine it with, where `dplyr::bind_rows(x)` keeps the class.

- Breaking:
  [`dplyr::rename()`](https://dplyr.tidyverse.org/reference/rename.html)
  moving one of the columns the run is recorded in now returns a plain
  tibble. Previously it returned a `nested_results` that no longer had
  that column: `rename()` renames through `names<-`, which reaches
  neither dplyr’s reconstruction nor vctrs’.

- `vctrs` is now a hard dependency. It was already installed alongside
  nestedtune, since `dplyr` requires it.

- `dplyr` is now a hard dependency. It was already installed alongside
  nestedtune, since `tune` requires it.

- Fixed fold labels in `collect_metrics(summarize = FALSE)` and in the
  partial-run warning, and the rule that decides whether an operation
  keeps the `nested_results` class. Both worked out an object’s
  fold-label columns from its column names, so a column you added was
  treated as one of the design’s whenever its name looked like one.
  Adding `id_extra` reported the folds as `Fold1, x` rather than
  `Fold1`; adding `id2` to a result from a plain v-fold design and then
  removing it again returned a plain tibble, where the same round trip
  on `extra` did not; and adding a list column named `id0` to a result
  from a repeated design failed with
  `unimplemented type 'list' in 'listgreater'`. A results object now
  records the columns its resampling design labelled the folds with, so
  a column you add is read as a fold label only when the design itself
  carries a column of that name.

- Fixed an error from replacing a fold-label column with a value that
  cannot be ordered. `dplyr::mutate(x, id = list(c(1, 2), 3, 4))` failed
  with `unimplemented type 'list' in 'orderVector1'`, raised from inside
  the rule and naming nothing the caller had done. It returns a plain
  tibble now, which is what replacing a column the run is recorded in
  has always meant.

- Fixed a failure where every outer fold errored under parallel
  processing if the workflow’s recipe used unqualified selectors such as
  `all_numeric_predictors()`. The packages a workflow declares are now
  attached inside each `mirai` daemon before any fold is dispatched, so
  a selector that resolves from your own attached packages resolves on a
  worker too. The same call ran without error when no daemons were
  running, which is what made the failure look like a parallel-only
  quirk.

- Breaking:
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  and
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  now take `...` immediately after their required arguments, so `grid`,
  `metrics` and `param_info` must be named. A call that passed them by
  position needs updating, and so does one that abbreviated a name: R
  does not partial-match an argument that follows `...`, so `metrics`
  can no longer be written `met`. In exchange, a mistyped or unsupported
  argument is now an error naming the function it was passed to, instead
  of being ignored. Every method the package registers whose `...` is
  documented as unused refuses an argument the same way.

- Breaking:
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  on a `nested_results` object takes `summarize` after `...`, matching
  tune’s own method, so it must be named.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  gain `param_info`, passed unchanged to
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
  — on every outer fold and on the parallel path as well as the serial
  one. Restricting a parameter’s range restricts the grid every fold
  searches. A `param_info` that is not a
  [`dials::parameters()`](https://dials.tidymodels.org/reference/parameters.html)
  object is refused before the first fold is fitted.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  gain `event_level`, naming which level of a two-class outcome factor
  counts as the event. It reaches the inner tuning run on both
  functions, and on
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  the outer scoring fit as well, which the package sent no settings to
  before — so a reported `sens` or `spec` was computed against the first
  level whatever the inner run had been told. Metrics that do not
  distinguish the two levels, such as `roc_auc` and `accuracy`, are
  unaffected. A value that is not `"first"` or `"second"` is refused
  before the first fold is fitted.

- The documentation site now builds with the tidymodels organization’s
  shared pkgdown theme, and the organization’s contributing guide and
  code of conduct have joined the repository and build as pages of the
  site. The README says on its face that the interface is experimental.

- The package has moved to the tidymodels organization. It now lives at
  <https://github.com/tidymodels/nestedtune>, its documentation site is
  served at <https://nestedtune.tidymodels.org/>, and `DESCRIPTION`, the
  README badges and the installation instructions name those addresses.
  The old repository address redirects to the new one; the old
  documentation address does not, so a bookmark of the site needs
  updating.

- The documentation now names the quantity a nested run estimates,
  instead of describing it.
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  estimates the k-fold test error of the whole tune-and-fit procedure on
  the analysis sets the outer folds drew — which is neither the risk of
  the model you deploy nor the same quantity averaged over datasets, and
  the help page and the guide both say so.

- [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  help now explains why its `std_err` column is not a confidence
  interval and why no interval is offered: outer fold scores share most
  of their training rows, so a standard error computed as though they
  were independent can misstate the uncertainty, typically downward, and
  there is no universally unbiased replacement to substitute. Published
  measurements of what that costs are cited.

- The nested cross-validation guide gains sources for its claim that the
  estimate runs slightly pessimistic, a warning against reading a gap
  between two nested estimates as a result, an explanation of why folds
  disagreeing about a parameter is expected rather than alarming, and a
  new section on when nesting is worth its cost and when it is not.

- A parallel run now refuses to start when a worker is holding an older
  install of nestedtune, instead of failing every fold with an opaque
  error. Workers are separate R processes, and the outer loop reaches
  into each one’s own copy of the package by name — so a worker whose
  copy predates a function the loop needs loads the package quite
  happily and then dies on every fold. The startup check now asks each
  worker which of this session’s internal functions its copy is missing,
  and the error names them, along with the fix: reinstall, then restart
  the pool. The restart matters — a running worker keeps the version it
  has already loaded, so reinstalling underneath one changes nothing.

- A parallel run started on a worker pool that cannot be cancelled now
  says so, once, at the start of the run. `mirai::daemons(n)` gives you
  a pool that stops when you interrupt;
  `mirai::daemons(n, dispatcher = FALSE)` gives you one that does not,
  and the two are indistinguishable from the outside. On the second
  kind, interrupting a run hands you back your prompt while the outer
  folds carry on computing results nobody will read. Previously only the
  documentation mentioned this. The pool is not refused — its results
  are correct, and only the ability to stop it is missing — so this is a
  warning, of class `nestedtune_pool_not_cancellable`.

- Running the outer folds in parallel now sends each fold one copy of
  your data instead of one copy per inner resample. A split carries the
  whole frame it indexes, and sending a fold to a worker serializes it,
  which does not preserve the single shared copy the design holds in
  memory — so a design with five inner resamples was putting six copies
  of the data on the wire for every outer fold. The splits are now
  emptied before dispatch and refilled on the worker. On a five-fold
  design over a 5,000-row frame this took a run from 25.7 MB to 4.7 MB.
  Results are unchanged: the objects each fold receives are identical to
  the ones a serial run passes, and the serial path is untouched.

- The object
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  returns now has two named accessors for the tuning run behind it.
  [`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md)
  returns that run — the record of what parameter selection actually saw
  when the procedure was re-run on your whole dataset — and
  [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  returns the candidate settings it scored, in the same shape as the
  per-fold `.grid` tables on a
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  result, so the two can be compared directly. Both were reachable
  before only by reaching into the object’s internals. Note what the
  first one’s numbers are worth: every metric inside that tuning run was
  computed on the resamples that chose the candidate it describes, so it
  flatters this model and is not its performance. The nested estimate
  from
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  on the
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  result remains the number to report. Handing either accessor an object
  it cannot answer for — a
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  result, say — now produces an error saying so, rather than R’s bare
  “no applicable method”.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  results now record which parameter candidates each outer fold actually
  searched, in a new `.grid` column holding one table per fold. Until
  now the object recorded only the grid you *asked* for, and the two are
  routinely different: a grid size is expanded by tune and can reach
  fewer candidates than you requested — asking for 20 on a parameter
  with four reachable values searches four — and a candidate that fails
  scores nothing. Folds can also differ from each other, because
  expanding a size draws from the random number generator and each fold
  is seeded separately, so tuning a continuous parameter with
  `grid = 10` leaves every fold searching its own candidates. Printing a
  result now says so when it happens, reporting each fold’s candidate
  count, which matters when you are reading the per-fold selections:
  folds that disagree may not have been choosing from the same set. A
  fold that failed keeps whatever it managed to score, and one that
  scored nothing carries an empty table. A candidate that failed on
  every inner resample is absent from `.grid` and recorded in `.notes`
  instead — tune keeps no other record of it.

- The object
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  returns now documents the two attributes it has always carried.
  `attr(x, "grid")` and `attr(x, "metrics")` record what the run was
  asked to do: `grid` holds the argument as you gave it, so it is a grid
  size rather than a table of candidates whenever you passed a size, and
  it is not a record of which candidates were evaluated; `metrics` is
  absent rather than `NULL` when you passed no metric set. Subsetting
  rows leaves both unchanged.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  now refuse a malformed design before fitting anything, naming the
  column and the position of the first offending element. A design whose
  `splits` or `inner_resamples` column held something other than a split
  or a resampling object used to cost a full run and come back reporting
  that every outer fold had failed — or, on
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
  fail with a message from base R that named nothing you wrote.
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds such a design without complaint when its `inside` argument
  produces no `rset`, which is the usual way to arrive at one. A design
  either function refuses, both refuse.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  now also refuse a workflow that has a model but no preprocessor,
  pointing at
  [`workflows::add_formula()`](https://workflows.tidymodels.org/reference/add_formula.html),
  [`add_recipe()`](https://workflows.tidymodels.org/reference/add_recipe.html),
  and
  [`add_variables()`](https://workflows.tidymodels.org/reference/add_variables.html).
  This is the counterpart of the no-model refusal below, and it used to
  fail once per outer fold with an error raised inside `workflows`.

- When
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  cannot re-run a design’s stored inner specification, the error now
  names your call rather than an internal function of the package.

- [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  now refuses an `inside` specification that does not produce an `rset`.
  Passing one used to build a design anyway: its `inner_resamples`
  column held whatever the specification returned, nothing complained,
  and the first sign of trouble was an error from deep inside R the next
  time the design was printed or used.

- When a resampling specification fails to evaluate, the error now names
  the specification that was tried instead of deparsing your data into
  the message. Both `outside` and `inside` had the data frame written
  into the call being evaluated, so a failure on a small 30×2 frame
  already produced around 1,200 characters that were mostly your own
  numbers, growing from there — long enough to bury the actual problem.
  Such a failure is now also wrapped in a nestedtune error carrying the
  original as its cause, so code matching on the underlying package’s
  condition class or on the whole message string sees a different
  condition than before.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  now say for themselves that a workflow has no model in it, and point
  at
  [`workflows::add_model()`](https://workflows.tidymodels.org/reference/add_model.html).
  A workflow carrying only a preprocessor — the easiest one to build by
  accident — used to fail with an error raised inside `workflows`,
  naming a call you never wrote, while every other bad `object` named
  yours. An entirely empty workflow is refused the same way and says
  which of the two it is.

- The documentation website now actually publishes. The job that pushes
  the built site had no copy of the repository to work in, so the first
  build to reach the default branch failed at the publishing step and no
  site was ever served.

- The reference pages and
  [`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md)
  are now built into a documentation website, rebuilt whenever a change
  lands on the default branch that the package itself can see.
  `DESCRIPTION` and the README have pointed at a documentation site
  since the guide was added; it goes live once GitHub Pages is switched
  on for the repository.

- Interrupting a parallel run now asks the folds it had already sent to
  the workers to stop. Before, the interrupt gave you your prompt back
  but left those folds computing — work whose results nobody would ever
  read, on the very pool you were about to reuse, until it finished on
  its own. However the call is left once its folds are dispatched, the
  outstanding ones are now cancelled on the way out and the pool goes
  idle shortly after. Two limits: cancelling needs mirai’s dispatcher,
  which `mirai::daemons(n)` starts by default and
  `mirai::daemons(n, dispatcher = FALSE)` does not, so on such a pool
  the folds still run to completion; and a fold already inside a
  compiled fitting routine may not be interruptible.

- The check that runs before parallel dispatch now asks every connected
  daemon whether it can load the package, instead of asking one and
  believing it for all of them. In a pool whose daemons differ — one
  respawned, or started against a different library — a single loadable
  daemon used to pass the check for the whole pool, and every fold that
  ran elsewhere came back as an opaque worker failure. The check now
  names how many daemons are affected and stops.

- A daemon that does not answer that check is now reported as a
  non-response rather than as one that cannot load the package, so a
  merely slow daemon is no longer met with advice to install what you
  already have. The two failures raise `nestedtune_daemons_cannot_load`
  and `nestedtune_daemons_no_response`; both also carry
  `nestedtune_daemons_unusable`, so a handler that only cares that the
  check failed can catch either, and code already handling the former
  keeps working unchanged.

- The wait for that check, previously fixed at 30 seconds, is now
  settable with
  `options(nestedtune.preflight_timeout = <milliseconds>)`. The default
  is unchanged, and no statistical result depends on it. It must be a
  single positive, finite number — an unbounded wait would restore the
  hang the bound exists to turn into an error.

- One consequence worth knowing: because the check now waits for every
  daemon rather than whichever answers first, the first parallel call
  after starting a cold pool is the slow one — it is what makes each
  daemon load the package, and on a loaded machine that can exceed the
  default 30 seconds. Raise the option if you meet a non-response you do
  not believe. Later calls in the same session reuse what the daemons
  already loaded.

- Cancelling a parallel run now stops it, instead of returning an
  estimate over whatever had finished. Previously the tasks that were
  stopped before they ran came back looking like folds that had been
  attempted and failed, so the run completed and reported a number for a
  design that never executed. It now raises a `nestedtune_cancelled`
  condition and returns nothing, with your RNG state restored. That
  condition inherits from `nestedtune_interrupted`, so code already
  handling a stopped run keeps working unchanged.

- One case is deliberately left as it was, and is now documented:
  calling `mirai::daemons(0)` while folds are still outstanding produces
  exactly what a worker dying mid-fold produces, with nothing to tell
  the two apart. It stays recorded as fold failures, because treating it
  as a cancellation would throw away every completed fold whenever a
  single worker died.

- [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  now draws a nested cross-validation result. Its default view puts one
  point per outer fold at the value that fold’s inner tuning selected,
  one panel per tuned parameter: a flat row means the folds agreed, and
  scatter means they disagreed and the value your deployed model carries
  was largely arbitrary. Printing has said this in words since the last
  release; now you can see it.

- `autoplot(x, type = "performance")` draws each outer fold’s score with
  a dashed line at the nested estimate. That line is the number
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  reports, read from the same place rather than recomputed, so the
  figure and the summary cannot disagree. Its subtitle says the estimate
  describes the tune-and-fit procedure rather than a model you can
  deploy, so the caveat travels with a figure exported into a slide or a
  paper.

- Both views keep every outer fold that was *attempted* on the axis. A
  fold that failed, or one that completed without recording a value for
  a parameter, leaves a visible gap rather than being quietly dropped or
  drawn at an invented value.

- The subtitle says how much of the requested design ran, and each panel
  says when fewer folds contributed to it than completed —
  `mtry (2 of 3 chose)`, `rmse (from 2 folds)`. Counting per panel
  rather than per figure is what keeps the claim true: a parameter only
  some folds chose a value for would otherwise read as unanimity, and a
  metric one fold could not score would read as an estimate from more
  folds than it had. A metric no completed fold could score keeps an
  empty panel rather than vanishing from the figure.

- `ggplot2` is now a hard dependency. Plotting a run where no outer fold
  completed, or asking for the parameters view of a design with no tuned
  parameters, is refused with a message saying which it was.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  now runs its outer folds in parallel. Start workers with
  `mirai::daemons(n)` before the call and the loop uses them; there is
  no argument to set, and no daemons means the serial behaviour is
  unchanged. Inner tuning still runs serially, because nesting
  parallelism inside parallelism oversubscribes cores.

- Parallel results are identical to serial ones. The same seed gives the
  same answer at any number of workers, because each fold’s seeds are
  drawn before the loop starts and assigned by position — a fold’s
  result depends on where it sits in the design, never on which worker
  ran it. A fold whose worker dies is recorded as a failed fold like any
  other, and the run finishes.

- [`?nested_tune_grid`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  gains a “Parallel execution” section covering what workers do and do
  not inherit from your session, and why the package must be installed
  where they can load it.

- A new guide,
  [`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md),
  runs the whole path — build a nested design, run the loop, read what
  each fold selected, fit the model to deploy — as code you can run, and
  says plainly what to report for that model and why. It puts the nested
  estimate next to the selection-time score users are most tempted to
  report, and closes with a worked write-up. Every number in its prose
  is produced when the vignette is built, so a claim that stops being
  true fails the check rather than ageing quietly.

- New
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  builds the model you actually deploy. It runs the same tuning
  procedure the nested estimate describes, this time with the whole
  dataset in hand: it re-evaluates the design’s inner resampling
  specification against every row, tunes, selects, and fits. Reach the
  trained workflow with
  [`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html).

- The final model is a separate object rather than a field on the
  results, and it carries no performance number of its own. Report the
  estimate from
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  on the
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  result for it — the documentation says why, and what that number does
  and does not claim.
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
  `show_best()`, and `select_best()` deliberately refuse a final fit
  rather than returning something that reads as its score.

- Because the inner resampling specification is stored unevaluated and
  re-evaluated at final-fit time, write it with literal arguments —
  `inside = vfold_cv(v = 5)`, not `inside = vfold_cv(v = k)`. A
  specification whose variables have gone out of scope now fails with a
  message naming it.

- Nested results now print as a report on the run rather than as a table
  of list columns. It names the outer resampling scheme, says how many
  folds were requested and how many completed, names any fold that
  failed along with the stage it failed at, and gives the estimate
  across the folds that contributed.

- Printing shows what each outer fold’s inner tuning selected, marking
  whether the folds agreed on a parameter or disagreed about it and,
  when they disagreed, listing every fold’s choice. Disagreement means
  the tuning procedure is unstable on this data, which averaging the
  metrics would hide.

- Printing also states plainly that the estimate describes the
  tune-and-fit procedure rather than a model you can deploy — the caveat
  now travels with the number instead of living only in the
  documentation.

- Printing never warns and never errors, including for a run where no
  outer fold completed at all.
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  still does both: asking for a summary of a design that did not run
  deserves a condition, while describing an object does not.

- An outer fold that fails no longer ends the run. The remaining folds
  still run, and the failed one is recorded rather than thrown away:
  `.completed` marks it, and `.notes` says which stage failed and why,
  carrying tune’s own notes about the underlying cause. This matters
  because both stages can fail quietly — inner tuning only raises once
  every candidate has failed, and the outer fit does not raise at all.

- A fold that completes on only part of its inner design now keeps the
  notes explaining what was lost. `.completed` being `TRUE` alongside a
  non-empty `.notes` means the fold worked, but chose its parameters on
  less of the inner design than was requested.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  now checks a data-frame `grid` against the workflow before fitting
  anything: a column that is not marked for tuning, or a tuned parameter
  with no column, is refused immediately and by name. Either mistake is
  wrong for every fold rather than for one, so it is reported as what it
  is — an error in the call — instead of as an entire design failing.

- [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  now summarizes only the outer folds that completed, warns naming the
  ones that did not, and errors rather than returning `NA` when none
  completed. An estimate is never reported as though it came from a
  design that did not run.

- Added
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  which runs the nested cross-validation loop end to end. For each outer
  fold it tunes on that fold’s inner resamples with
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  selects the best candidate, finalizes the workflow, and fits and
  scores it on the outer split. The result keeps each fold’s chosen
  parameters alongside its metrics, so disagreement between folds —
  selection instability — is visible rather than averaged away.

- Added a
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  method for those results, returning either the per-fold metrics or
  their summary across outer folds.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  is reproducible from a single
  [`set.seed()`](https://rdrr.io/r/base/Random.html) before the call. It
  derives one tuning seed and one outer-fit seed per fold up front, so a
  fold’s result depends on its position in the design rather than on the
  order folds happen to run in, and it leaves the caller’s random-number
  state exactly as it found it.

- Added
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md),
  a constructor for nested resampling designs that does not keep a copy
  of the data for every outer fold. For the same seed and the same
  specifications it selects the same rows as
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html):
  [`analysis()`](https://rsample.tidymodels.org/reference/as.data.frame.rsplit.html)
  and
  [`assessment()`](https://rsample.tidymodels.org/reference/as.data.frame.rsplit.html)
  return identical frames, and each inner split carries the same class
  and resample id. On a 20000-row dataset with a five-fold inner
  resampling, a 50-fold outer design holds 10× the source data rather
  than 57×.

- [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  refuses an outer bootstrap rather than warning about it. The same
  observation can otherwise land in both the inner analysis and the
  inner assessment set, which makes the design invalid rather than
  unusual.
