# Decisions

_Append-only. Cross-cutting choices with rationale, numbered D-001 onward.
Never renumbered, never edited — supersede with a new entry. Genuine
rejections belong here ("considered X, rejected because…"); deferrals do
not ("not now" is a ROADMAP fact, not a decision). Milestone-local
decisions live in the milestone file._

_Each `### D-` heading names its subject and any entry it supersedes,
annotates, or narrows._

### D-001 (2026-07-25): Package named `nestedtune`, not `nestedcv`

**Context:** The repo was created as `nestedcv`, but CRAN already carries
`nestedcv` 0.9.0 (Myles Lewis, QMUL, published 2026-07-14, actively
maintained) — a caret/glmnet package for high-dimensional transcriptomics
with a published Bioinformatics paper. The CRAN distribution ambition makes
the name unavailable. Discovered during the design interview, before any code
was written.

**Decision:** The package is `nestedtune`. It follows the `finetune`
precedent — a package extending `tune` with what `tune` does not do — and is
free across all 24,393 CRAN packages as of 2026-07-25. Considered and
rejected: `nestcv` (confusable with the incumbent), `nestedsample` (implies
the rsample layer, which is not the contract boundary), `outerloop` and
`doublecv` (available and viable, but less searchable and less clearly
tidymodels-native respectively); keeping the name and dropping CRAN
(rejected — concedes CRAN for a permanently confusing search result).

**Consequences:** DESCRIPTION, namespace, and all user-facing text use
`nestedtune`. The git repository and working directory may keep the old name
without cost; only the package name is load-bearing. Renaming now costs
nothing, whereas renaming after vignettes, examples, and a pkgdown site exist
would touch every one of them.

### D-002 (2026-07-25): Contract boundary — orchestrate the outer loop, delegate inner tuning to `tune`

**Context:** `rsample::nested_cv()` builds nested resampling structures but
`tune` aborts on that class, so nothing in the ecosystem runs the loop; the
canonical how-to is an article that bypasses parsnip entirely. Evidence
ledgered in `references/tidymodels-nested-cv-gaps.md` (G1–G3, G5). The
enabling fact: tune's refusal applies only to the top-level `nested_cv`
object, while each `inner_resamples` element is an ordinary `rset` that tune
accepts.

**Decision:** nestedtune drives the outer loop, calls `tune::tune_grid()` on
each outer fold's inner `rset`, selects, fits on the outer analysis set, and
scores on the outer assessment set, returning a collected-results object.
Considered and rejected: owning the inner tuning engine too (rejected —
duplicates tune and doubles the surface needing verification, though tune#148
suggests a real speed argument for it); adding inference on the estimate
(rejected for now — contested statistics, parked as a ROADMAP candidate);
staying at the splits layer and only fixing memory (rejected — leaves the
actual gap unfilled, though it remains a candidate in its own right).

**Consequences:** `tune` becomes a hard dependency and its behavior sits
inside nestedtune's results, which is why GP1 governs divergence and why IP2
explicitly declines to promise stability across tune versions. The surface
stays small enough to verify against oracles.

### D-003 (2026-07-25): Pre-1.0 deprecation cycle waived

**Context:** cairn's universal rule is that breaking changes to public
behavior go through a deprecation cycle, unless the project is pre-1.0 and the
user explicitly waives it. nestedtune has no code, and its central return
object — the collected nested results — is the kind of design that is
typically wrong once or twice before it settles.

**Decision:** The deprecation cycle is waived while pre-1.0. Breaking changes
may ship without a `lifecycle::deprecate_warn()` cycle until version 1.0.0,
at which point the universal rule resumes. Considered and rejected: tying the
waiver to the first CRAN release instead of to 1.0 (a defensible alternative —
it tracks real users rather than a number, but it would end the freedom at
exactly the moment early feedback starts arriving).

**Consequences:** The API can be restructured cheaply during early
development. Early adopters carry the cost, so the waiver is stated in
DESIGN Conventions rather than left implicit, and it lapses automatically at
1.0 without a further decision.

### D-004 (2026-07-25): Inviolable principles bind the artifact; guiding principles bind the process

**Context:** At the principles phase, four candidates became inviolable on a
shared basis — each forbids a failure invisible in the output. Oracle
verification meets that same test and was nonetheless set as guiding, which
looked like an inconsistency and was raised as one.

