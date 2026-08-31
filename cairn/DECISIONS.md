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

### D-015 (2026-07-26): IP1's middle clause is narrowed to preprocessing that feeds a reported estimate — amends the principle text D-004 classified, on RR02's finding

**Context:** IP1 has read since the design interview that preprocessing "is
estimated on analysis data, never on the full dataset", and says explicitly that
this binds the final-fit path. M05 ships that path, and a trained model's
preprocessing must be estimated on its training data, which for the final model
is every row. RR02 (question 2) found the intent and the text diverge: the
maintainer's reading — that IP1 governs estimation of a performance claim, and a
fit producing no estimate is outside it — is sound as a matter of what leakage
is, but the clause as written is an unconditional prohibition, so "a literal
audit of IP1 against the shipped code flags a violation". The clause does have a
true reading for the final-fit path — within the final tuning run, preprocessing
must be estimated per resample, never once on pooled data — which RR02 verified
tune 2.1.0 honours by extracting per-fold normalization means.

**Decision:** IP1's middle clause is narrowed to the text RR02 proposed: any
preprocessing that feeds a reported estimate is estimated on the analysis set of
the resample being scored, never on data that includes the corresponding
assessment rows; the final model's own training preprocessing, which yields no
estimate, is estimated on the full dataset and is outside the clause. Considered
and rejected: recording that the existing text already permitted it (nothing in
the principle set moves, but the next audit hits the same apparent contradiction
and the clause stays wrong on its face); changing M05's design to obey the
literal text (RR02 rejects it as statistically wrong — a trained model's
preprocessing has nowhere else to come from — and it would send M05 back to
planning).

**Consequences:** IP1 keeps its full force everywhere leakage can occur and
stops forbidding a correct operation. The narrowing is what makes M05
implementable without an IP violation, and it is the first amendment to an
inviolable principle in this repo — made at the user's explicit decision, as the
IP/GP rule requires. Nothing else in the principle set moves; IP1's number
stays.

### D-016 (2026-07-26): The tuning seed's scope includes building the resamples — amends the RNG contract D-011 fixed, on RR02's finding of a third stochastic stage

**Context:** D-011 settled the reproducibility contract for `nested_tune_grid()`
as two kind-pinned seeds per fold — one for tuning, one for the outer fit —
because a fold's outcome hangs on exactly two RNG states. `nested_tune_grid()`
receives its resamples already built. `nested_final_fit()` does not: it builds
its inner `rset` by evaluating the design's stored `inside` specification, and
RR02 verified by execution that `vfold_cv()` consumes the RNG. That draw is a
third stochastic stage D-011 never had to place.

**Decision:** The tuning seed's scope is defined as "construct the resamples and
tune": the kind-pinned tuning seed is applied first, the `inside` specification
is evaluated second, `tune_grid()` runs third. Both seeds are exposed on the
returned object, and the documented hand-replication recipe includes the
rset-construction step inside the tuning seed's scope. Two seeds remains the
right number — RR02 reconfirmed that `tune_grid()` is net-zero on
`.Random.seed` and that a plain `fit()` consumes the ambient stream exactly as
`last_fit()` does, so RR01's argument for two-rather-than-one carries over
verbatim.

**Consequences:** D-011's two-seed contract is unchanged for
`nested_tune_grid()` and extended, not replaced, for any function that builds
its own resamples — the later parallelism milestone and any
`nested_tune_bayes()` inherit this clause. The failure it prevents is silent:
RR02 notes that with the draw on the caller's ambient stream "every same-seed
identity test would still pass" while the exposed-seed replication contract
broke, so the guard is the contract-derived oracle (BC3) rather than a
reproducibility test.

### D-017 (2026-07-26): `knitr` and `rmarkdown` join Suggests as the vignette builder — the first non-test addition to the Suggests set D-006 opened

**Context:** M06 ships the long-form guide IP3 obliges the package to carry, and
that obligation is discharged only if the guide's claims stay true — which the
milestone enforces by having every number in its prose produced by a chunk that
executes at build, so drift fails the check rather than aging silently. The
package has carried no vignette infrastructure at all: no `vignettes/` directory
and no `VignetteBuilder` field, so there was nothing to execute chunks with.

