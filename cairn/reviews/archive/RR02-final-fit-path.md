# RR02: The final-fit path after nested cross-validation (M05)

- **Date:** 2026-07-26
- **Answers:** RB02 (`cairn/reviews/RB02-final-fit-path.md`)
- **Reviewer basis:** All materials listed in RB02 read in full: DESIGN.md, the
  M05 milestone file, D-002/D-003/D-010/D-011/D-014, `R/nested-tune-grid.R`,
  `R/nested-resamples.R`, `R/nested-results.R`, `R/checks.R`, RR01, LESSONS.md.
  Behavioral claims were **verified by execution** in this checkout (R 4.6.1,
  tune 2.1.0, rsample 1.3.2, ranger installed) wherever a probe could settle
  them; each claim below is tagged *verified* (ran code) or *inferred*
  (reasoned, not executed). Probe results referenced as P1–P6:
  - P1: `tune_grid()` (2.1.0, `allow_par = FALSE`) preps a recipe **per
    resample on that resample's analysis set** — the extracted
    `step_normalize` mean equals the analysis-set mean, not the full-data
    mean, and differs across folds. *Verified.*
  - P2: plain `fit()` on a workflow with a ranger spec consumes the **ambient
    R stream**: same seed → identical predictions, different seed → different,
    and the call advances `.Random.seed`. *Verified.*
  - P3: the stored `inside` attribute is an unevaluated call on both
    constructors; re-evaluating `vfold_cv(v = k)` where `k` is no longer in
    scope **errors**, and where a different `k` is in scope it **silently
    builds a different design** (v = 10 for a design built with v = 4).
    *Verified.*
  - P4: `tune::fit_best()` exists, requires `save_workflow = TRUE` on the
    tuning run, returns a trained workflow, and under the same seed its
    ranger predictions are `identical()` to a hand
    `finalize_workflow()` + `fit()` on the full data. *Verified.*
  - P5: `vfold_cv()` consumes the RNG — rset construction is a stochastic
    stage. *Verified.*
  - P6: `tune_grid()` is net-zero on `.Random.seed` (reconfirms RR01).
    *Verified.*

## Answers

### 1. Is re-running the tuning procedure on the complete dataset the correct final-fit path?

**Yes.** The argument for: the nested estimate characterizes the *procedure*
"given a dataset, resample it per the inner specification, tune, select,
fit" — and the deployment target of that procedure is the full dataset. This
is the same logic that justifies ordinary k-fold CV followed by a full-data
refit: every model the CV estimate ever scored was trained on (k−1)/k of the
data, yet the deployed model is trained on all of it, and the estimate is
read as (slightly conservative) for it. Nested CV inherits the identical
convention one level up: this is the refit step as described in the standard
treatments (Varma & Simon 2006; Cawley & Talbot 2010), and it is exactly what
`mlr3`'s `AutoTuner` does when trained on the full task and what
scikit-learn's documented pattern (score the search by cross-validation, then
fit the search on all rows) does. M05 is the ecosystem-standard operation,
not an invention.

The argument against, stated at its strongest: with a fixed inner `v`, the
final run's resamples have absolute analysis-set sizes no resample in the
nested run ever had (roughly `n·(v−1)/v` versus `n·(v_out−1)/v_out·(v−1)/v`),
so the tuning run that produces the deployed model is not, at fixed absolute
size, any run the estimate averaged over. Three replies. First, this size
mismatch is not introduced by M05 — it is inherent to resampling itself and
already present *inside* the validated loop (inner analysis sets are smaller
again than the outer analysis sets whose performance they are used to
optimize). Second, the direction of the induced bias is the safe one: since
performance is generically non-decreasing in training-set size, the nested
estimate is mildly *conservative* for the full-data procedure — the
acceptable direction for a reported claim, and the one every CV user already
accepts. Third, the mismatch is a feature for the model itself:
size-sensitive hyperparameters (regularization strength, neighborhood sizes)
should be selected at the deployment size, which the full-data run does and a
size-matched run would not.

