# RB05: The final fit re-running a recorded procedure — its Bayesian oracle, its print, its refusals (M46)

- **Date:** 2026-09-02
- **Output required:** write findings to `cairn/reviews/RR05-final-fit-recorded-procedure.md`
- **Binding criteria:** not requested

You are performing an independent expert review. This brief is fully
self-contained — do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

nestedtune is an R package that orchestrates the outer loop of nested
cross-validation for the tidymodels ecosystem and delegates inner tuning to
`tune`. Two orchestrators exist: `nested_tune_grid()` (around
`tune::tune_grid()`) and, since M45, `nested_tune_bayes()` (around
`tune::tune_bayes()`). Both run one shared loop, told which tuner to call by a
*tuner description* (`R/tuner.R`), and both return a `nested_results` tibble,
one row per outer fold, carrying a `procedure` attribute that records the
tuner that ran, its own arguments, and `param_info`, `event_level` and
`eval_time`.

The package's inviolable principle IP3 says the nested estimate describes the
tune-and-fit *procedure*, never the shipped model. The final model therefore
comes from a separate function, `nested_final_fit()`, which re-runs that
procedure once more with every row in hand: set a tuning seed, re-evaluate the
design's stored inner resampling specification (`attr(design, "inside")`, an
unevaluated call) against the full data, tune, select, finalize, set a fit
seed, fit. It returns a `nested_final_fit` object: the trained workflow, the
selected parameters, the tuning run selection came from (`x$tuning`, reached
by `extract_tune_results()`), and the two seeds. The tuning run is kept as the
record of what selection saw; its metrics are selection-time quantities and
nothing in the package turns them into a performance claim (RR02 Q7).

Until now the signature was `nested_final_fit(object, resamples, grid, metrics,
...)`, mirroring `nested_tune_grid()`, so the user restated the procedure. With
a second orchestrator that restatement would need a method switch and every
setting of both, and nothing would stop a user handing the final fit a
procedure other than the one their estimate describes. D-041 (2026-09-01)
therefore fixed the new shape: `nested_final_fit(object, results, ...)`, where
`results` is the `nested_results`; the inner specification, the data and the
procedure are read from it. M46 implements that: it records the design's
`inside` call on every `nested_results` as a new `inside` attribute, rebuilds
the tuner description from the `procedure` attribute, refuses a results object
lacking the record or carrying no rows, and adds the Bayesian final-fit path
with its oracles, RNG properties, print/summary and docs.