**Decision:** `knitr` and `rmarkdown` join Suggests and DESCRIPTION declares
`VignetteBuilder: knitr`. Considered and rejected: Quarto vignettes (better
output, but they require the `quarto` binary on the build machine — a heavier
requirement for contributors and for CRAN's check farm than two pure-R
packages); shipping the guide as static prose with hand-typed output (no
build-time execution, so the drift guard that keeps IP3's obligation honest
could not exist).

**Consequences:** Install weight for users is unchanged — Suggests is not
installed by default, and `R CMD check` on CRAN has both. Check time grows by
the vignette's runtime, measured at roughly nine seconds for the full
design → tune → final-fit path. The worked example adds nothing further to the
dependency surface: `mtcars` is base R and `ranger` is already in Suggests
(D-012). The hard-dependency surface is untouched: rsample, cli, rlang, tune
(>= 2.0.0), workflows, parsnip.

### D-018 (2026-07-26): `mirai` is the outer-loop parallel backend and joins Suggests with `pkgload` — extends the dependency set D-017 last amended, and gives D-011's kind pin its first parallel consumer

**Context:** M07 makes `nested_tune_grid()`'s outer loop run its folds
concurrently. D-011 fixed the reproducibility scheme in anticipation of exactly
this — seeds drawn at entry, assigned by fold position, generator kind pinned
per fold — and D-016 recorded that "the later parallelism milestone" inherits
that clause. What was open was the backend. tune 2.x carries both `mirai`
(>= 2.4.0) and `future` (>= 1.33.0) in Suggests and dispatches through mirai,
going parallel only at `status()$connections >= 2`.

**Decision:** `mirai (>= 2.4.0)` joins Suggests as the sole parallel backend,
with `pkgload` beside it so tests can prime daemons during development.
Parallelism is enabled solely by the user calling `mirai::daemons(n)`;
`nested_tune_grid()` gains no argument, and the dispatch threshold mirrors
tune's `>= 2` connections. Considered and rejected at the M07 plan gate:
`future`/`future.apply` (mature and already common, but tidymodels is moving
off it, so the package would diverge from the ecosystem it delegates to);
base `parallel` (no new dependency, but PSOCK workers need everything exported
by hand and the fork path excludes Windows); a user-supplied mapper argument
(maximum flexibility, but a knob where GP3 asks for one obvious path).

**Consequences:** Install weight for users is unchanged — Suggests is not
installed by default, and the serial path is untouched when mirai is absent or
below threshold. The hard-dependency surface stays rsample, cli, rlang, tune
(>= 2.0.0), workflows, parsnip. RR03 verified by execution that D-011's kind
pin is load-bearing rather than precautionary: mirai starts every daemon on its
own L'Ecuyer-CMRG stream, so without the pin a worker would draw from a
different generator than the serial run, and with it results are `identical()`
to serial at every daemon count. One user-visible constraint follows and is
documented rather than engineered away: daemons are separate R processes, so
`nestedtune` must be installed in a library they can load — `devtools::load_all()`
alone does not reach them, and a stale installed copy makes daemons run stale
code while the host runs development code.

### D-019 (2026-07-26): `autoplot()` on `nested_results` is one method with a `type` argument, and `ggplot2` joins Imports with `vdiffr` in Suggests — settles the outer-level semantics D-010 deferred and extends the dependency set D-018 last amended

**Context:** D-010 refused `tune_results` inheritance and recorded that
`autoplot()` would therefore error, adding that "any of them that turns out to
be genuinely wanted is written deliberately, with outer-level semantics decided
at that point". M08 is that point. The object supports two genuinely different
views: what each outer fold selected — the instability DESIGN calls first-class
and nothing else in the ecosystem shows — and how the per-fold outer scores
spread. Registering a method for `ggplot2::autoplot()` normally requires
ggplot2 as a hard dependency, and the profile's test-doctrine allows testing a
plot with `vdiffr` precisely when the plot is the product.

**Decision:** One export, `autoplot.nested_results(object, type =
c("parameters", "performance"), ...)`, defaulting to the instability view;
`ggplot2` joins Imports and `vdiffr` joins Suggests. Considered and rejected at
the M08 plan gate: two separate exported functions (more discoverable, and each
gets its own help page, but it puts two names in a small namespace and abandons
the idiom every other tidymodels object answers to); the instability view alone
(smallest thing that earns the milestone, but the fold spread is then reachable
only through `collect_metrics(summarize = FALSE)`); `ggplot2` in Suggests with
the method registered lazily in `.onLoad()` (keeps the hard surface at six
packages, which is GP4's instinct, but it is machinery every reader must
understand and the vignette then needs the `requireNamespace()` guard whose
failure mode M06 was caught by); shipping a tidy data frame and no plot at all
(zero dependency cost, but it does not deliver the candidate).