The alternative — matching the loop's absolute resample size by subsampling
the data for the final tuning run, or adjusting `v` to compensate — is not
worth its complexity: it has no literature behind it (the GP5 instinct
applies), it discards data at the one step whose entire product is the
deployed model, it adds a knob where GP3 wants one path, and the thing it
preserves (procedure identity at fixed absolute size) is not what the nested
estimate estimates anyway. **Reject the alternative; the design is correct.**

### 2. Does IP1 permit this, on the text quoted?

**The intent permits it; the text as written does not. An amendment is
needed.** Taking the clauses in order:

IP1's first sentence — "The outer assessment set never influences anything
upstream of its own scoring" — is satisfied vacuously by the final fit: the
final-fit path has no outer assessment set and performs no scoring, so there
is no boundary to leak across. The maintainer's reading — that IP1 governs
estimation of a performance claim, and a fit producing no estimate is outside
it — is sound as a matter of what leakage *is*: leakage is a property of an
estimate whose evaluation data influenced its training. No estimate, no
leakage. This is also the only reading under which the final fit is possible
at all, since a trained model's preprocessing must be estimated on its
training data, and its training data is by definition every row.

But the middle clause is written as an unconditional prohibition —
"preprocessing is estimated on analysis data, never on the full dataset" —
and explicitly extended to the final-fit path. Under M05 the final workflow's
preprocessing *is* estimated on the full dataset. A literal audit of IP1
against the shipped code flags a violation, and this repo's rules say
inviolable principles are audited literally, with changes requiring a
recorded decision. The clause does have a true and important reading for the
final-fit path: **within the final tuning run**, preprocessing must be
estimated per-resample on each analysis set — never once on the pooled data
before resampling (the classic preprocess-then-CV leak). P1 verifies tune
honors this. If that is what the clause meant, its wording overshoots by
covering the final model's own training preprocessing too.

So: text and intent diverge, and since M05's design is correct, it is the
text that must move. Record a decision entry amending IP1's middle clause so
that "never on the full dataset" scopes to **preprocessing that feeds a
reported estimate** — e.g.: *"This binds the final-fit path as well as the
loop: any preprocessing that feeds a reported estimate is estimated on the
analysis set of the resample being scored, never on data that includes the
corresponding assessment rows. The final model's own training preprocessing,
which yields no estimate, is estimated on its training data — the full
dataset — and is outside this clause."* This is bound as BC2.

### 3. Is there an unnamed leakage path inside the final fit?

**No genuine leakage path was found; one optimism path exists and is Q7's
subject; one silent-wrongness (not leakage) hazard was found and is B1.**
Taking the brief's candidates:

- **Former outer-assessment rows inside the re-evaluated inner resamples:**
  not leakage. Those rows' former role carries no information into any number
  the package reports — the nested estimate is already computed and is
  untouched by the final fit, and the final fit reports no estimate of its
  own. "Row once used for assessment" is not a contaminant; contamination is
  directional (test → train *of the same estimate*), and there is no estimate
  here for it to flow into.
- **Preprocessing inside the tuning run:** *verified*, not inferred — P1
  shows tune 2.1.0 under `control_grid(allow_par = FALSE)` preps the recipe
  separately per resample on that resample's analysis set (extracted
  normalization means equal analysis-set means, differ per fold, and do not
  equal the full-data mean). So the internal tuning run has no
  preprocess-then-resample leak, **provided** M05 passes the unprepped
  workflow and the rset to `tune_grid()` — which T2's design does. What is
  inferred rather than executed: that the same holds for formula and
  variable preprocessors (they carry no estimated state, so there is nothing
  to leak) and for `fit_resamples()` (shares the loop machinery RR01 read in
  source).
- **A derivable number that is optimistically biased while looking honest:**
  exactly one, and it is real: `collect_metrics()` / `show_best()` called on
  the **stored tuning run** yields the full-data resampling estimate at the
  selected configuration — plain (non-nested) CV, subject to selection
  optimism over the grid, wearing tune's authoritative `tune_results`
  clothes. That is Q7's question and is answered there. A second, lesser
  path — `extract_workflow()` then `predict()` on the training rows
  (resubstitution) — is outside any package's reach and identical to the
  situation after `tune::last_fit()`; the Q8 documentation covers it. The
  exposed seeds leak nothing statistical.