**Decision:** The asymmetry is deliberate and stated as a classification rule:
IPs constrain what the package *does* (its artifact and outputs); GPs
constrain how it is *developed* (its process). Oracle verification is a
development discipline, so it is GP2 despite meeting the invisibility test.
Considered and rejected: promoting oracles to inviolable (would block any
numeric feature lacking two oracles, and nested-CV oracles are scarce);
narrowing the IP set instead (no specific inviolable was identified as
over-strong).

**Consequences:** Future principle candidates are classified by this rule
rather than case by case. A process discipline can be traded with stated
justification; an artifact property cannot. Recorded because the asymmetry is
otherwise readable as an oversight.

### D-005 (2026-07-25): Building a resampling structure is in scope where it is memory-lean — narrows D-002's boundary and the DESIGN.md exclusion

**Context:** DESIGN.md's Purpose & Scope listed "**Building the resampling
structure** — `rsample::nested_cv()` does that" as explicitly not nestedtune's
job, and D-002 rejected "staying at the splits layer and only fixing memory" as
the contract boundary while keeping it "a candidate in its own right".
Investigation for M01 found the memory blow-up is not inherent to rsample's
`rsplit` design: `nested_cv()`'s helper `inside_resample()` calls
`as.data.frame(src)`, materializing each outer fold's analysis set, so cost
scales with the *outer* fold count. A lean structure is buildable from public
rsample API (`make_splits()` + `manual_rset()`) with no fork and no compiled code.

**Decision:** nestedtune may build and export a nested resampling structure,
scoped to the memory-lean construction rsample does not provide. This narrows,
and does not overturn, D-002: orchestrating the outer loop (G1–G3, G5) remains
the contract, and this is an addition beside it, not a replacement. Considered
and rejected: keeping the exclusion and building the lean structure only inside
the orchestrator (leaves M01 with no user-visible deliverable and presupposes a
milestone not yet planned); upstream-first, waiting on rsample#283 (open since
2022-03-17 with "it isn't going to be absolute top priority" on the record).

**Consequences:** The DESIGN.md exclusion is corrected in place to say what is
now true. nestedtune duplicates a small part of rsample deliberately, which the
"delegate rather than reimplement" convention otherwise disfavours — the
justification is that the delegated version is the defect. Reporting the
diagnosis upstream is not foreclosed; it is a ROADMAP candidate.

### D-006 (2026-07-25): Dependency set for M01 — rsample hard, benchmarking tools dev-only

**Context:** The universal rule is that dependency changes go through a question
gate and are recorded here. nestedtune has no DESCRIPTION yet, so M01 sets the
initial surface. D-002 already commits to `tune` as the tuning engine, but M01
does not use it.

**Decision:** `rsample` in Imports. `testthat`, `lobstr`, and `mlbench` in
Suggests — `lobstr` because the memory measurement depends on accounting for
shared references, which `utils::object.size()` does not do, and `mlbench` for
`LetterRecognition`, the dataset rsample#283's own measurements use. `tune` is
deliberately **not** recorded yet; it is added by the orchestration milestone
that needs it. Considered and rejected: recording `tune` now (pulls a heavy
dependency into a milestone that never calls it); testthat-only with
`object.size()` and synthetic data (cheapest, but cannot measure the property
under test).

**Consequences:** `R CMD check` stays fast through M01. The orchestration
milestone carries its own dependency gate for `tune`. Suggests-only means the
memory benchmark must skip gracefully where `lobstr` or `mlbench` is absent.

### D-007 (2026-07-25): M02 adds tune, workflows, and parsnip to Imports — resolves the deferral D-006 recorded

**Context:** D-006 recorded `rsample` as M01's only hard dependency and
deliberately deferred `tune`, stating it "is added by the orchestration
milestone that needs it". M02 is that milestone. Its per-fold step calls
`tune::tune_grid()`, `select_best()`, `finalize_workflow()`, and `last_fit()`,
the last three of which operate on `workflow` objects.

**Decision:** `tune`, `workflows`, and `parsnip` join `rsample` in Imports.
`parsnip` is declared because offering the model abstraction is gap G3 — the
canonical article bypasses parsnip entirely, and closing that is part of the
package's premise. Considered and rejected: declaring `tune` alone and letting
`workflows`/`parsnip` arrive transitively (relies on a dependency's own
dependency list, which carries no contract); additionally declaring `yardstick`
and `dials` (likely reached only through tune's re-exports, so `R CMD check`
would flag them unused).

