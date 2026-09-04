# Changelog

## nestedtune 0.0.0.9000

- The guide
  [`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md)
  is now the getting-started path alone: design, loop, what to report,
  what each fold chose, the final fit, reproducibility and the write-up.
  What the nested estimate means moved to a new page,
  [`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md):
  which quantity it estimates, why it tends to run a little pessimistic,
  what `std_err` is and is not, why two nested estimates cannot be
  subtracted to compare workflows, why the outer folds disagree, and
  when nesting is worth its cost. The new page runs no code.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
  [`nested_tune_race_anova()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md),
  [`nested_tune_race_win_loss()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
  and
  [`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md)
  refuse a `resamples` design at the call, before any fold runs, in
  three further shapes, under the same `nestedtune_bad_design` class: an
  element of some fold’s inner `splits` list that is not an `rsplit`; a
  fold whose inner splits do not all carry one frame that is the outer
  split’s own data frame (as
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  builds them) or that split’s analysis set (as
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  builds them); and an inner split carrying the outer data frame whose
  `in_id`, or non-`NA` `out_id`, holds a row index outside the outer
  split’s `in_id`. Each refusal names every offending fold, split and
  index. Before, an inner design over another frame was tuned as given
  serially and sent down a slower path in parallel, and a hand-built
  inner split indexing a row its outer fold holds out ran to completion.
  Designs from
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  and
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html),
  on a data frame or a tibble, and one whose outer `rset` repeats a row,
  pass unchanged.

- Before any fold is dispatched to mirai daemons, the startup check now
  asks every daemon for each package the workflow and the tuner need,
  and stops when one cannot load one of them, naming how many daemons
  are affected and which packages: the `nestedtune_daemons_missing_pkgs`
  refusal, or the existing `nestedtune_daemons_cannot_load` one when a
  daemon also cannot load nestedtune itself, both under
  `nestedtune_daemons_unusable`. Before, such a pool was warned about
  and then failed every fold sent to that daemon. The host’s own entry
  check widens the same way: a package the workflow needs that is not
  installed here – a recipe step’s as well as the engine’s – is refused
  at entry by every tuning driver and by
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md),
  under the `nestedtune_pkg_not_installed` class the tuner refusals
  already carry, with an
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
  call to paste.

- [`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md)
  and
  [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  on an object they have no method for – a `nested_results`, a list, a
  number – now signal the `nestedtune_no_extract_method` refusal naming
  that object whatever else was passed in `...`. Before, a stray
  argument was reported first and the object not at all.

- Three compatibility changes to the `nested_results` class. Printing
  the columnless type token
  [`vctrs::vec_cbind_frame_ptype()`](https://vctrs.r-lib.org/reference/vec_cbind_frame_ptype.html)
  hands back no longer errors, and writes the banner and the rows alone:
  neither the outer-label line nor a fold count. A column add that
  leaves two columns sharing a record column’s name –
  [`vctrs::vec_cbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
  or
  [`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html)
  with `.name_repair = "minimal"` – returns a bare tibble carrying none
  of the run’s attributes, as a repair that moves the column already
  did; two columns outside the record sharing a name leave the object as
  it is. And `names<-`, the door
  [`dplyr::rename()`](https://dplyr.tidyverse.org/reference/rename.html)
  uses, keeps the object and every attribute intact when each record
  column keeps its name, a rename that duplicates a name outside the
  record included, and returns a bare tibble when a record column is
  renamed or a column outside the record takes one’s name.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md),
  [`nested_tune_race_anova()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md),
  [`nested_tune_race_win_loss()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
  and
  [`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md)
  refuse a `resamples` design at the call, before any fold runs, in
  three new shapes: an inner `rset` with no rows; an `NA` label, or two
  outer folds carrying the same label; and a label column – any column
  beside `splits` and `inner_resamples` – that is not character or
  factor, or whose name is not `id` or `id` followed by a digit from 1
  to 9, the names rsample’s and tune’s own readers find id columns by.
  Every design refusal, the six that existed included (not a nested
  design, no outer folds, no `id` column, an outer bootstrap, a `splits`
  element that is not an `rsplit`, an `inner_resamples` element that is
  not an `rset`), now carries the condition class
  `nestedtune_bad_design`, and a refusal names every offending row or
  column rather than the first it found. Designs from
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  and
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  pass unchanged.

- On a
  [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  design, every inner tuning call now sees only its outer fold’s
  analysis rows, so a `param_info` parameter whose range tune finalizes
  from the data – `mtry()`, or a `min_n()` finalized by row count – is
  finalized without the rows that fold holds out, as it already was on
  an
  [`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  design. Before, tune read the whole data frame the design’s inner
  splits index: on a 200-row frame with five outer folds, a `min_n`
  finalized at half the row count searched candidates up to 100 where
  the fold’s 160 analysis rows give 80. The candidates such a run
  searches, and so its selections and estimate, change; a `param_info`
  with no unknown range, a data-frame `grid`, a
  [`nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
  design, and an outer split that repeats a row are unaffected, and
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  on the two designs built under one seed now returns identical
  `.inner_metrics` and `.metrics`. This applies to
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md),
  both racing functions and
  [`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md);
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  refuses an unknown range before any frame is read, as before.
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  still finalizes on the full data, which is the final model’s own
  training data. The design object does not change; a running fold holds
  one copy of its analysis set for the tuning call.

- [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  refuses a results object in which no outer fold completed, with
  condition class `nestedtune_no_completed_folds`: such a run has no
  estimate to report a model with, and the message points at
  [`summary()`](https://rdrr.io/r/base/summary.html) on the object,
  which lists the stage each fold failed at. The refusal comes after the
  three `nestedtune_bad_results` refusals and before anything is fitted
  or drawn.
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html),
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  and
  [`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md)
  already refused the same object; their error now carries the same
  class, so the fact is catchable one way at every door. A run in which
  some folds failed is fitted as before.

- [`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md)
  runs the outer loop of nested cross-validation with finetune’s
  simulated annealing inside: each outer fold scores `initial`
  space-filling candidates on its inner resamples, then for `iter`
  iterations perturbs the current candidate and keeps or discards the
  result by finetune’s annealing rule. It is
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)’s
  sibling: the same arguments less `objective`, `initial` defaulting to
  1 (finetune’s default; at least 1 rather than the Bayesian sibling’s
  2), and a
  [`finetune::control_sim_anneal()`](https://finetune.tidymodels.org/reference/control_sim_anneal.html)
  through `...` as `control`. Each fold’s `.inner_metrics` carries
  `.iter`, `0` on the initial candidates. Refused at entry, before any
  fold runs: finetune not installed (`nestedtune_pkg_not_installed`);
  `iter` below 1 (`nestedtune_bad_iter`) – finetune 1.3.0 runs two
  iterations at `iter = 0`, not none, so the 0 the Bayesian sibling
  accepts is refused here; `initial` below 1 or a `tune_results`
  (`nestedtune_bad_initial`); a control that is not a
  `control_sim_anneal()` (`nestedtune_bad_control`).
  `control_sim_anneal()` defaults `verbose_iter` to `TRUE`, which prints
  finetune’s annealing log from every fold of a serial run; pass
  `control = control_sim_anneal(verbose_iter = FALSE)` for a quiet run.
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  on an annealing result runs the search again on the full data and
  prints the initial and iteration counts that ran beside the ones
  requested, as it does for a Bayesian result
  ([\#35](https://github.com/tidymodels/nestedtune/issues/35)).

- [`nested_tune_race_anova()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
  and
  [`nested_tune_race_win_loss()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
  run the outer loop of nested cross-validation with finetune’s two
  racing tuners inside: each outer fold scores every candidate in `grid`
  on `burn_in` inner resamples (shuffled first under `control_race()`’s
  default `randomize = TRUE`), drops the candidates already clearly
  worse than the best, and scores the survivors on the rest. They take
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)’s
  arguments, and a
  [`finetune::control_race()`](https://finetune.tidymodels.org/reference/control_race.html)
  through `...` as `control`. Each fold’s `.inner_metrics` holds every
  candidate its race scored, eliminated candidates included
  (`tune::collect_metrics(<race>, all_configs = TRUE)`), with `n` the
  number of inner resamples each was scored on; `attr(x, "grid")` and
  the `procedure` record hold the grid as offered. Refused at entry,
  before any fold runs: finetune not installed, lme4 (for the ANOVA
  race) or BradleyTerry2 (for the win/loss race) not installed
  (`nestedtune_pkg_not_installed`); a control that is not a
  `control_race()` (`nestedtune_bad_control`); and an inner design in
  any outer fold with no more resamples than the control’s `burn_in`
  (`nestedtune_bad_burn_in`) – `control_race()` defaults `burn_in` to 3,
  so a design with three inner resamples needs
  `control = control_race(burn_in = 2)`.
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  on a racing result races the recorded grid again on the full data, and
  [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  on that fit lists every candidate the race scored. finetune, lme4 and
  BradleyTerry2 join Suggests
  ([\#35](https://github.com/tidymodels/nestedtune/issues/35)).

- Breaking: each outer fold of a `nested_results` now carries its inner
  tuning run’s metrics as `.inner_metrics` –
  [`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  of that fold’s run, one row per candidate and metric with `.metric`,
  `.estimator`, `mean`, `n`, `std_err` and `.config`, plus `.iter` from
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  – in place of the `.grid` column, which held the candidates alone. The
  candidates a fold searched are the table’s distinct parameter rows, so
  nothing `.grid` recorded is lost, and a Bayesian search’s trajectory
  or a fold’s best candidate can now be computed from the object. A fold
  that tuned and then failed its outer fit keeps its table; a fold that
  scored nothing carries a zero-row table under a completed fold’s
  columns. The column is part of the record the dplyr and vctrs
  invariants check, as `.grid` was. `.selected` is unchanged.
  [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  on a `nested_final_fit` keeps its candidate columns and `.config`, and
  no longer carries `.eval_time` on a fit that scored a dynamic survival
  metric – the column held one arbitrary evaluation time per candidate;
  the times are in `collect_metrics(extract_tune_results(x))`
  ([\#57](https://github.com/tidymodels/nestedtune/issues/57)).

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  now take a control object through `...` –
  `control = tune::control_grid(...)` on the first,
  `control = tune::control_bayes(...)` on the second – and pass it to
  the inner tuning call in every fold;
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  re-runs under the control the result recorded,
  `attr(res, "procedure")$control`. The slots this package forces are
  overwritten rather than refused: `allow_par` is `FALSE`, and the
  Bayesian `seed` is each fold’s tuning seed, so a control setting
  either yields the run the default gives. `event_level` stays an
  argument, and a control naming a level that is neither tune’s default
  nor the argument’s is refused at entry, as is a control that is not
  what the matching `tune::control_*()` returns (condition class
  `nestedtune_bad_control`) and any other name or an unnamed value in
  `...` (`nestedtune_bad_dots`). `no_improve`, `uncertain` and
  `time_limit` reach
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  this way. Each help page now classifies every slot of its control
  object under one of six headings: forced, settable as its own
  argument, refused, passed through, not returned, inert
  ([\#33](https://github.com/tidymodels/nestedtune/issues/33),
  [\#35](https://github.com/tidymodels/nestedtune/issues/35)).

- Breaking:
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  now takes the `nested_results` object in place of the design and the
  procedure – `nested_final_fit(object, results)` – and re-runs the
  procedure that result recorded: the design’s inner resampling
  specification, now carried on every `nested_results` as its `inside`
  attribute, the tuner and its arguments from the `procedure` attribute,
  the metric set, and the data every split references. The former
  `grid`, `param_info`, `metrics`, `event_level` and `eval_time`
  arguments are gone, so the model and the estimate you report for it
  come from one search by construction; a Bayesian result re-runs
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  with its Gaussian process seeded from the fit’s tuning seed, exactly
  as each outer fold was. A results object with no such record (built by
  an earlier version, or from a design assembled by hand), one that is
  no longer a `nested_results` (an operation that changed the rows
  returns a plain tibble), or one with no rows is refused before any
  fitting, with condition class `nestedtune_bad_results`. Not migrated.

- [`predict()`](https://rdrr.io/r/stats/predict.html) and
  [`augment()`](https://generics.r-lib.org/reference/augment.html) now
  work directly on a `nested_final_fit`, returning what the same call on
  `extract_workflow(final)` returns; the
  [`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)
  route still works. `augment` is re-exported so the call needs no other
  package attached. [`predict()`](https://rdrr.io/r/stats/predict.html)
  passes further arguments (`level`, `eval_time`, …) through to the
  model, where parsnip refuses a name it does not recognise;
  [`augment()`](https://generics.r-lib.org/reference/augment.html) takes
  `new_data` and `eval_time` only and refuses anything else, where
  workflows’ own method would let it vanish. The help page says what
  residuals on the training rows are not.

- [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) on a
  `nested_final_fit` name the procedure that ran: the candidates scored
  for a grid search; for a Bayesian search the initial candidates and
  iterations, each as what ran beside what was requested. The summary
  carries those counts as components, `NULL` on a grid fit, and a
  `tuner` component; the printed pointer to the estimate now names the
  results object the fit was built from rather than one orchestrator.
  The object gains a `procedure` element, and
  [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  on a Bayesian final fit carries `.iter`.

- [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  runs the outer loop of nested cross-validation with
  [`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
  as the inner tuner. On each outer fold it scores `initial`
  space-filling candidates on the fold’s inner resamples, lets a
  Gaussian process propose up to `iter` more under `objective`, selects
  the best, and fits and scores the outer split – what
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  does around
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  through the same loop, so the seed contract, the parallel path, the
  results object and its methods are shared. Two rules are its own. The
  Gaussian process is seeded from the fold’s tuning seed, so a fold
  reproduces from its `.tuning_seed` alone, and `iter = 0` gives the
  numbers
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  gives on the same space-filling grid. And `initial` is a count only: a
  `tune_results` object, which tune accepts there, is refused, since one
  tuning run cannot serve every outer fold. `iter`, `initial` and
  `objective` are refused at entry, each with its own condition class,
  unless a single non-negative whole number, a single whole number of at
  least 2, and an acquisition function.

- Each fold’s `.grid` from
  [`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
  carries an `.iter` column naming the search iteration each candidate
  was proposed in, `0` for the initial candidates. The
  candidates-searched line
  [`print()`](https://rdrr.io/r/base/print.html) shows and the candidate
  counts [`summary()`](https://rdrr.io/r/base/summary.html) holds count
  those rows.

- Every `nested_results`, from either orchestrator, carries a
  `procedure` attribute: a named list of the tuner that ran
  (`"tune_grid"` or `"tune_bayes"`), its own arguments (`grid`, or
  `iter`, `initial` and `objective`), and `param_info`, `event_level`
  and `eval_time`. It travels with the class through the dplyr and vctrs
  doors and is shed with it. A Bayesian result has no `grid` attribute.
  The `grid` and `metrics` attributes of a grid result are as they were.

- [`agreement()`](https://nestedtune.tidymodels.org/reference/agreement.md)
  reports how often each candidate was selected across the outer folds
  of a `nested_results`: one row per distinct combination of selected
  parameter values, with `n`, the number of completed outer folds that
  chose it, and `prop`, that count over the completed fold count, most
  frequent first. A fold with no recorded value for a parameter is
  counted under `NA`, and a partial run is tabulated over the folds that
  completed, with a warning saying so. The most frequent combination is
  not the final model’s parameters;
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  selects those for itself.

- [`print()`](https://rdrr.io/r/base/print.html) on a `nested_results`
  accepts `n` and `width` and passes them to the rendering of the
  outer-fold rows, so `print(res, n = Inf)` shows every fold of a run of
  more than twenty and `print(res, width = 40)` narrows the table. Both
  are matched by full name only; any other argument is still refused.
  Previously `print(res, n = 25)` was an error.

- The failure advice a `nested_results` summary prints now names the
  results object’s `.notes` column. Previously it read `x$.notes`, and
  `x` inside the summary’s print method is the summary itself, which has
  no such column.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  and
  [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  gain an `eval_time` argument, passed on to every `tune` call whose
  answer depends on it, so a censored regression workflow scored by a
  dynamic or integrated survival metric is measured at the times you
  name rather than at whatever tune picks. It is refused ahead of tune
  when it is not numeric, is empty, or has an element that is missing,
  negative or not finite; zero, repeated times and times out of order
  are passed on untouched for tune to normalize. A metric measured at
  several evaluation times is summarized per time by
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  and [`summary()`](https://rdrr.io/r/base/summary.html), each row
  naming its time in a `.eval_time` column, and drawn one panel per time
  by `autoplot(type = "performance")`, so estimates at different times
  are never averaged together; a run scored by no survival metric keeps
  the columns it had. Previously neither function took the argument and
  neither could reach it.

- [`summary()`](https://rdrr.io/r/base/summary.html) on a
  `nested_final_fit` returns a `summary.nested_final_fit` object holding
  the full-data tuning run’s resampling scheme, the number of candidates
  that run scored, the parameter values selection chose, and an
  `estimate` component that is always `NULL` — so a caller can reach a
  value without re-deriving it from the fit. Printing it reports those
  under headings and says, where the number would be, that this model
  has no performance estimate of its own and that the nested estimate is
  the one to report. Previously
  [`summary()`](https://rdrr.io/r/base/summary.html) on a final fit fell
  through to the default method and printed a table of the object’s five
  internal components. [`print()`](https://rdrr.io/r/base/print.html) on
  a final fit is unchanged.

- Breaking: printing a `nested_results` now shows the object — its outer
  folds as the tibble rows they are, the resampling scheme it came from,
  a count of the folds that did not complete, and a note when the folds
  did not all search the same grid. Everything else printing used to
  report has moved behind
  [`summary()`](https://rdrr.io/r/base/summary.html): which folds failed
  and at which stage, what each fold’s inner tuning selected, the
  estimate across the folds that completed, and the sentence saying a
  nested estimate describes the procedure rather than a model you can
  deploy. Previously [`print()`](https://rdrr.io/r/base/print.html)
  reported all of that and never showed a single row of the object.

- [`summary()`](https://rdrr.io/r/base/summary.html) on a
  `nested_results` returns a `summary.nested_results` object holding the
  requested and completed fold counts, the failed folds with the stage
  each failed at, the values the completed folds selected for each tuned
  parameter, and the metric estimates averaged across them — so a caller
  can reach a number without re-deriving it from the columns.
  Summarizing a run that only partly completed warns and still returns
  the summary; summarizing one where every fold failed does the same,
  where
  [`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  refuses outright.

- A `nested_results` whose record of its fold-label columns cannot label
  its rows — because the record is empty, or names a column the object
  no longer carries — now names each fold by its row position.
  Previously the first two cases made printing raise, and a record
  naming several columns of which some were absent produced a truncated
  label such as `Fold1,`.

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