The unnamed hazard that is *not* leakage: re-evaluation of the stored
`inside` call in an environment where its free variables have changed
silently produces a different design (P3d). See B1 and BC5.

### 4. Does D-011's RNG contract transfer unchanged?

**It transfers, with one addition the brief did not anticipate: the inner
rset construction is a third stochastic stage, and it must run inside the
tuning seed's scope.**

The RR01 finding that a fold's outcome is a function of exactly two RNG
states carries over cleanly: `tune_grid()` derives its substreams from the
state at its entry and restores on exit (reconfirmed, P6), and the final
`fit()` — like `last_fit()` before it — consumes the ambient stream (P2:
same-seed identity, stream advancement, seed sensitivity, all verified with
ranger). So two kind-pinned seeds at the two stage boundaries is the right
shape, and RR01's Q5 argument for two-rather-than-one (the sufficiency of
one seed rests on tune's restore discipline, which IP2 declines to promise
across tune versions; a dedicated fit seed makes the coupling impossible by
construction) applies verbatim. `set_fold_seed()`/`restore_rng()` reuse
verbatim is correct, including the fresh-session guard (the entry
`sample.int()` auto-initializes `.Random.seed`; the `exists()` check handles
the no-state snapshot).

The addition: `nested_tune_grid()` received pre-built resamples, but
`nested_final_fit()` **builds** its rset by evaluating the stored `inside`
call, and `vfold_cv()` consumes the RNG (P5, verified). If that draw ran on
the caller's ambient stream — before or between the seeds — every same-seed
identity test would still pass (the whole call remains deterministic in the
entry state), but the exposed-seed hand-replication contract would silently
break: the result would not be reproducible from the two seeds alone, which
is the property D-011's contract exists to provide, and no test in the
planned suite would catch the weakening. The fix costs one line of ordering:
apply the tuning seed first, then evaluate the `inside` specification, then
call `tune_grid()`. The documented replication recipe then reads naturally —

```
set.seed(tuning_seed, kind = "Mersenne-Twister",
         normal.kind = "Inversion", sample.kind = "Rejection")
inner  <- <inside specification>(full_data)   # e.g. vfold_cv(v = 3) on all rows
tuned  <- tune_grid(object, inner, grid = grid, metrics = metrics,
                    control = control_grid(allow_par = FALSE))
final  <- finalize_workflow(object, select_best(tuned, metric = <first metric>))
set.seed(fit_seed, <same kind pin>)
fit(final, full_data)
```

— and two remains the right number, with the tuning seed's scope defined as
"construct the resamples and tune". This ordering, plus exposing both seeds
on the returned object (parity with `nested_results`, and the replication
contract is unusable without them), is bound as BC1. Nothing else about a
full-data run perturbs RR01's reasoning: tune's positional-substream
sensitivity binds the rset's row order, which is deterministic under the
seed.

### 5. Can M05's two oracles be genuinely independent?

**Yes — (a) escapes RR01's hazard under the same discipline RR01's BC9
imposed, and (a) and (b) are two genuine oracle types. A third, cheap strand
is available and worth adding; mlr3 is not worth its cost.**

Oracle (a), the hand-written pipeline, becomes a restatement of the
implementation exactly when it reads the seeding off the implementation. It
escapes when it derives everything from the *documented contract*: its own
`set.seed(S)` and its own `sample.int(.Machine$integer.max, 2)` in the
documented layout, asserted equal to the object's exposed seeds; its own
rset built under the first seed per the documented recipe; nothing read off
the returned object. Written that way it independently exercises the seed
layout, the rset-construction placement (Q4's addition — the oracle is the
test that would catch its violation), argument plumbing, metric resolution,
selection, finalization, and the fit. Its stated blind spot is the same as
RR01's: a defect in the contract itself, shared by docs and implementation,
passes. The mitigation is the same: the contract is what this review has now
examined. Bound as BC3.

Oracle (b), the one-row-grid invariant, is a different type, not the same
type twice: it nulls the selection stage entirely and pins the
finalize-and-fit tail against the identity "tuning over one candidate selects
that candidate", failing under a different class of defect (tail plumbing,
finalization) than (a) (seed/contract layout, selection). The pair parallels
M02's accepted structure (reference implementation + invariant), and GP2 is
satisfied.