**Consequences:** The hard-dependency surface is settled for the package's core:
rsample, tune, workflows, parsnip. `R CMD check` gets slower from M02 onward.
Any further dependency takes its own gate and D-entry.

### D-008 (2026-07-25): The memory-lean constructor is `nested_resamples()` and carries rsample's `nested_cv` class — implements the scope D-005 opened

**Context:** D-005 put a memory-lean nested resampling constructor in scope, and
M01 ships it as the package's first export. Two things had to be settled before
any code: what to call it, and whether its return value should present itself as
an rsample `nested_cv` object. `tune` hard-aborts on class `nested_cv` (G1), so
the class choice also decides how the object behaves when handed to `tune`.

**Decision:** The export is `nested_resamples(data, outside, inside)`, mirroring
`rsample::nested_cv()`'s signature. Its return value carries
`c("nested_resamples", "nested_cv", <outer rset classes>)` plus the `outside`
and `inside` attributes rsample sets. Considered and rejected: naming it
`nested_cv` (masks `rsample::nested_cv()` whenever both are attached);
`lean_nested_cv` and `nested_rset` (leak an implementation property, and rsample
vocabulary, into a name the applied audience reads); carrying a distinct class
only (a user swapping the constructor into existing code would lose every method
dispatching on `nested_cv`, and `tune` would stop refusing the object loudly and
start mis-consuming it as a plain `rset` with a spare column).

**Consequences:** The object is a drop-in for `rsample::nested_cv()`'s. `tune`
refuses it exactly as it refuses rsample's, so G1 stays open until M02's
orchestrator, which consumes the inner `rset`s rather than the top-level object.
Pre-1.0 the name and class stay changeable without a deprecation cycle (D-003).

### D-009 (2026-07-25): `cli` and `rlang` join Imports — amends the dependency set D-006 fixed

**Context:** D-006 set M01's hard dependency surface at `rsample` alone. Writing
the scaffold surfaced two gaps it did not anticipate. The r-package profile's
`test-doctrine` slot requires user-facing conditions to be raised with
`cli::cli_abort()` rather than base `stop()`. And D-008 committed to
`nested_resamples(data, outside, inside)` mirroring `rsample::nested_cv()`,
whose `outside`/`inside` are *unevaluated expressions* — inspecting and
modifying them needs `rlang::is_call()`, `call_modify()`, and `caller_env()`.

**Decision:** `cli` and `rlang` join `rsample` in Imports. Considered and
rejected: `cli` alone, hand-rolling call inspection with base `substitute()` and
`match.call()` (reimplements rlang and diverges from how rsample does the same
job); neither, using base `stop()` (contradicts the profile's error-condition
rule outright).

**Consequences:** No practical weight is added — `rsample` already imports both,
so they are installed for every user of this package regardless, and `R CMD
check` time is unchanged. The hard surface for M01 is now rsample, cli, rlang;
D-007's tune/workflows/parsnip additions for M02 are unaffected.

### D-010 (2026-07-25): M02's orchestrator is `nested_tune_grid()` returning a standalone `nested_results` class — applies IP3 to the class choice, where D-008 applied compatibility

**Context:** M02 ships the package's second export, and two things had to be
settled before any code: what to call it, and whether its return value should
carry tune's `tune_results` class. D-008 faced the same pair for
`nested_resamples()` and answered "carry the upstream class" — there,
inheriting `nested_cv` kept every existing method working and kept tune's
refusal loud. The reasoning does not transfer: at the outer level the inherited
methods are not merely unhelpful, several are wrong.

**Decision:** The export is `nested_tune_grid(object, workflow, grid, metrics)`,
returning an object of class `nested_results` that does **not** inherit
`tune_results`. `collect_metrics()` is registered as a method on tune's
generic. No `control` argument in M02: `control_grid(allow_par = FALSE)` is
built internally. Considered and rejected: `tune_nested()` and `nested_tune()`
(both follow tune's `tune_<method>` shape, but nested CV is not a tuning method
— it wraps one — and neither leaves an obvious slot for a Bayesian inner loop);
inheriting `tune_results` (brings `show_best()` and `select_best()` along, which
would rank outer folds and return something authoritative-looking and
meaningless — the exact misreading IP3 exists to forbid).

**Consequences:** `show_best()`, `select_best()`, and `autoplot()` error as "no
applicable method" on a `nested_results` object rather than answering wrongly;
any of them that turns out to be genuinely wanted is written deliberately, with
outer-level semantics decided at that point. The `nested_tune_*` prefix is now
the orchestrator family's naming convention. Pre-1.0 all of this stays
changeable without a deprecation cycle (D-003).

