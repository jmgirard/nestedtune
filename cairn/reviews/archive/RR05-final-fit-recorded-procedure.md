# RR05: The final fit re-running a recorded procedure — its Bayesian oracle, its print, its refusals (M46)

- **Date:** 2026-09-02
- **Answers:** RB05 (`cairn/reviews/RB05-final-fit-recorded-procedure.md`)
- **Reviewer basis:** every material RB05 lists, read in full at `0debd6b`
  on `m046-final-fit-recorded-procedure`: the M46 milestone file; D-014,
  D-016, D-023, D-040, D-041; DESIGN's IP/GP block and final-fit paragraphs;
  RB02/RR02; `R/nested-final-fit.R`, `R/tuner.R`, the named segments of
  `R/nested-tune-grid.R`, `R/nested-final-fit-print.R`,
  `R/nested-final-fit-extract.R`, `R/checks.R`, `R/nested-results.R`; the
  oracle, print and checks test files, `helper-orchestration.R`, and the
  print snapshot. Behavioural claims tagged *verified* were run in this
  checkout (R, tune 2.1.0); probes P1–P5 below. Everything else is
  *inferred* from source.
  - P1: `tune::fit_best()` on a `tune_grid()` run built without
    `save_workflow = TRUE` aborts with the message RB05 quotes. *Verified.*
  - P2: with `save_workflow = TRUE` the saved object is an **unfitted**
    workflow whose recipe template holds every training row (60 of 60 on
    the brief's fixture). Object growth: 130.3 kB → 152 kB on the 60-row
    fixture, and 2,631.9 kB → 3,485.9 kB on a 5000 × 20 frame whose data
    is 823.4 kB — the run grows by 854 kB, i.e. one copy of the data plus
    change. *Verified.*
  - P3: the fitted workflow a plain `fit()` returns already retains its
    recipe template (60 of 60 rows), so under 1(a) the final-fit object
    would hold the data twice. *Verified.*
  - P4: `attr(run, "workflow") <- wf` on a run tuned *without*
    `save_workflow` makes `fit_best()` accept it — `fit_best()` reads the
    workflow off that one attribute and the training data off
    `x$splits[[1]]$data`. *Verified*, and it is a private attribute of
    tune's, not an interface.
  - P5: `control_bayes(save_workflow = TRUE)` is accepted and `fit_best()`
    runs on a `tune_bayes()` result so built; `collect_metrics()` on it
    carries `.iter`. *Verified.*

## Answers

### 1. The O5 strand on a Bayesian final fit

**Recommend (b): run `fit_best()` on the test's own reference run, built
with `save_workflow = TRUE`, and amend AC3's second clause to say so.**
The grounds, in the order the brief asks them to be weighed:

*What (a) changes about `x$tuning` under IP3 and RR02 Q7.* In the letter,
nothing: an unfitted workflow carries no number, so BC4 (no number from
the run in print or summary) and the unregistered ranking generics are
untouched. In substance it changes the object's story. RR02 Q7 kept the
run as "the record of what selection saw" — the resamples, the candidates,
the scores. The workflow is the *input* to selection, which the user
already holds as `object`; it is not part of what selection saw. More
consequentially, (a) turns `fit_best(extract_tune_results(x))` into a
working user route that produces a second "final model" from the same
selection, fitted on the ambient RNG stream rather than on `x$fit_seed`,
and so not the model on the object and not reproducible from the object's
two seeds. That is a second path to the thing the function exists to
produce (GP3: one obvious path), and it is a path the package would have
opened without meaning to. Under (b) the route stays closed, as it is
today.

*Memory.* P2 and P3 measure it: on a recipe workflow the saved workflow is
one more copy of the training data on top of the copy the fitted
workflow already retains, so the final-fit object roughly doubles its data
footprint (+854 kB against 823 kB of data at 5000 × 20; the growth scales
with the data, not with the run). GP4 says memory is a design constraint,
and the loop's own roxygen (`R/nested-tune-grid.R:394-400`) declines
`save_workflow` on grounds that would now hold for the final fit as well.
The cost buys nothing a user needs — the trained workflow is on the
object — so it is spent on the oracle alone.

*Evidence strength.* Running `fit_best()` on the package's stored run is
not stronger evidence than running it on the reference's, given the
assertions already in the file. `fit_best()` reads three things: the
metrics (to select), the saved workflow (to finalize), and
`x$splits[[1]]$data` (to fit; P4). The first test in the file asserts the
package run and the reference run identical on `selected` and on every
split's `in_id`; the data is the same frame on both; the workflow is the
same `wf`. So the inputs `fit_best()` would read from the two runs are
already asserted equal, and the tail it exercises — select, finalize, fit
on all rows — is the same tail either way. The one thing (a) adds is a
check that the package's stored run is a well-formed `tune_results`
`fit_best()` accepts, which `extract_tune_results()`'s existing snapshot
test and `scored_candidates()` already cover. The O5 strand's value lies
in routing the tail through code nobody in this package wrote (RR02 Q5);
that value is fully realized under (b). Worth saying plainly: the
Bayesian O5 strand is weaker than the grid one in any shape, because
`fit_best()` never runs `tune_bayes()` — it pins only that `select_best()`
on a `.iter`-bearing run picks the row the package picked. It is still
cheap and still worth having.

*The roxygen paragraph.* Under (b) "each fold record discards the inner
`tune_results`" stays true and needs no caveat. Under (a) it needs one, and
`tuner_control()` needs a flag that makes the final-fit control differ from
the fold control — the first divergence between the two, in a function
whose whole point is that the final fit re-runs *the same* procedure. The
by-hand recipe in the Reproducibility section would then either show a
control the loop does not use or omit a slot the code sets.

A third shape, P4, is available and should be named so it is rejected on
the record rather than overlooked: attach `wf` to the package's own
extracted run inside the test (`attr(run, "workflow") <- wf`) and run
`fit_best()` on that. It gives "fit_best on the package's stored run" with
no package change and no memory cost, but it leans on a private attribute
name in tune, and the evidence gain over (b) is nil for the reason above.
Reject; (b) is the shape RR02 Q5 fixed and it has served the grid strand
unchanged since M05.

Suggested AC3 wording for the maintainer's gate (advisory): "…and
`tune::fit_best()` on the reference Bayesian run — `reference_bayes_final_fit()`'s
`tune_bayes()` built with `save_workflow = TRUE`, asserted identical to the
final fit's stored run on selection and `in_id` splits in the same file —
reproduces the Bayesian final fit's predictions, the strand
`test-nested-final-fit-oracles.R` records as O5." The O5 provenance
header already says "Needs save_workflow = TRUE on the test's own
tune_grid() call"; extend it to "the test's own tuner call".

### 2. What the grid final fit's print and summary show

**Both tuners' final fits should name their procedure in both methods, and
M40's constant should be re-agreed by hand in M46.** The alternative — a
procedure line that appears only when the tuner was Bayesian — gives one
class a print whose shape depends on which orchestrator ran, and a user
holding a grid fit and a Bayesian fit of the same workflow would see two
layouts for one kind of object. The asymmetry costs more than re-agreeing
fourteen pinned lines.

The substantive reason the line belongs on the grid fit too is the one
`print_final_design()` already gives for the summary: the candidate count
"is the size of the menu selection picked from, which is what makes the
line below it a choice rather than a foregone conclusion". `Selected:
num_comp = 3` with no menu is the foregone-conclusion reading; a grid fit
that says "3 candidates" and a Bayesian one that says "5 initial, 8
iterations completed (10 requested)" are the same sentence about two
searches. One line suffices in `print()`; the summary already has
`Full-data tuning:` and `Candidates scored:` and gains the Bayesian
counts as components (`initial`, `iterations_completed`,
`iterations_requested`, `NULL` on a grid fit, carried rather than omitted,
in the habit `estimate = NULL` set).

On the counts themselves, two sharpenings, because AC5 says "the initial
count" without saying which one. `tune_bayes()` can generate fewer initial
candidates than `initial` asks for — a space-filling design on a small
integer space deduplicates — so "initial" has a requested and a scored
value exactly as `iter` does. IP4 wants what ran: read the initial count
as the number of `.iter == 0` rows in `scored_candidates(x$tuning)`, the
completed iterations as the largest `.iter` there (both derivations never
raise, since `scored_candidates()` swallows its errors), and show the
requested `iter` and `initial` from `attr(results, "procedure")` as
requested. Whether to show a requested figure only when it differs from
the scored one or always is a taste call; always is simpler to snapshot
and pin at both counts (LESSONS: pin the counts at which the wording
changes).

On `PRINT_BEFORE_M40`: its promise was M40's — "adding `summary()` changed
no print byte" — and it was kept. M46 changing the print on purpose does
not break it; it retires it. Keep the mechanism (a hand-written constant,
not a snapshot, for the reason the test's comment gives) and re-pin:
rename to something that says what it now guards, state the promise it
now makes, and record in the test comment that M46 re-agreed it and why.
Dropping the constant and leaving only the snapshot would lose the
protection M40 built.

*The pointer sentence.* Confirmed: for a Bayesian final fit "the
`nested_tune_grid()` result" is wrong. Two fixes work. The print method
has `attr(results, "procedure")$tuner` in reach only if M46 stores the
procedure (or the tuner name) on the final-fit object — it does not today
— so the branch-free fix is the better one: name the results object, not
the orchestrator. Suggested: "Report the nested estimate from
`collect_metrics()` on the results object this fit was built from, which
describes the procedure that produced it." (Avoid "the `nested_results`
this fit was built from" in *printed* text — the user holds `res`, not a
class name — and use the class name in roxygen where it links.) The
`nested_tune_grid()` wording is in six places T6 should sweep, all of
which now name one orchestrator where two exist: the two `@description`
paragraphs in `R/nested-final-fit-print.R`, both bullets
(`print.nested_final_fit()` and `print_final_estimate()`), the "What its
numbers are, and are not" section in `R/nested-final-fit-extract.R`, and
the "What to report" section in `R/nested-final-fit.R`. In roxygen "the
[nested_tune_grid()] or [nested_tune_bayes()] result" keeps the links;
in printed text the results-object phrasing is enough.

### 3. The refusal contract for a results object the final fit cannot re-run

**One class, `nestedtune_bad_results`, three (in practice four) messages,
following the per-argument convention.** The test the brief asks for —
what would a caller do differently on each — has the same answer for
every shape: stop, and go back to an object the orchestrator produced.
No handler re-runs `nested_tune_grid()` from inside a `tryCatch`; the
distinction between "you filtered it to nothing" and "this was built by an
older version" is for the person reading the message, and the message
carries it. The Bayesian checks already fold a type error ("Got a
character vector") and a value error ("Got 2.5") into one class per
argument; `nestedtune_bad_results` covering "not a `nested_results`",
"no record" and "no rows" is the same rule. A caller who needs the
shape programmatically can read `conditionMessage()`; none is known to
need it.

What the shapes actually are, read against `R/nested-results.R`, differs a
little from the brief's list and affects the messages:

- *Not a `nested_results` at all.* This is also where the dplyr/vctrs
  door lands: an operation outside the invariants (rows added or removed)
  returns a **bare tibble**, class and attributes gone together, so
  `res[0, ]`, `filter(res, FALSE)` and `slice(res, 1)` all arrive here, not
  as a classed object missing its record. The message should say so: "a
  verb that changed the rows returns a plain tibble; use the object the
  orchestrator returned".
- *A `nested_results` lacking `inside`.* Two origins, indistinguishable by
  inspection because an attribute cannot hold `NULL`: an object built by
  M45 (`procedure` present, `inside` never stamped), and an M46 object
  built from a design that carried no `inside` call (T1's own test: "a
  design carrying no `inside` yields a result whose attribute is
  `NULL`"). One message must cover both: "carries no inner resampling
  specification to re-run — it was built by an earlier version of
  nestedtune, or from a design assembled by hand rather than by
  `nested_resamples()` or `rsample::nested_cv()`. Re-run
  `nested_tune_grid()` or `nested_tune_bayes()` on this version, on a
  design from one of those constructors; a results object is not
  migrated." That is the plan's answer with the second origin added.
- *A `nested_results` lacking `procedure`.* Only an object from before
  M45. Same remedy, and it will always also lack `inside`, so one branch
  ("lacks `inside`/`procedure`") serves; test both attributes and name
  whichever is missing.
- *Zero rows with the record present.* By the invariant rule this is a
  prototype (a `vec_ptype()`), never a filtered object, and the plan's
  audit already says so. Message: "has no rows, so there is no data to
  re-run the procedure on; a prototype describes the run but cannot
  re-run it".

Order: `check_workflow(object)` first, as today, then the results check,
so the frame the abort names is the user's call (AC1) and the check runs
before `split_data()` touches the `splits` column.

A detail worth fixing while there: `check_inside_spec()`'s message names
`{.arg resamples}` and "a design assembled by hand"; under D-041 the
argument is `results` and the missing call is the design's, recorded on
the results. The wording should say the results object carries no
specification because the design it came from carried none.

### 4. Second escalation: removal

**Keep it.** The case for removal, stated at its strongest: the function is
one recipe — seed, build the inner rset, tune, select, finalize, seed, fit
— and the package could print that recipe in a vignette and stop carrying
`R/nested-final-fit.R`, its print/summary/extract surface (some 500
lines), three test files and a reference implementation that M46 now
doubles for the Bayesian path. Pre-1.0 the deletion is cheap.

Why it does not hold:

1. **The two tune functions D-041 names do not perform the recipe.**
   `fit_best()` needs a run built with `save_workflow = TRUE` on resamples
   the user built themselves, under a seed they placed themselves;
   `last_fit()` fits on a split's training rows and scores its test rows —
   it never fits on every row. So "leave users `fit_best()` and
   `last_fit()`" leaves them the by-hand block in the Reproducibility
   section, not two calls. That block has three places to go silently
   wrong that two reviews have now found: the rset draw outside the tuning
   seed's scope (RR02 Q4 — "every same-seed identity test would still
   pass"), `control_bayes(seed = )` left to tune's default (D-040), and the
   `inside` call re-evaluated in an environment where its free variables
   changed (RR02 B1). A recipe documents these; the function prevents them.
2. **A recipe reintroduces the restatement D-041 just removed.** The user
   would write out `grid`/`iter`/`initial`/`objective`/`param_info`/
   `metrics`/`event_level`/`eval_time` a second time, and nothing would
   stop them writing them differently from the run whose estimate they
   report. The recorded procedure exists to make the model and the
   estimate come from one search; that is IP3's pairing, and a vignette
   cannot enforce it.
3. **The oracle burden is already paid, and M46's increment is small.**
   O3, O4 and O5 exist and pass; M46 adds one reference function
   (`reference_bayes_final_fit()`, a copy of the fold reference with the
   loop removed) and one invariant (`iter = 0` equals the grid fit), both
   shapes the suite already has. Under 1(b) no package code changes for
   the oracle at all.
4. **The surface is where IP3's obligation is met.** The print method's
   "this model has no performance estimate of its own" sentence, the
   pointer to `.selected`, and the bias caution on `extract_tune_results()`
   are read at the moment of deployment. Remove the object and that
   sentence moves to a help page nobody opens at that moment.
5. **D-041's falsifier points the other way.** It is "a real need for a
   final fit from a design alone"; nobody has produced one. The
   complement — a real need to *not* have the function — has no evidence
   either, and the standard tools (mlr3's `AutoTuner`, scikit-learn's
   search objects) all ship the refit as a call, not a recipe (RR02 Q1).

Conditions under which this should be reopened, so the recommendation is
falsifiable: tune shipping a "refit the recorded procedure on all rows"
path that reads a tuning run's resampling specification, which would put
the function inside D-002's boundary; or the Bayesian/grid parity in
print, summary and oracles turning into a recurring cost with each new
orchestrator, at which point the surface (not the worker) is what should
shrink.

## Beyond the brief

- **B1 — the `inside` attribute cannot record "none".** Because
  `attr(x, "inside") <- NULL` removes the attribute, an M46 object from a
  design with no `inside` call and an M45 object look the same. Q3's
  message covers it; T1's test ("yields a result whose attribute is
  `NULL`") should say in its comment that this is why the refusal names
  both origins.
- **B2 — the Reproducibility recipe is grid-only.** `R/nested-final-fit.R`'s
  by-hand block calls `tune_grid()` under `control_grid()`. M46 T6 needs
  the Bayesian variant — `tune_bayes(object, inner, iter =, initial =,
  objective =, …, control = control_bayes(allow_par = FALSE, event_level =,
  seed = fit$tuning_seed))` — or one block with the tuner call named
  generically and both controls shown. D-040's `seed = <the tuning seed>`
  is the line a reader would omit.
- **B3 — `test-nested-final-fit-checks.R` moves to results objects, and
  `folds[0, ]` no longer tests zero rows.** `results[0, ]` returns a bare
  tibble (invariant rule), so it exercises the "not a `nested_results`"
  branch. The zero-row branch needs a prototype: `vctrs::vec_ptype(res)`
  or attribute surgery, as T4's corruption test already plans.
- **B4 — the `metrics` attribute may legitimately be `NULL`.** A results
  object from a run with `metrics = NULL` carries no metric set; the
  rebuilt procedure must pass `NULL` on and let tune pick, as
  `final_fit_worker()` already does via `.get_tune_metric_names()`. Not a
  refusal case; worth one assertion.
- **B5 — the summary's `candidates` on a Bayesian fit.** `scored_candidates()`
  deduplicates on `.config`; a Bayesian run labels initial candidates
  `Preprocessor1_Model1…` and proposals `Iter1…`, so the count is initial
  scored plus iterations completed. Fine, but the print line should not
  compute `initial` as `candidates - max(.iter)`; count `.iter == 0` rows
  directly (Q2).

## Recommendations

1. **Apply — Q1 (b).** The Bayesian O5 strand runs `fit_best()` on the
   reference's own `tune_bayes()` run built with `save_workflow = TRUE`;
   the package's controls stay as they are; AC3's second clause is amended
   by the maintainer to say so (wording offered under Q1).
2. **Reject — Q1 (a)**, saving the workflow on the final-fit path: doubles
   the object's data footprint (P2, P3) against GP4, opens an unintended
   second final-model route on the ambient stream against GP3, makes the
   final-fit control diverge from the fold control, and adds no evidence
   the file's existing identity assertions do not already give.
3. **Reject — the test-side attribute-surgery variant (P4)**: works on
   tune 2.1.0 but leans on a private attribute name for no evidence gain.
4. **Apply — Q2: one procedure line in `print()` for both tuners, the
   counts as summary components for both**, grid included; re-agree the
   hand-pinned constant under a new name with its new promise stated.
5. **Consider — Q2 sharpening of AC5:** read the initial count as the
   `.iter == 0` rows of the scored candidates, not from `procedure$initial`,
   and show requested `initial` beside requested `iter`. Maintainer's gate
   for the wording.
6. **Apply — Q2 pointer sentence:** name the results object the fit was
   built from, not an orchestrator, in printed text; in roxygen link both
   orchestrators. Sweep the six sites listed under Q2.
7. **Apply — Q3: one class `nestedtune_bad_results`,** messages per
   origin as drafted, the "no `inside`" message naming both origins (B1)
   and the bare-tibble message naming the verb door.
8. **Apply — Q3 detail:** reword `check_inside_spec()` (or its successor)
   for an argument named `results` whose design carried no specification.
9. **Apply — Q4: keep `nested_final_fit()`** as M46 plans it, with the two
   reopening conditions recorded in the milestone's Decisions section.
10. **Apply — B2:** the Reproducibility recipe shows the Bayesian control
    with `seed = fit$tuning_seed`.
11. **Consider — B3, B4:** the zero-row refusal test built from a
    prototype; one assertion that a `NULL` `metrics` attribute re-runs.