The residual correlated exposure — both strands share tune and the two-seed
scheme — has a cheaper remedy than an external framework:
**`tune::fit_best()`**, tidymodels' own independently written "select,
finalize, fit on the full data" path. Verified viable by execution (P4):
under the same seed its ranger predictions are `identical()` to the hand
finalize-and-fit, and it needs `save_workflow = TRUE` only on the *test's*
hand-run `tune_grid()` — no package change, no new dependency. A third
assertion in the oracle file (hand-tune under seed 1, then
`set.seed(fit_seed)` + `fit_best()`, asserted identical to
`nested_final_fit()`'s predictions) pins the tail semantics with code neither
the package nor the test author wrote. Recommended at consider level.

`mlr3`'s `AutoTuner` is the right operation conceptually, but exact identity
is unattainable — its resampling instantiation and RNG consumption differ
from rsample/tune's, so the check degrades to coarse agreement of the
selected hyperparameter under a deterministic setup, while pulling at least
three Suggests packages (`mlr3`, `mlr3tuning`, `paradox`) through the
dependency gate. Rejected: less power than the `fit_best()` strand at
strictly higher cost.

### 6. How should IP2 be tested for this path?

All on `ranger` behind `skip_if_not_installed()` — the repo's lesson stands:
a deterministic engine passes every one of these vacuously, wrong schemes
included. The tests:

1. **Same-seed identity:** two `nested_final_fit()` calls under one
   `set.seed()` → `expect_identical()` selected parameters, predictions from
   the extracted workflow on fixed rows, and the stored tuning run's metrics.
   Establishes the whole path — rset construction included — is a pure
   function of the entry state.
2. **Seed sensitivity:** a different seed changes the predictions. Guards
   against the vacuous pass.
3. **Net-zero exit:** `.Random.seed` and the `RNGkind()` triple identical
   before and after; a follow-up `runif()` matches a run with the call
   absent; the fresh-session branch (no `.Random.seed` in the global
   environment) neither errors nor leaves the session without valid state.
4. **Error-path restoration, non-vacuously:** the failure must be raised
   *after* the entry snapshot. The argument checks fire before it, so a
   check-triggered error tests nothing about restoration; force a failure
   inside the guarded region instead — an `inside` call that errors on
   re-evaluation, or a grid on which every candidate fails so
   `select_best()` raises — and assert entry state and kind are restored.
5. **Ambient-kind independence:** the same seed with the caller's generator
   on L'Ecuyer-CMRG versus default Mersenne-Twister produces `identical()`
   results — what the kind pin buys, and the serial simulation of a fresh
   worker.

What these establish: the result is reproducible from the entry state alone,
insensitive to the caller's generator configuration, and the call is
side-effect-free on the caller's RNG — on this platform, R version, and tune
version, for engines whose randomness flows through R. What they do not
establish, stated rather than implied: identity across R versions, platforms,
or tune versions (IP2's own disclaimers); anything about engines that bypass
R's generator; anything about parallel backends — this path has no fold loop
to parallelize, and the internal run is pinned sequential by
`control_grid(allow_par = FALSE)`, a pin asserted by code review rather than
by observable output. Items 4 and 5 are the sharpenings beyond AC3 as
written and are bound as BC6.

### 7. What may the returned object carry, under IP3?

**Store the tuning run: it is a provenance benefit worth the risk, with two
mitigations that keep IP3's boundary intact.** Grounds:

- IP3's text forbids the API *presenting* an estimate as the model's
  property. A stored object the user must reach into, on which they call
  tune's own generics, is the user operating tune on a tune object — the
  package has presented nothing. The planned refusals (no
  `collect_metrics()`, `show_best()`, or `select_best()` method for
  `nested_final_fit`, erroring as D-010's class does) are the right
  enforcement at the package's own surface and should stand.
- Removing the tuning run would not remove the hazard — a user can re-run
  the same tuning in three lines and get the same optimistic number.
  Omission prevents audit without preventing misuse.
- The stored run is load-bearing three ways: it is the reproducibility
  record of what selection saw (the analog of `nested_results` keeping
  `.selected`); the oracle file exercises it; and it enables the package's
  signature comparison — the final selection against the outer folds'
  `.selected`, where disagreement is exactly the instability DESIGN makes
  first-class.

The mitigations, bound as BC4: `print.nested_final_fit()` never displays any
numeric value derived from the stored tuning run (AC4's snapshot should be
checkable for this), and the roxygen names the number and the bias plainly —
metrics computed from the stored run are selection-time quantities,
optimistically biased as a performance claim, and the thing to report is the
nested estimate. A differently-named accessor is defensible but not required
pre-1.0: a documented slot is enough, and if an accessor is added later it
should be named for what the object is (an `extract_`-family verb), not a
euphemism. Consider level.

### 8. What exactly should the documentation say?

Substance for the roxygen section (the implementer may adapt wording, not
content):

> Report the estimate from `nested_tune_grid()`'s `collect_metrics()` as
> this model's performance. That number is an approximately unbiased — if
> anything slightly conservative — estimate of how the whole tune-and-fit
> procedure that produced this model performs on new data from the same
> population, measured on data no part of the procedure ever touched. The
> model in hand has no honest number of its own: everything computable from
> its training data, including the resampling metrics inside the stored
> tuning run, was consumed by selection or fitting and is optimistically
> biased as a performance claim. If the outer folds selected different
> parameters from each other, report that too — the nested estimate covers
> the procedure across that instability, not the single configuration this
> model happens to carry.

What a user can still get wrong after reading it: (i) reading the nested
estimate as *conditional on this model's selected hyperparameters* — it is
marginal over selection, and no per-configuration claim is available;
(ii) reporting the stored tuning run's CV number anyway because it is "for
the actual model" — the sentence naming it biased is the defense, but the
number remains reachable; (iii) analyst-level selection — re-running the
whole pipeline until the nested estimate looks good — which no package can
prevent; (iv) assuming the estimate transfers to deployment data that is not
exchangeable with the training data, or to retraining at a different size;
(v) reading "slightly conservative" as license to prefer the higher inner
number.

## Beyond the brief

- **B1 — the stored `inside` call has no environment, and re-evaluation can
  silently diverge.** Both constructors store the bare language object
  (P3a/P3e); the construction-time environment is not stored. At
  final-fit time, a specification like `vfold_cv(v = k)` errors if `k` is
  gone (P3c) and — worse — silently builds a *different* design if a
  different `k` is in scope (P3d, verified: v = 10 where the design was
  built with v = 4). The failing case must be caught and re-raised as an
  informative `cli_abort` naming the stored call (a new branch under AC5's
  umbrella; bound as BC5). The silent case is undetectable in principle
  from the design object alone; the defense is documentation — the roxygen
  should say the specification is re-evaluated at call time and that
  literal arguments (`vfold_cv(v = 3)`) are the safe form. Same-seed
  reproducibility is unaffected either way.
- **B2 — repeated-call identity.** As with `nested_tune_grid()`, two
  consecutive `nested_final_fit()` calls with no `set.seed()` between them
  return identical results (net-zero corollary). Document, as the loop's
  roxygen does.
- **B3 — print could surface final-vs-fold selection disagreement.** The
  final selection disagreeing with some or all of the outer folds'
  `.selected` is exactly the instability DESIGN makes first-class, and the
  moment of deployment is the moment a user should see it. A pointer line in
  `print.nested_final_fit()` (the selected parameters are already shown;
  add "compare `res$.selected` from the nested run") costs one bullet.
  Maintainer's call; not bound.
- **B4 — `fit_best()` probe results** (P4) are recorded above under Q5; the
  strand needs `save_workflow = TRUE` only in the test's own `tune_grid()`
  call.

## Recommendations

1. **Apply — ship the full-data re-tune as designed** (Q1). The resample-size
   discrepancy is inherent to resampling, its bias direction is conservative,
   and the operation matches the standard refit step and mlr3's.
2. **Apply — record a decision entry amending IP1's middle clause** to scope
   "never on the full dataset" to preprocessing that feeds a reported
   estimate, with the final model's training preprocessing explicitly outside
   it (Q2; BC2). The design is right; the text must catch up before an IP
   audit reads the implementation as a violation.
3. **Apply — construct the inner rset inside the tuning seed's scope** and
   document the replication recipe with that step included; expose both seeds
   on the returned object (Q4; BC1).
4. **Apply — write oracle (a) with contract-derived seeds** — own
   `set.seed()` + `sample.int(.Machine$integer.max, 2)`, own rset build,
   nothing read off the returned object (Q5; BC3). With that discipline,
   (a) and (b) are two genuine oracle types and GP2 is satisfied.
5. **Consider — add a `tune::fit_best()` strand to the oracle file** (Q5,
   B4): verified viable, no dependency change, pins the finalize-and-fit tail
   with independently written code.
6. **Reject — an mlr3 `AutoTuner` oracle:** exact identity is unattainable
   across frameworks, so it degrades to coarse agreement while pulling three
   or more Suggests packages through the dependency gate; the `fit_best()`
   strand buys more at no cost.
7. **Reject — size-matched final tuning** (subsampling or adjusted `v` to
   match the loop's absolute resample sizes): no literature basis (GP5),
   discards data at the one step whose product is the deployed model, and
   adds a knob against GP3.
8. **Apply — keep the tuning run stored**; print shows no number from it and
   the roxygen names its bias (Q7; BC4). The planned method refusals stand.
9. **Apply — wrap the `inside` re-evaluation** so a failure aborts
   informatively, naming the stored call; document that the specification is
   re-evaluated at call time and literals are the safe form (B1; BC5).
10. **Apply — the RNG suite of Q6**, including the ambient-kind test and the
    guarded-region error-path test (BC6); everything on ranger.
11. **Consider — an `extract_`-family accessor for the stored tuning run**
    (Q7): a documented slot suffices pre-1.0; if added, name it for what it
    is, never a euphemism.
12. **Consider — a print pointer from the final selection to the outer
    folds' `.selected`** (B3).

## Binding criteria

Tolerances: every equality below is exact (`identical()` /
`expect_identical()`), same process, same platform, same package versions —
no numeric tolerance is granted or needed.

- BC1: `nested_final_fit()` draws its two seeds in one
  `sample.int(.Machine$integer.max, 2)` call at entry; the kind-pinned tuning
  seed is applied **before** the stored `inside` specification is evaluated,
  which is before `tune_grid()` runs; the kind-pinned fit seed is applied
  immediately before the full-data `fit()`; both seeds are exposed on the
  returned object; and the roxygen states the hand-replication recipe with
  the rset-construction step inside the tuning seed's scope.
- BC2: Before M05 merges, `cairn/DECISIONS.md` carries a decision entry
  reconciling IP1's middle clause with the shipped behavior — either amending
  the clause so "never on the full dataset" scopes to preprocessing that
  feeds a reported estimate (with the final model's training preprocessing
  explicitly outside it), or recording the maintainer's reading that the
  existing text already permits it. The entry names IP1 and M05.
- BC3: The reference-implementation oracle derives its expected seeds from
  the documented contract via its own `set.seed()` and
  `sample.int(.Machine$integer.max, 2)` call, asserts them equal to the
  object's exposed seeds, constructs the inner rset itself under the first
  seed per the documented recipe, and reads neither seeds nor resamples off
  the returned object.
- BC4: `print.nested_final_fit()` output contains no numeric value derived
  from the stored tuning run, and the roxygen states that metrics computed
  from the stored tuning run are selection-time quantities, optimistically
  biased as a performance claim, naming the nested estimate as what to
  report instead.
- BC5: A stored `inside` call that fails to re-evaluate at final-fit time
  (at minimum: a free variable absent from the evaluation environment) is
  raised as a `cli_abort` naming the stored call, fired by a test; the
  roxygen states that the specification is re-evaluated at call time.
- BC6: The error-path RNG-restoration test triggers its failure after the
  entry snapshot (inside the guarded region), not via argument validation;
  and a test asserts `identical()` results for the same seed whether the
  caller's generator at entry is default Mersenne-Twister or L'Ecuyer-CMRG.
