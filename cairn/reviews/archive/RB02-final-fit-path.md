# RB02: The final-fit path after nested cross-validation (M05)

- **Date:** 2026-07-26
- **Output required:** write findings to `cairn/reviews/RR02-final-fit-path.md`

You are performing an independent expert review. This brief is fully
self-contained — do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

**The package.** `nestedtune` is an R package (pre-1.0, no CRAN release yet)
that orchestrates nested cross-validation for the tidymodels ecosystem. Its
contract boundary is deliberately narrow: it drives the **outer loop** and
delegates inner tuning to `tune`. For each outer fold it calls
`tune::tune_grid()` on that fold's inner `rset`, selects with `select_best()`,
finalizes the workflow, and fits/scores on the outer split with `last_fit()`.
It does not implement a tuning engine.

**What has shipped.** Four milestones. M01 exports `nested_resamples()`, a
memory-lean replacement for `rsample::nested_cv()`. M02 exports
`nested_tune_grid()`, returning a `nested_results` object that keeps each outer
fold's selected parameters. M03 made a failed outer fold recorded rather than
fatal. M04 added the print method. Execution is still **serial**; parallelism
over outer folds is a later milestone.

**What this milestone (M05) is doing.** Adding the missing final-fit path.
Today `nested_tune_grid()` tells users in its documentation to "fit that
separately" and gives them no way to do it. M05 adds
`nested_final_fit(object, resamples, grid, metrics)`, which re-evaluates the
design's stored inner resampling specification against the **complete
dataset**, runs `tune::tune_grid()` on the resulting `rset`, selects with
`select_best()`, finalizes, and fits the finalized workflow on every row with
`fit()`. It returns a `nested_final_fit` object holding the trained workflow,
the selected parameters, and the tuning run, reached via `extract_workflow()`.

The enabling structural fact, verified in this checkout: both
`nested_resamples()` and `rsample::nested_cv()` store the inner specification
as an **unevaluated call** in `attr(x, "inside")` (e.g. the language object
`vfold_cv(v = 3)`), and every split carries the full original data in
`$data`. So the design object alone is sufficient to re-run the procedure on
all the data.

**Why this needs independent review.** M05's plan tags two tasks as touching
inviolable principles. This repo's inviolable principles are hard constraints
never violated in implementation; changing one requires an explicit maintainer
decision recorded as a decision entry. The two at issue read verbatim:

> IP1: **No leakage across the outer boundary.** The outer assessment set never
> influences anything upstream of its own scoring: not inner tuning, not
> parameter selection, not preprocessing. This binds the final-fit path as well
> as the loop — preprocessing is estimated on analysis data, never on the full
> dataset. This is the property that makes the package's output mean anything.

> IP2: **Reproducible results.** The same seed produces the same result
> regardless of the number of workers and regardless of whether execution is
> parallel or serial. This requires RNG streams managed per outer fold rather
> than inherited from a worker, and it constrains which parallel backends are
> usable. Deliberately **not** claimed, because it cannot be honoured: identity
> across R versions, across platforms, or across `tune` versions.

Note IP1's middle clause: it says in so many words that it binds the final-fit
path, and that preprocessing is estimated on analysis data "never on the full
dataset". The maintainer's provisional reading — which this brief exists to
test rather than to assert — is that this clause governs *estimation of a
performance claim*, and that the final model, which produces no estimate and
whose training set is by definition the whole dataset, is outside it. If that
reading is wrong, M05's central design is wrong.

A third principle shapes what the returned object may carry:

> IP3: **The estimate describes the procedure, never the shipped model.** The
> nested estimate characterizes the whole tune-and-fit procedure. The API never
> presents it as a property of a fitted model, however convenient that would be;
> the final model is a separate object. Because this refuses the applied
> audience's most natural request, it carries an obligation: the documentation
> must say plainly what a user should report instead, and why.

**The RNG contract M05 proposes to reuse.** M02's contract (decision D-011,
settled by the previous review RB01/RR01) draws `2 * n` seeds in one
`sample.int()` call at entry, assigns fold `i` elements `2i-1` and `2i`,
applies each with the generator kind pinned, and restores the caller's
`.Random.seed` and `RNGkind()` on exit including on error. M05 proposes the
same shape with `n = 1`: two seeds, one for the tuning run and one for the
final fit, same kind pinning, same restoration.

## Materials

Read these files in the repository root. They are short. R 4.6.1 with `tune`
2.1.0, `rsample`, `workflows`, `parsnip`, `recipes`, `yardstick`, and `ranger`
installed; `Rscript -e 'devtools::test()'` runs the existing suite.