### D-011 (2026-07-25): Per-fold RNG is two kind-pinned integer seeds drawn at entry, and `nested_tune_grid()` is net-zero on the caller's RNG state — settles the IP2 question RB01 escalated

**Context:** M02's driver must satisfy IP2 (same seed → same result regardless
of worker count or serial/parallel execution). Three schemes were on the table
and the question was escalated as RB01 rather than settled in session. RR01
verified by execution against `tune` 2.1.0 that tune >= 2.0.0 already derives
its own per-resample L'Ecuyer-CMRG substreams *even under
`control_grid(allow_par = FALSE)`*, restores the caller's state and kind
exactly, and that `last_fit()` alone consumes the ambient stream. A fold's
entire stochastic outcome is therefore a function of exactly two RNG states.

**Decision:** At entry `nested_tune_grid()` draws `2 * n_folds` seeds in one
`sample.int()` call from the caller's state and assigns them by fold position;
each fold seeds its tuning step and its outer fit separately with the RNG kind
triple pinned (`kind = "Mersenne-Twister"`, `normal.kind = "Inversion"`,
`sample.kind = "Rejection"`). Per-fold seeds are exposed on the results object
and the hand-replication contract is documented. On exit the caller's
`.Random.seed` and `RNGkind()` triple are restored exactly. Considered and
rejected: L'Ecuyer-CMRG streams via `parallel::nextRNGStream()` (RR01 verified
tune re-seeds from whatever state it finds, so provable stream independence
never reaches tune's substreams — it buys only a theoretical residue, for a
gated dependency and generator-kind surgery in an exported function);
inheriting the caller's stream (fails IP2 by construction once folds reorder).

**Consequences:** The kind pin is what makes a fresh parallel worker produce
the same numbers as a serial run under a caller who set a non-default
`RNGkind()` — the one latent defect in the unrefined scheme. Net-zero exit
deliberately diverges from M01's `nested_resamples()`, which leaves the stream
where `rsample::nested_cv()` would: the delegate being mirrored differs —
rsample's constructor advances the stream, tune's estimator restores it. Two
consecutive calls without an intervening `set.seed()` return identical results,
as `tune_grid()` 2.x already does. IP2 binds only randomness flowing through
R's RNG; engines that bypass it (kernlab's SVM, keras/torch) are outside its
reach under any R-side scheme. The verified probe table and full reasoning are
in `cairn/reviews/archive/RR01-rng-streams-outer-folds.md`.

### D-012 (2026-07-25): `tune` pinned at `>= 2.0.0` and `ranger` added to Suggests — amends the dependency set D-007 fixed, on RR01's evidence

**Context:** D-007 added `tune`, `workflows`, and `parsnip` to Imports with no
version floor. RR01 verified by execution against tune 2.1.0 that every
reproducibility guarantee M02 relies on — per-resample L'Ecuyer substreams
derived internally even under `allow_par = FALSE`, net-zero exit on the
caller's RNG state, `last_fit()` consuming the ambient stream — is tune 2.x
behavior. tune's own NEWS for 2.0.0 states that results differ from earlier
versions; the foreach-era 1.x seeded differently. Separately, RR01 verified
that with a deterministic engine every RNG test in M02 passes vacuously —
including under the schemes the review rejected — so the RNG suite has no power
without an engine whose randomness flows through R's RNG.

**Decision:** DESCRIPTION declares `tune (>= 2.0.0)` in Imports and `ranger` in
Suggests, the latter guarded by `skip_if_not_installed()` in the tests that use
it. Considered and rejected: no floor on tune (the IP2 evidence was gathered on
2.1.0 and does not transfer downward — a user on 1.x would get a driver whose
reproducibility claim was never tested against their tune); a heavier
stochastic engine such as `randomForest` or an xgboost path (ranger is
parsnip-native, single-threaded by default, and draws its seed from the R
stream, all verified); testing with deterministic engines only (leaves the
seeding untested by construction).