**Consequences:** The hard-dependency surface becomes rsample, cli, rlang, tune
(>= 2.0.0), workflows, parsnip, ggplot2 — the first addition to Imports since
D-009, and the first that is not needed to compute a result. GP3's preference
for one obvious path over a knob is traded off deliberately: two views of one
object is the case where an argument is the honest answer, and tune's own
`autoplot()` sets the precedent GP1 asks the package to match. `show_best()`
and `select_best()` stay unregistered, so D-010's refusal is narrowed to those
two rather than overturned. Pre-1.0 the `type` values stay changeable without a
deprecation cycle (D-003).

### D-020 (2026-07-26): The parallel pre-flight timeout is an R option, `nestedtune.preflight_timeout` — narrows D-018's no-knob line to function arguments, and opens the package's option namespace

**Context:** M07's pre-flight probe bounds its round-trip at a hard-coded
`preflight_timeout_ms <- 30000L`, so a daemon that is merely slow — a loaded CI
runner, an antivirus-scanned Windows library — is reported as one that cannot
load the package (M07 review finding F3; loading `tune` alone in a cold daemon
measured 6.5 s). D-018 settled the parallel surface with a line this bumps
against: "Parallelism is enabled solely by the user calling `mirai::daemons(n)`;
`nested_tune_grid()` gains no argument", having rejected a user-supplied mapper
as "a knob where GP3 asks for one obvious path".

**Decision:** the bound is read from `getOption("nestedtune.preflight_timeout",
30000L)` and validated; `nested_tune_grid()` gains no argument, and M10 asserts
its formals are unchanged. This is the package's first user-facing option, so it
also fixes the namespace: `nestedtune.<snake_case>`, the R convention. Considered
and rejected at the M10 plan gate: a `nested_tune_grid()` argument (most
discoverable, but it contradicts D-018 outright and puts an infrastructural
control on a statistical signature); no knob at all, fixing only the message
(truest to D-018's "documented rather than engineered away", but it leaves a user
whose environment genuinely needs 60 s with no route at all).

**Consequences:** D-018 is narrowed, not superseded — its rejection was of a
*signature* knob, and that holds; what this permits is an out-of-band default
that the obvious path never requires a user to touch. GP3 is traded off
deliberately and narrowly: the option tunes infrastructure, never anything
statistical, so no result depends on it and the one obvious path is unchanged for
every user who ignores it. The default is unchanged at 30 s, so no existing
behaviour moves. Pre-1.0 the option name stays changeable without a deprecation
cycle (D-003).

### D-021 (2026-07-27): `R6` joins Suggests so a hang names the test file it stopped in — extends the dependency set D-020 last touched, and is the first addition that serves diagnosis rather than a result

**Context:** M14 makes the test suite say where it stopped. Under `R CMD check`
the suite's output goes to `testthat.Rout` and is dumped to the job log only at
the end, so every line arrives carrying the same runner timestamp — verified on
the hung macOS job of 2026-07-27, whose whole surviving dump is stamped
17:31:48. An in-band clock is therefore the only way a marker says how long the
suite sat in a file, and testthat's check reporter buffers, so the marker must
also reach `stderr()`, which is unbuffered. testthat exposes this through one
mechanism only: a `Reporter` subclass. Its R6 members are locked
(`cannot change value of locked binding for 'start_file'`, by execution), so
replacing a method on a stock instance is not available, and
`tools:::.check_packages_used_in_tests()` reports `'::' or ':::' import not
declared from: 'R6'` for the subclass.

**Decision:** `R6` joins Suggests, used only by `tests/testthat.R` to define
`HangTraceReporter`, which writes a timestamped `start`/`end` line per test file
to `stderr()`. Considered and rejected at the M14 implementation gate:
`ProgressReporter$new(file = stderr())` in a `MultiReporter`, which needs no
dependency and does name each file as it starts, but carries no clock — leaving
the surviving log able to say where the suite stopped and not how long it was
there — and duplicates testthat's whole progress display and results block into
the error stream.