- `cairn/DESIGN.md` — purpose, contract boundary, conventions, and the full
  IP/GP principle set. Note the convention "The final model is a separate
  object, never a field on the results", and GP1 (delegation fidelity), GP2
  (oracle verification), GP3 (hard to misuse over configurable), GP5 (don't
  ship inference the literature hasn't settled).
- `cairn/milestones/M05-final-fit-path.md` — the milestone's goal, scope,
  acceptance criteria AC1–AC6, coverage map, and tasks T1–T8. T2 and T5 carry
  the tripwire tags that produced this brief.
- `cairn/DECISIONS.md` — read D-002 (contract boundary), D-003 (pre-1.0
  deprecation waiver), D-010 (why `nested_results` deliberately does not
  inherit `tune_results`), D-011 (the RNG contract quoted above), and D-014
  (the decision that created M05: what was chosen and what was rejected).
- `R/nested-tune-grid.R` — the whole file (364 lines). The orchestrator M05
  parallels. `nested_fold_fit()` at lines 179–244 is the per-fold pipeline;
  `set_fold_seed()` and `restore_rng()` at lines 342–363 are the helpers M05
  proposes to reuse verbatim.
- `R/nested-resamples.R` — the whole file (177 lines). Lines 124–129 are where
  the `inside` and `outside` attributes are stored.
- `R/nested-results.R` — the whole file (269 lines). The results object and its
  `collect_metrics()` method, for the shape M05's new object parallels.
- `R/checks.R` — the whole file (188 lines). The validation M05 reuses.
- `cairn/reviews/archive/RR01-rng-streams-outer-folds.md` — the previous
  review, which settled the RNG scheme. Its reasoning about oracle
  independence (its question 7) bears directly on question 5 below.
- `cairn/LESSONS.md` — durable repo lessons. Several bear on how the tests in
  question 5 and 6 must be written (deterministic engines make RNG tests pass
  vacuously; `tune >= 2.0.0` derives its own per-resample substreams).

## Questions

1. **Is re-running the tuning procedure on the complete dataset the correct
   final-fit path?** State the argument for and against, and give a verdict. In
   particular: during the nested run the inner specification is evaluated
   against each outer fold's *analysis set* (roughly `(v-1)/v` of the data);
   `nested_final_fit()` evaluates the same specification against 100% of the
   data, so with a fixed `v` the resamples are of different absolute size than
   any resample the nested estimate ever saw. Does that difference mean the
   final model's tuning is not the procedure that was validated? If it does,
   say what the alternative is and whether it is worth its complexity.

2. **Does IP1 permit this, on the text quoted above?** Address the middle
   clause directly — "This binds the final-fit path as well as the loop —
   preprocessing is estimated on analysis data, never on the full dataset."
   Under the maintainer's reading, the final model's preprocessing *is*
   estimated on the full dataset, and that is correct because the full dataset
   is its training data and no performance claim is derived from it. Is that
   reading sound, or does IP1 as written forbid what M05 proposes? If the text
   and the intent diverge, say so plainly — amending an inviolable principle is
   possible here but requires an explicit recorded decision, so it matters
   whether one is needed.

3. **Is there a leakage path inside the final fit that the maintainer has not
   named?** Consider at least: the inner specification being re-evaluated
   against data that includes rows which were outer-assessment rows in the
   nested run; the tuning run's own resamples and whether tune estimates
   preprocessing within each analysis set (verify against tune's behavior, and
   say what you verified versus inferred); and any way the returned object
   could let a user derive a number that is optimistically biased while
   appearing to be an honest estimate.

4. **Does D-011's RNG contract transfer unchanged?** M05 proposes two
   kind-pinned seeds drawn in one `sample.int()` call at entry — one for the
   tuning run, one for the final fit — with the caller's `.Random.seed` and
   `RNGkind()` restored on exit including on error, reusing `set_fold_seed()`
   and `restore_rng()` verbatim. Is two the right number, is the split at the
   right place, and does anything about a full-data tuning run (as opposed to a
   per-fold one) break the contract or the reasoning RR01 used to justify it?

5. **Can M05's two oracles be genuinely independent?** The milestone's AC2
   proposes (a) a hand-written tune pipeline over the same inner specification
   on the full data, asserted identical to `nested_final_fit()`'s selected
   parameters and predictions — a reference-implementation oracle; and (b) a
   forced selection under a one-row grid, asserted identical to a direct
   `fit()` of the finalized workflow — an invariant oracle. RR01's question 7
   raised the matching hazard for M02: a hand-written reference loop that must
   reproduce the seeding scheme risks becoming a restatement of the
   implementation rather than an independent check of it. Assess whether (a)
   escapes that hazard here, and whether (a) and (b) are two independent oracle
   *types* or one type twice. If they are not independent, propose a third
   construction — including any external reference implementation worth
   checking against, such as `mlr3`'s `AutoTuner`, whose training on the full
   task is the same operation.

6. **How should IP2 be tested for this path?** Name the specific tests. The
   repo's lessons record that a deterministic engine makes every RNG test pass
   vacuously — including under seeding schemes that are wrong — so the engine
   must be one whose randomness flows through R's generator (`ranger`
   qualifies). Say what the tests establish and what they do not.