**Consequences:** The hard-dependency surface is rsample, cli, rlang, tune
(>= 2.0.0), workflows, parsnip. `ranger` in Suggests means the stochastic-engine
tests skip gracefully where it is absent, so CI without it stays green while
losing that coverage — the tests that matter most for IP2 are exactly the
skippable ones, which is a cost accepted rather than hidden. AC12 and AC13
(RR01's BC5 and BC6) are satisfiable as written; no "Deviations from RR01" row
is owed.

### D-013 (2026-07-25): `recipes` and `yardstick` join Suggests for the test engines — same reasoning D-009 used for `cli` and `rlang`, and leaves D-007's Imports rejection standing

**Context:** RR01's BC10 requires AC3's `fit_resamples()` invariant to run on an
engine with no randomness at all, so the equality is exact rather than
seed-contingent. parsnip's tunable model engines all pull an extra package
(glmnet, kknn, xgboost) or, in rpart's case, consume RNG by default through
`xval = 10`. A tunable recipe step with a plain `linear_reg()` lm model has no
RNG anywhere in the path.

`yardstick` is a separate need: it is not re-exported by `tune`, so without it
no test can construct a `metric_set()` and the `metrics` argument ships
untested.

**Decision:** `recipes` and `yardstick` join Suggests. The deterministic engine
is `step_pca(num_comp = tune())` ahead of `linear_reg()`; metric sets are built
with `yardstick::metric_set()`. Considered and rejected: `rpart` (ships with R,
but its default internal cross-validation draws from the RNG, so the RNG-free
property would depend on remembering `xval = 0` — fragile in exactly the tests
meant to catch fragility); testing only with `metrics = NULL` (avoids the
`yardstick` line, at the price of never passing a value to one of the
function's four arguments).

**Consequences:** No practical weight — both are hard Imports of `tune`
(`recipes` of `workflows` too), so they are installed for every user of this
package regardless, exactly as D-009 argued for `cli` and `rlang`. D-007's
rejection of `yardstick` and `dials` stands unchanged: it concerned *Imports*,
where `R CMD check` would flag them unused, and Suggests carries no such claim.
The deterministic test engine exercises the preprocessing path, which is also
where IP1's "preprocessing is estimated on analysis data" clause bites, so the
choice buys leakage-test relevance the model-only engines would not have.

### D-014 (2026-07-26): The final-fit path is `nested_final_fit()`, re-running the tuning procedure on the full data and returning its own object — extends to the model the separation D-010 applied to the results class

**Context:** IP3 and the DESIGN convention have said since the interview that the
final model is a separate object, and `nested_tune_grid()` tells users to "fit
that separately" without giving them a way to. Planning M05 had to settle three
things before any code: where the final model's parameters come from, what comes
back, and what it is called. The enabling fact is that both `nested_resamples()`
and `rsample::nested_cv()` store the inner specification as an unevaluated call
in `attr(x, "inside")`, so the design object alone is enough to re-run the
procedure on the complete dataset.

**Decision:** The export is `nested_final_fit(object, resamples, grid, metrics)`,
mirroring `nested_tune_grid()`'s signature. It re-evaluates the stored `inside`
specification against the full data, tunes, selects, finalizes, and fits on every
row, returning a `nested_final_fit` object holding the trained workflow, the
selected parameters, and the tuning run, reached with `extract_workflow()`.
Considered and rejected: reusing the outer folds' selections, e.g. by modal vote
(cheaper, and it reuses work already paid for, but no settled statistical basis
for the tie-break, and it makes the results object the source of the model —
the reading IP3 forbids); offering both routes behind an argument (GP3 prefers
one obvious path to a knob the literature cannot help a user turn); returning a
bare fitted workflow (every `predict()`/`extract_*()` for free, but nothing then
records the selection or states that this model's performance is not the nested
estimate, which DESIGN requires print methods to say); `fit_final()` and
`final_workflow()` as names (the first claims a very general name for a small
package, the second hides that an expensive tuning run happens inside).

**Consequences:** The package's naming gains a third shape beside
`nested_resamples()` and the `nested_tune_*` family D-010 established.
`collect_metrics()`, `show_best()`, and `select_best()` deliberately have no
method for the new class and error rather than answering — the same refusal
D-010 chose for `nested_results`, for the same reason. `predict()` and
`augment()` are not shipped in M05; `extract_workflow()` is the door, as after
`tune::last_fit()`. Pre-1.0 all of this stays changeable without a deprecation
cycle (D-003).

<!-- Template:

### D-00N (YYYY-MM-DD): Title

**Context:** 1–2 lines.
**Decision:** 1–2 lines.
**Consequences:** 1–2 lines. (Supersedes D-0xx, if any.)

-->