The milestone's acceptance criteria were fixed at planning
(`cairn/milestones/M46-final-fit-recorded-procedure.md`, AC1–AC7). At the
implementation gate three questions came up that the maintainer chose to send
to independent review rather than settle in-session. The first is a measured
conflict between a criterion as written and tune's behaviour; the other two
are design choices with pinned prior output and a public condition contract at
stake. This is the second brief on the final-fit mechanism (RB02, 2026-07-26,
settled the path's existence, its seed contract and its first oracle set), so
per the repository's rule for a second escalation, removal of the mechanism is
among the options put to you in question 4.

**The measured fact behind question 1.** M46's AC3 reads, in its second
clause: "`tune::fit_best()` on `extract_tune_results()` of a Bayesian final fit
reproduces its predictions, the strand `test-nested-final-fit-oracles.R`
records as O5." On tune 2.1.0 (measured 2026-09-02 in this checkout),
`tune::fit_best()` on a `tune_results` built without
`control_*(save_workflow = TRUE)` aborts with "The control option
`save_workflow = TRUE` should be used when tuning." The package's tuner
controls (`tuner_control()`, `R/tuner.R:80-97`) never set `save_workflow`, and
the existing grid O5 strand (`test-nested-final-fit-oracles.R:96-131`) runs
`fit_best()` on the *test's own reference run*, built with `save_workflow =
TRUE` by `reference_final_fit()` (`helper-orchestration.R:202-240`) — the shape
RR02 Q5 established ("needs `save_workflow = TRUE` only on the test's own
`tune_grid()`"). So the criterion as written cannot pass unless the final-fit
path's own tuning run is stored with the workflow. Measured on a 60-row,
two-predictor recipe fixture: the stored run grows from 130.3 kB to 152 kB with
`save_workflow = TRUE`; on a recipe workflow the saved workflow carries the
recipe's training template, i.e. a copy of the data, and the final-fit object
already carries the fitted workflow with its own retained recipe.

## Materials

Read these, in this order. Line numbers are as of commit `0debd6b` on branch
`m046-final-fit-recorded-procedure`.

- `cairn/milestones/M46-final-fit-recorded-procedure.md` — the whole file:
  goal, scope, AC1–AC7, tasks, work log (the 2026-09-02 line records the gate).
- `cairn/DECISIONS.md` — entries D-014, D-016, D-023, D-040, D-041 (search
  `### D-0NN`). D-041 is the signature decision; D-023 the accessors.
- `cairn/DESIGN.md` — the IP block (IP1–IP4, around lines 160–195), GP1–GP5,
  and the final-fit paragraphs (lines 269–286).
- `cairn/reviews/archive/RB02-final-fit-path.md` and
  `cairn/reviews/archive/RR02-final-fit-path.md` — the first brief on this
  mechanism; RR02 Q5 (oracle independence, the `fit_best()` strand) and Q7
  (what the object may carry under IP3) bear directly on questions 1 and 2.
- `R/nested-final-fit.R` — the entry point (lines 211–258), `final_fit_worker()`
  (272–316), `new_nested_final_fit()` (327–338). Note the roxygen sections
  "What to report" and "Reproducibility".
- `R/tuner.R` — the tuner description, `run_tuner()` (46–78),
  `tuner_control()` (80–97), `new_procedure()` (104–114).
- `R/nested-tune-grid.R` lines 468–532 (`nested_loop()`), 654–735
  (`scored_candidates()`), and the roxygen paragraph at 394–400 that says
  `save_workflow` is "not offered" because each fold record discards the inner
  `tune_results`.
- `R/nested-final-fit-print.R` — the print and summary methods, whole file.
- `R/nested-final-fit-extract.R` — `extract_tune_results()` and its roxygen
  section "What its numbers are, and are not".
- `R/checks.R` — `check_iter()`, `check_initial()`, `check_objective()`
  (518–586) for the package's current condition-class convention
  (`nestedtune_bad_<arg>`), and `check_inside_spec()` (301–316).
- `tests/testthat/test-nested-final-fit-oracles.R` — the oracle provenance
  header (O3, O4, O5) and the three tests.
- `tests/testthat/helper-orchestration.R` lines 190–240
  (`reference_final_fit()`) and 125–188 (`reference_nested_bayes_loop()`).
- `tests/testthat/test-nested-final-fit-print.R` lines 78–117 — the
  hand-pinned `PRINT_BEFORE_M40` constant and its test, which is what question
  2 would re-agree.
- `tests/testthat/_snaps/nested-final-fit-print.md` — the current print and
  summary output for a grid final fit.

To reproduce the `fit_best()` refusal:

```r
library(tune); library(rsample); library(parsnip); library(workflows)
set.seed(1)
d <- data.frame(x1 = rnorm(60), x2 = rnorm(60)); d$y <- d$x1 + rnorm(60)
rec <- recipes::step_pca(recipes::recipe(y ~ ., data = d),
                         recipes::all_predictors(), num_comp = tune())
wf <- workflow(rec, linear_reg()); r <- vfold_cv(d, v = 3)
t1 <- tune_grid(wf, r, grid = data.frame(num_comp = 1:2),
                control = control_grid(allow_par = FALSE))
fit_best(t1, metric = "rmse")   # aborts: save_workflow = TRUE required
```

The suite runs with `Rscript -e 'devtools::test()'` from the repo root; the
final-fit oracle file alone with
`Rscript -e 'devtools::test(filter = "nested-final-fit-oracles")'`.

## Questions

1. **The O5 strand on a Bayesian final fit.** AC3's second clause requires
   `tune::fit_best()` to run on the tuning run the final fit itself stores.
   Two ways to meet the intent are on the table. (a) The final-fit path alone
   builds its tuning run with `save_workflow = TRUE` (a flag threaded from
   `final_fit_worker()` into `tuner_control()`; the fold path unchanged), so
   the criterion holds as written and `fit_best(extract_tune_results(x))`
   also becomes a user-usable route; the stored run then carries an unfitted
   workflow, a recipe's training template included. (b) The Bayesian O5 strand
   takes the shape RR02 Q5 fixed for the grid strand — `fit_best()` on the
   test's own reference run, built with `save_workflow = TRUE` — and AC3's
   wording is amended to say so, which is a substantive amendment under the
   repository's rules. Which do you recommend, and why? In answering, weigh:
   whether (a) changes what `x$tuning` means under IP3 and RR02 Q7 (the run is
   "the record of what selection saw"; a saved workflow is not a number, but
   it is more object); whether the memory cost is material for a package that
   treats performance as a design constraint (GP-level: "performance is a
   design constraint"); whether an oracle that runs `fit_best()` on the
   package's own stored run is stronger evidence than one that runs it on the
   reference's, given that the reference and the package run are asserted
   identical on selection and `in_id` splits in the same test file; and
   whether the roxygen paragraph at `R/nested-tune-grid.R:394-400` ("each fold
   record discards the inner `tune_results`") stays true or needs a
   final-fit-path caveat under (a).

2. **What the grid final fit's print and summary show.** AC5 asks that a
   *Bayesian* final fit's print and summary name the procedure: the initial
   count, the iterations actually completed (read as the tuning run's largest
   `.iter`), and the requested `iter` shown separately as requested. It says
   nothing about a grid final fit, whose print output M40 pinned by hand as
   the constant `PRINT_BEFORE_M40` (a test asserting that adding `summary()`
   changed no print byte). Should the grid final fit's print and summary also
   name their procedure (for instance the candidate count, which `summary()`
   already carries as `candidates`), re-agreeing M40's constant in M46, or
   should only the Bayesian one, leaving the grid output byte-identical? A
   related sub-question: the print method's pointer sentence currently says
   "Report the nested estimate from `collect_metrics()` on the
   `nested_tune_grid()` result"; for a Bayesian final fit that should
   presumably name `nested_tune_bayes()` — confirm or correct, and say whether
   the sentence should instead name neither and say "the `nested_results`
   this fit was built from", now that the object is built *from* a results
   object.

3. **The refusal contract for a results object the final fit cannot re-run.**
   AC1 says a `results` lacking `inside` or `procedure`, or with zero rows, is
   refused before any fitting "with its own condition class naming the user's
   call". Three shapes reach the refusal: the argument is not a
   `nested_results` at all; it is one but carries no `inside` or `procedure`
   attribute (an object built before this version, or one that shed its record
   through a dplyr or vctrs door that returns a bare tibble — see
   `R/nested-results.R:72-86` for the invariant rule); it carries the record
   but has zero rows. The package's convention for the Bayesian arguments is
   one class per *argument* (`nestedtune_bad_iter`, `nestedtune_bad_initial`,
   `nestedtune_bad_objective`), each class covering every wrong shape of that
   argument with a message naming the shape. Should the results-record
   refusal follow that convention — one class, say `nestedtune_bad_results`,
   three messages — or carry one class per shape so a caller can distinguish
   "no record" from "empty" without reading the message? Say what a caller
   would do differently on each, if anything, and what the pre-M46-object
   message should tell the user (the plan's answer is "re-run the
   orchestrator on this version"; a results object is not migrated, D-041).

4. **Second escalation: removal.** This is the second brief on the final-fit
   mechanism. Put removal among the options: should `nested_final_fit()` be
   removed altogether, leaving users `tune::fit_best()` and
   `tune::last_fit()` (which D-041 already names as the route for a tuned fit
   with no nested run in hand), with the package documenting the "re-run the
   procedure on all rows" recipe instead of implementing it? Weigh it
   against keeping the mechanism as M46 plans it. D-041's own falsifier is "a
   real need for a final fit from a design alone that those two do not
   serve"; the question here is the complement — whether the recorded-procedure
   final fit earns its code and its oracle burden over a documented recipe.
   Answer plainly; a recommendation to keep is as useful as one to remove.

## Constraints

- **D-002 — the contract boundary.** nestedtune orchestrates and delegates
  the statistical pipeline to tune; nothing here re-implements tuning,
  selection or fitting.
- **D-041 — the signature.** `nested_final_fit(object, results, ...)` reading
  the procedure from the results object is settled; the former `grid`,
  `param_info`, `metrics`, `event_level` and `eval_time` formals are gone
  without a deprecation cycle (D-003, pre-1.0). Question 4 may recommend
  removing the function; it may not reintroduce a design-plus-procedure
  signature.
- **D-014 / RR02 Q7 — what the object carries.** The final fit object carries
  the tuning run as the record of what selection saw; tune's ranking and
  collecting generics stay unregistered for the class; no number from the run
  appears in print or summary. Question 1(a) is asked *within* this — whether
  a saved workflow on that run is compatible with it.
- **D-016 — seed scope.** The tuning seed's scope is "construct the resamples
  and tune"; D-040 extends it so `control_bayes(seed = <tuning seed>)` is
  built inside that scope. Not up for revision.
- **IP3, IP4** as `cairn/DESIGN.md` states them. IP2 (reproducibility) binds
  the Bayesian final-fit path exactly as it binds the fold path.
- **Dependency changes are gated** and are not asked for here; do not
  recommend adding a package.
- **AC wording is amendable only through the maintainer's gate.** If you
  recommend (b) in question 1, say so; the maintainer amends, not you.

Flag disagreement with a constraint explicitly rather than working around it.

## Output format

In `RR05-final-fit-recorded-procedure.md`: answer each question by number with
your reasoning and evidence; list any additional findings separately under
"Beyond the brief"; end with concrete recommendations, each marked apply /
consider / reject-with-reason. Your report is advisory: emit a `## Binding
criteria` section ONLY if this brief's header slot says `requested`. Where
requested: numbered `BC1…`, each a measurable assertion checkable against
evidence, with any numeric projection stating its tolerance. These are
ingested VERBATIM into the constrained milestone's acceptance criteria and
mechanically diffed against this file; departures are legal only through that
milestone's shown "Deviations from RR05" table.