7. **What may the returned object carry, under IP3?** M05 plans to store the
   trained workflow, the selected parameters, and the full-data tuning results,
   and to leave `collect_metrics()`, `show_best()`, and `select_best()`
   deliberately unregistered so they error rather than answer — the same
   refusal D-010 chose for `nested_results`. But a user can reach the stored
   tuning results and call `collect_metrics()` on *them*, obtaining the
   selection-time resampling estimate on the full data: a number that is
   optimistically biased as a performance claim and that looks authoritative.
   Is storing the tuning run a hazard IP3 should forbid, a provenance benefit
   worth the risk, or something to keep behind a differently-named accessor?

8. **What exactly should the documentation say?** IP3 obliges the package to
   state plainly what a user should report instead of the final model's own
   performance, and why. Draft the substance of that claim in two or three
   sentences — the wording a statistically careful reader would accept, which
   the implementer can adapt. Name anything a user could still get wrong after
   reading it.

## Constraints

Fixed, and not to be relitigated. Flag disagreement with a constraint
explicitly in your report rather than silently working around it.

- **D-002 — the contract boundary.** nestedtune orchestrates and delegates
  inner tuning to `tune`. Recommendations that reimplement any part of tune's
  tuning engine are out of scope.
- **D-014 — M05's settled API shape.** The export is
  `nested_final_fit(object, resamples, grid, metrics)`; it returns its own
  `nested_final_fit` class reached with `extract_workflow()`; `predict()` and
  `augment()` methods are deliberately deferred. Naming, the return-shape
  choice, and the rejection of reusing the outer folds' selections (e.g. by
  modal vote) are settled — do not re-open them. You may recommend *additional*
  arguments or accessors if an answer above requires one; that is in scope.
- **A design carrying no re-runnable inner specification is refused**, with a
  clear error pointing at the two constructors that produce one. Settled at the
  maintainer's gate; do not propose an override argument.
- **Dependency changes are gated.** Hard dependencies today are `rsample`,
  `cli`, `rlang`, `tune (>= 2.0.0)`, `workflows`, `parsnip`. Any recommendation
  adding another — including base-priority packages, and including `hardhat`,
  whose `extract_workflow` generic is already reachable through tune's
  re-export — must say so explicitly, because it triggers a separate maintainer
  gate and a recorded decision.
- **D-003 — pre-1.0, deprecation cycle waived.** Breaking changes are cheap.
  Do not water down a recommendation to preserve compatibility the project has
  explicitly declined to promise.
- **IP2's own disclaimers hold.** Identity across R versions, platforms, and
  `tune` versions is deliberately not claimed.
- **GP5 — no inference the literature hasn't settled.** Variance estimation on
  the nested estimate is parked as a roadmap candidate for exactly this reason.
  Do not recommend that M05 ship an interval.
- **M05's scope excludes the long-form vignette** (it is M06) and excludes
  parallelism. Documentation recommendations should be sized for roxygen.

## Output format

In `cairn/reviews/RR02-final-fit-path.md`: answer each question by number with
your reasoning and evidence; list any additional findings separately under
"Beyond the brief"; end with concrete recommendations, each marked
apply / consider / reject-with-reason.

Where findings bind implementation, also emit a `## Binding criteria` section:
numbered `BC1…`, each a measurable assertion checkable against evidence, with
any numeric projection stating its tolerance. These are ingested VERBATIM into
M05's acceptance criteria and mechanically diffed against this file; departures
are legal only through a shown "Deviations from RR02" table. Keep binding
criteria to what genuinely binds — each one becomes a criterion the milestone
cannot ship without satisfying. M05 already carries six acceptance criteria
and a 150-line budget on its plan-owned sections, so criteria that merely
restate an existing AC cost the milestone more than they buy.