**Consequences:** Install weight for users is unchanged in the strictest sense
available: `R6` is a hard dependency of `testthat`, so every machine that can
run this suite already has it, and no user who merely installs the package gains
anything to download. It is the first Suggests entry that supports neither a
result nor a document but the diagnosis of the suite itself; the hard-dependency
surface is untouched (rsample, cli, rlang, tune >= 2.0.0, workflows, parsnip,
ggplot2). D-018's no-knob line is not engaged — nothing here reaches an exported
signature.

### D-022 (2026-07-27): `pkgdown` is declared in `DESCRIPTION` as `Config/Needs/website` — extends the dependency set D-021 last touched, and is the first entry outside `Imports`/`Suggests`

**Context:** `DESCRIPTION:15` and `README.md:110` have advertised
`https://jmgirard.github.io/nestedtune/` since M06, and the URL 404s: there is no
`gh-pages` branch and `gh api repos/jmgirard/nestedtune/pages` returns HTTP 404
(observed 2026-07-27). `_pkgdown.yml` is committed and
`pkgdown::check_pkgdown()` reports "No problems found.", so the site's structure
is ready and only the build-and-publish path is missing. `pkgdown` is declared
nowhere in `DESCRIPTION`, so `r-lib/actions/setup-r-dependencies@v2` — which the
repo's other two checked workflows already use — has nothing to resolve.

**Decision:** `DESCRIPTION` gains `Config/Needs/website: pkgdown`, unpinned, and
`.github/workflows/pkgdown.yaml`'s dependency step declares `needs: website`.
Considered and rejected at the M17 plan gate: naming `any::pkgdown` in the
workflow's `extra-packages` line, which adds no `DESCRIPTION` field and needs no
entry here, but leaves the dependency legible only inside a workflow file — every
other tool this package leans on is discoverable from `DESCRIPTION`, and the
r-lib action exists to read exactly this field. A version floor
(`pkgdown (>= 2.2.0)`, the version that produced M17's local build evidence) was
also weighed and declined: nothing has yet shown an older builder behaves
differently, and a pin nothing needs is a pin nobody maintains.

**Consequences:** The user-facing install weight is unchanged and the
hard-dependency surface is untouched (rsample, cli, rlang, tune >= 2.0.0,
workflows, parsnip, ggplot2); `Config/Needs/*` is read by CI tooling and never
by `install.packages()`. It is the first declared dependency that lives outside
`Imports` and `Suggests` alike, and the first that serves neither a result, a
document shipped in the package, nor the diagnosis of the suite, but the
publication of documentation the package already contains. D-018's no-knob line
is not engaged — nothing here reaches an exported signature.

### D-023 (2026-07-30): The stored tuning run and the candidates it scored are reached by two new `extract_`-family generics, `extract_tune_results()` and `extract_scored_candidates()` — takes up the accessor D-014 left as a documented slot, and answers RR02 rec 11

**Context:** `nested_final_fit` has carried its tuning run since M05 as an
undocumented list slot; D-014 recorded `extract_workflow()` as the door and
shipped nothing else, and RR02 Q7 (`cairn/reviews/archive/RR02-final-fit-path.md:320-324`)
rated an accessor "Consider" — "a documented slot is enough, and if an accessor
is added later it should be named for what the object is (an `extract_`-family
verb), not a euphemism". M21 then gave `nested_results` a `.grid` column naming
the candidates each outer fold scored, and the final fit gained no equivalent
even though `scored_candidates()` derives one from the slot it already holds.
Neither `tune` nor `hardhat` exports a generic for either quantity (verified
2026-07-30 against tune 2.1.0), so registering a method on an upstream generic
is not available and a new generic is the only route.

**Decision:** Two exported S3 generics, `extract_tune_results()` and
`extract_scored_candidates()`, each with a `nested_final_fit` method and a
default method that aborts as a classed nestedtune condition rather than letting
R's "no applicable method" reach the user. The candidates accessor returns
`scored_candidates()`'s table unchanged — parameters plus tune's `.config`
label — so one shape describes one concept on both classes. Considered and
rejected at the M22 plan gate: `extract_tuning()`/`extract_grid()` (shorter, but
`grid` already names the *request* stored at `attr(x, "grid")` on
`nested_results`, and reusing it for the candidates actually scored re-merges
the distinction M20 and M21 were spent separating); `extract_tuning_run()`/
`extract_candidates()` (reads better in prose, but hardhat's family names the
returned class — `extract_workflow()` returns a `workflow` — so a user guessing
from that idiom would not land here); a parameters-only candidate table
(cleaner, but forks the shape of a thing that already exists on `nested_results`
and drops the label that cross-references a row back into the tuning run);
plain non-generic functions (no dispatch machinery, but the whole `extract_*`
family is generic across tidymodels and a non-generic leaves no room for a
second class to answer).

**Consequences:** The package's export list gains two names and its namespace
gains two generics it owns rather than borrows — the first generics nestedtune
defines, where `collect_metrics()`, `extract_workflow()`, and `autoplot()` were
all methods on someone else's. Should hardhat or tune later define either name,
the collision is a masking conflict resolved by dropping ours; pre-1.0 that
costs no deprecation cycle (D-003). D-010's and D-014's refusals are untouched:
`collect_metrics()`, `show_best()`, and `select_best()` still have no method for
either class, and RR02 BC4's mitigation extends rather than relaxes — the
accessor that hands the tuning run over carries the same bias caution the print
method does. `nested_results` gets no method for either generic; the `.grid`
column stays its per-fold surface.

### D-024 (2026-07-30): Posture toward upstream's tune prototype — port the outer loop and retire nestedtune if tune wants it, otherwise stay a companion asking only that tune's `nested_cv` refusal remain top-level; no CRAN submission until the question is settled — closes the posture the design interview deliberately left open

**Context:** `cairn/DESIGN.md` has recorded this as open since 2026-07-25:
"Still open, deliberately not invented by the interview: posture toward
upstream's dormant prototype (tune#969), pending the maintainer's reply." The
ROADMAP carried the matching candidate row (G7), whose promotion condition was
the reply itself. topepo answered on tune#969: the `nested` branch is stalled on
time rather than by choice, tune's internals were rewritten about a year ago and
he does not believe the rewrite breaks it, his bandwidth opens after 2026-08-14,
and he is "very open to making this happen" and invited collaboration. He also
raised multi-level parallelism, and whether mirai or future schedules it better.
The question is therefore no longer "will upstream ship this" but "where should
the outer loop live", which the interview declined to answer without him.

**Decision:** Three clauses, decided at the user's gate. (1) If tune wants the
outer loop upstream, nestedtune ports it and is retired — the repo stays as
history and the standalone package stops being developed. (2) Otherwise
nestedtune continues as a companion, and the only thing it asks of tune is that
the `nested_cv` refusal stay a **top-level** refusal, with each
`inner_resamples` element still accepted as an ordinary `rset` — which is
already tune's behavior, so the ask costs tune no new API and no commitment
beyond not regressing. (3) No CRAN submission while clause (1) is live, so the
package is never published and then retired; this is a stated condition on the
posture and not a release plan, which stays user-declared (D-050). Considered
and rejected at the gate: porting the loop while keeping nestedtune for the
pieces tune may not want (the memory-lean constructor, per-fold selection
stability) — it splits maintenance across two homes for a benefit that is
speculative until tune says what it will take, and clause (1) does not forbid
proposing those pieces to rsample or tune separately; keeping nestedtune
standalone regardless (maximum design control, but it leaves the ecosystem
carrying two implementations of one loop, which is what D-002's boundary
exists to prevent); asking tune additionally for a supported pass-through for
forcing inner tuning sequential (safer against internal drift, but it asks a
maintainer for an API commitment on the first exchange).

**Consequences:** D-002's contract boundary is unchanged in substance and now
has a stated failure mode: the boundary holds *because* nestedtune delegates,
and clause (1) says what happens when the delegate wants the caller too. The
DESIGN.md "Still open" note is corrected in place under D-045's
current-knowledge rule, pointing here; git holds the original. The G7 candidate
row is retired from the ROADMAP with this entry taking ownership — search-first
sweeps for the posture question now land here, not on a row. The 2026-08-14
date is his stated availability, not a commitment either way, and nothing in
this entry obliges a reply by then. Clause (3) binds `/cairn-release` in the
sense that the release-walk is not to be entered while clause (1) is live; it
creates no release milestone and nominates nothing.

### D-025 (2026-08-28): nestedtune stays a package and moves into the tidymodels organization with the current maintainer retained — supersedes D-024's clause (1) and the submission condition clause (3) attached to it

**Context:** D-024 recorded three clauses at the user's gate: (1) if tune wanted
the outer loop upstream, nestedtune would port it and be retired; (2) otherwise
it stays a companion asking only that tune's `nested_cv` refusal remain
top-level; (3) no CRAN submission while clause (1) was live, so the package
could not be published and then retired. Clause (1) was written against an
unanswered question — topepo had said on tune#969 that the stalled `nested`
branch was a bandwidth problem and that he was open to collaboration, and
D-024's own Consequences noted the 2026-08-14 availability date was "his stated
availability, not a commitment either way". He and the user met, and the
question is now answered.

**Decision:** nestedtune remains its own package and its own repository. The
repository transfers to the `tidymodels` organization as `tidymodels/nestedtune`,
with Jeffrey Girard remaining owner and primary maintainer. The outer loop is
not ported into tune and the package is not retired, so D-024 clause (1) is
dead; clause (3) was conditioned on clause (1) being live and therefore lapses
with it, leaving release timing governed by nothing but the user's own
declaration (D-050). Clause (2) is superseded rather than confirmed: it framed
the alternative to retirement as staying an outside companion, and organization
membership is a third shape it did not anticipate. What clause (2) asked of tune
still holds and costs tune nothing — that the `nested_cv` refusal stay a
top-level refusal, each `inner_resamples` element still accepted as an ordinary
`rset` — but it is now an ask between packages in one organization rather than
across a boundary.

**Consequences:** D-002's contract boundary is unchanged, and the failure mode
D-024 attached to it — "clause (1) says what happens when the delegate wants the
caller too" — no longer has a live trigger; the boundary now holds because both
packages are maintained in the same place and duplicating tune's loop would be
visible to the same maintainers. D-003's deprecation waiver is untouched: it was
tied to version 1.0, not to a CRAN release, and D-024 explicitly rejected tying
it to the first release. The `cairn/DESIGN.md` line stating the old posture as
settled is corrected in place under D-045's current-knowledge rule, pointing
here; git holds both earlier versions. M28's plan is re-cut by the same planning
pass that writes this entry — the port inventory it was scoped to produce has no
recipient, and the inventory becomes a record of what to ask tune and rsample
for now that the asks are intramural. Nothing here schedules or nominates a
release: lifting clause (3) removes a prohibition and creates no window. The
transfer has not happened yet, so the repository URL, `DESCRIPTION`'s `URL` and
`BugReports` fields, the pkgdown configuration, the README badges, and the local
git remote all still name `jmgirard/nestedtune` and are corrected when the move
lands, tracked as a candidate row rather than planned against an address that
does not exist.


### D-026 (2026-08-28): the organization transfer is already complete — corrects the transfer-status facts D-025 stated an hour earlier, and supersedes nothing else in it

**Context:** D-025 was written from the user's description of the maintainer
meeting and from the local git remote, both of which read as future tense, and
it stated that "the transfer has not happened yet". The very next push — the one
that committed D-025 — was answered by GitHub with `This repository moved.
Please use the new location: https://github.com/tidymodels/nestedtune.git`, and
the push succeeded through the redirect. The move was therefore already done
when D-025 claimed it was pending. Independent confirmation through `gh` was
attempted and could not be obtained: the network timed out. The server's own
redirect on a successful authenticated push is the evidence this entry rests on.

**Decision:** The canonical repository is `tidymodels/nestedtune` as of
2026-08-28 or earlier; the exact transfer date is not established here and no
claim is made about it. D-025's substance — the package continues, the outer
loop is not ported, clause (3)'s submission condition lapses, the ask of tune is
unchanged — stands untouched; only its transfer-status facts are corrected. The
local git remote is re-pointed at the new URL in the same commit as this entry,
so pushes stop relying on a redirect.

**Consequences:** The candidate row D-025 created said the housekeeping work
"unblocks when the transfer completes" — that condition is met, so the row is
corrected in place under D-045's current-knowledge rule and is promotable now
rather than later; whether to promote it is the user's call and no milestone is
planned here. M28's Scope Out is amended in the same pass for the same reason.
`DESCRIPTION`'s `URL` and `BugReports`, `_pkgdown.yml`, and the README badges
still name `jmgirard/nestedtune`; those are package metadata rather than
tracking records, so they are not touched by this docs-only commit and belong to
whatever milestone takes the housekeeping row. Nothing here changes release
timing, which stays user-declared.


### D-027 (2026-08-30): `tidyverse/tidytemplate` joins `Config/Needs/website` and builds the site — extends the site-tooling declaration D-022 opened, and is the first dependency named by GitHub repository rather than by package name

**Context:** `_pkgdown.yml` has carried pkgdown's stock `template: bootstrap: 5`
since M17, where every tidymodels sibling surveyed at M32 sets
`template: package: tidytemplate` with the organization's `bslib` colour. The
builder for that theme is not on CRAN; it is installed from
`tidyverse/tidytemplate`. D-022 settled the analogous question for pkgdown
itself, declaring it in `DESCRIPTION` rather than in the deploy workflow's
`extra-packages` line.

**Decision:** `Config/Needs/website` reads `pkgdown, tidyverse/tidytemplate`, and
`_pkgdown.yml` names `package: tidytemplate` with `bootstrap: 5` and `bslib`
`primary`/`danger` at `#CA225E`. `.github/workflows/pkgdown.yaml` is unchanged:
its `setup-r-dependencies` step already names only `local::.` with
`needs: website`, so the DESCRIPTION field is what the deploy actually resolves.
Considered and rejected at the M32 question gate, on D-022's reasoning: naming
the builder in `extra-packages`, which would install it either way and leave the
DESCRIPTION field decorative. Also rejected: staying on the stock look, which
would drop the half of M32 that makes the site match the organization.

**Consequences:** The user-facing install weight is unchanged — `Config/Needs/*`
is read by CI tooling and never by `install.packages()` — and the hard-dependency
surface is untouched. It is the first entry in that field spelled as an
`owner/repo` reference rather than a CRAN package name, so the field now depends
on `pak` resolving GitHub-style entries, which the local install at M32 T3
exercised and the deploy job exercises on every publish. A theme package outside
CRAN also means the site's appearance can change under this repo without a
commit here; nothing pins it, on the same reasoning D-022 gave for declining a
pkgdown floor. The milestone file `cairn/milestones/M32-tidymodels-org-conventions.md`
holds the sibling survey the choice rests on.


### D-028 (2026-08-30): `air` is the repository's formatter, and the organization's `lock`, `pr-commands` and `format-suggest` workflows are vendored at their shared blobs — the first code-style convention `DESIGN.md` records, and it continues the organization convergence D-027 opened

**Context:** M32 took the tidymodels organization's community files and site
template; the three CI workflows every sibling runs were left for M33. One of
them, `format-suggest.yaml`, runs `air format .` on a pull request and posts
every difference as a review suggestion, so it presupposes a formatter this
repo did not have — `DESIGN.md`'s Conventions recorded no code style at all,
and nothing in `D-001` through `D-027` touches one.

**Decision:** `air` is the formatter. A root `air.toml` carries the siblings'
shape, `[format]` with `skip = ["tribble"]` (rsample and dials, minus rsample's
package-specific `exclude`), and `.Rbuildignore` gains rsample's
`^[\.]?air\.toml$` entry. `.github/workflows/lock.yaml`, `pr-commands.yaml`
and `format-suggest.yaml` are vendored byte for byte at the modal blob of the
nine-repository survey and are not adapted. Considered and rejected at the M33
question gate: taking `format-suggest.yaml` without adopting a formatter, which
on an unformatted tree posts a suggestion on nearly every line of every pull
request; and pinning the vendored files' actions to commit shas, which would
put each file off its modal blob.

**Consequences:** The user-facing dependency surface is untouched — `air` is a
standalone binary, declared in no `DESCRIPTION` field, and the three workflows
add no R package. Three actions now hold write-capable tokens under moving tags
(`r-lib/actions/pr-push@v2` under `contents: write`; `posit-dev/setup-air@v1`
and `reviewdog/action-suggester@v1` under `pull-requests: write` on a
`pull_request_target` trigger), where M17 review F10 pinned the pkgdown deploy
action by sha on that same reasoning; the divergence is carried as a ROADMAP
candidate rather than settled here, because vendoring at the shared blob is the
whole point of the convergence. None of the three files carries a `push` or
`pull_request` trigger, so `.github/ci-usage.py`'s filter rule does not reach
them. Adopting the formatter also re-pointed a test helper's `file:line` ledger;
the milestone file `cairn/milestones/M33-org-ci-workflows.md` holds the survey
and the reformatting evidence.


<!-- Template:

### D-00N (YYYY-MM-DD): Title

**Context:** 1–2 lines.
**Decision:** 1–2 lines.
**Consequences:** 1–2 lines. (Supersedes D-0xx, if any.)

-->
