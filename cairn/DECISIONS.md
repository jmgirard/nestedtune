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


### D-029 (2026-08-31): `dials` joins Suggests so the tests can name a parameter range — extends the dependency set D-028 last touched, and is the first addition whose package is already installed by an existing Import

**Context:** M34 forwards `param_info` to `tune::tune_grid()`, and the criterion
that verifies the forward is behavioural: a restricted range has to change what
every outer fold selects. Building that restriction means calling a `dials`
constructor — `dials::threshold()`, `dials::min_n()` — and `R CMD check`
reports an undeclared `::` import in `tests`. Two earlier tests already called
`skip_if_not_installed("dials")` without ever reaching into the namespace, so
the gap predates this milestone and was invisible until something used it.

**Decision:** `dials` joins `Suggests`. Considered and rejected: overwriting the
`range` field of the parameter object `tune::extract_parameter_set_dials()`
returns, which needs no declaration but binds the test to the internal shape of
a `dials` object rather than to its documented constructor — a test that breaks
under a behaviour-preserving change upstream, which the test doctrine calls a
defect in the test.

**Consequences:** No user gains an install: `tune` is in `Imports` and requires
`dials`, so every installation that can run this package already has it. The
`[dials::parameters()]` links the two new `@param` blocks carry now name a
declared package. `Suggests` remains what it was — used by tests, examples and
vignettes, never loaded by the package itself.


### D-031 (2026-08-31): `nested_results` carries tune's dplyr invariants, `dplyr` joins Imports, and the invariant set is every column the constructor writes — extends the dependency set D-029 last touched, and narrows what D-010's class promises for `[`

**Context:** #32 asks for the invariants tune declares on `tune_results`
(tune#221): a dplyr verb may reorder rows, and may add or reorder columns, but
an operation that adds or removes rows returns a bare tibble rather than an
object still describing the run its rows came from. `[.nested_results` (M04,
M20) answers half of that already — it sheds the class on a column subset and
recomputes the fold counts on a row subset — but it keeps the class on a row
subset, which is the case #32 names. Three things had to be settled before any
of it could be written: how `dplyr` is depended on, which columns constitute
the record an operation must leave alone, and how many methods to register.

**Decision:** `dplyr (>= 1.1.0)` joins Imports. The invariant set is every
column `new_nested_results()` writes — `splits`, the `id` columns, `.metrics`,
`.selected`, `.grid`, `.notes`, `.completed`, `.tuning_seed`,
`.outer_fit_seed` — all of which must be present and hold the same values, up
to a reordering of the rows, for the class to survive; extra columns are free
to arrive. One method is registered, `dplyr_reconstruct.nested_results()`, and
`[.nested_results` is rewritten to delegate to the same rule, which is the
behavior change: a row subset now returns a bare tibble. Considered and
rejected: `dplyr` in Suggests with the method registered at load time (it
keeps the hard requirement list shorter, but every test of these invariants
would skip vacuously on a machine without `dplyr` — and `tune`, already an
Import, requires `dplyr` anyway, so nobody's install changes); the narrower
invariant set of the five columns `has_results_columns()` names (it would let
a caller overwrite a recorded per-fold seed and keep an object still claiming
to be the run); registering `dplyr_row_slice()` and `dplyr_col_modify()` as
well (dplyr's defaults for both route through `dplyr_reconstruct()`, which is
also why `tune` registers only the one). The `vctrs` half of tune#221 stays
out and keeps its ROADMAP row.

**Consequences:** D-010 fixed `nested_results` as a standalone class so that
methods answering wrongly would error instead; this narrows the same class's
promise in the other direction — an object that cannot answer for a run stops
being one, rather than answering from a record that is no longer true of it
(IP4). `[` is the breaking part, waived pre-1.0 by D-003 and recorded in
`NEWS.md`. `dplyr` in Imports means the package may use its verbs internally
without further argument. Falsified by an invariant-respecting operation that
still yields an object whose record is untrue of its rows, or by a caller with
a legitimate need for a row subset that stays a `nested_results`.

### D-030 (2026-08-31): `event_level` is offered as its own argument rather than a `control` argument taking tune's settings object — the first slot of tune's control objects this package exposes, and the shape D-010's "no `control` argument" now takes

**Context:** M35 needed the caller to name which factor level counts as the
event. D-010 recorded that `nested_tune_grid()` takes no `control` argument;
that stance was written when nothing about tune's control objects had to reach
a caller at all, and the roxygen now states it publicly under "Differences from
calling tune directly", so what is settable and what is not is part of the
package's contract rather than an omission.

**Decision:** one narrow `event_level` argument on both orchestrators, passed
through untouched to `tune::control_grid()` on the inner run and, on
`nested_tune_grid()`, to a `tune::control_last_fit()` on the outer scoring fit.
No `control` argument. Considered and rejected: accepting tune's own
`control_grid()` object — of its ten slots, `save_pred`, `extract` and
`save_workflow` land on the inner `tune_results` that each fold record discards
once the fold succeeds; `parallel_over`, `backend_options` and `workflow_size`
are inert under the `allow_par = FALSE` this package forces; `pkgs` is
redundant serially and already guaranteed on the parallel path by the daemon
pre-flight; and `verbose` has nowhere to print from inside a daemon.
`event_level` was the one slot that changes a number the caller is shown.

**Consequences:** the "no `control` argument" stance survives, but as a
positive claim the docs make about each slot rather than a blanket refusal.
Every further slot a caller turns out to need is its own argument and its own
decision — `eval_time` is the next candidate and stays on the ROADMAP.
Falsified by a caller needing a slot other than `event_level`, or by the inner
tuning run being retained on `nested_results`, which would give `save_pred` and
`extract` something to act on.

### D-032 (2026-08-31): `vctrs` joins Imports, and the two doors that reach no generic — `rbind()` and `rename()` — get methods of their own — extends the dependency set D-031 last touched, and completes for vctrs the invariant D-031 fixed for dplyr

**Context:** #32 asked for the invariants tune declares on its results objects
through both of the interfaces a caller can reach them by. D-031 took the dplyr
half and parked the vctrs half. Three things had to be settled before the rest
could be written: how `vctrs` is depended on, which methods carry the rule, and
what to do about the operations that consult neither dplyr nor vctrs and so
reach no rule at all.

**Decision:** `vctrs (>= 0.6.1)` joins Imports, the minimum `tune` states;
`dplyr`, already an Import, requires a newer one, so no install changes.
`vec_restore.nested_results()` carries the same rule
`dplyr_reconstruct.nested_results()` carries, and the `vec_ptype2` and
`vec_cast` pairs among `nested_results`, `tbl_df` and `data.frame` are
registered to what each entry point was measured to reach.
`rbind.nested_results()` and `names<-.nested_results()` are written as well:
base `rbind()` and dplyr's `rename()` reach no generic either package
dispatches on, so without them an operation that doubles the rows, or renames
a column the record is kept in, returns an object still reporting the run it
came from. Considered and rejected: `vctrs` in Suggests with the methods
registered at load time (every test of these invariants would skip vacuously
where it is absent, and `dplyr` requires `vctrs` anyway); leaving `rbind()` as
rsample and tune both leave it, and saying so in the help page instead (an
untrue record is not traded away by documenting it).

**Consequences:** this package diverges from both upstream packages on three
operations, deliberately. `rbind()` stops returning a results object where
rsample's and tune's keep theirs; `vec_cbind()` keeps the class here, matching
what `bind_cols()` does through the other door, where rsample drops it; and a
plain table does not cast up to a `nested_results`, so combining one with a
bare tibble refuses rather than quietly producing a table. The divergences are
raised with the upstream maintainer on #32. `vctrs` in Imports means the
package may use its functions internally without further argument. Falsified
by a coherence requirement in vctrs that the registered pairs violate, or by a
downstream package depending on any of the three upstream behaviors.

### D-033 (2026-08-31): `vec_cbind()` keeping the class rests on vctrs' experimental `vec_cbind_frame_ptype()`, and stays there — annotates the `vec_cbind` divergence D-032 fixed, on RR04's review

**Context:** D-032 fixed that a column added through vctrs keeps the class
exactly as one added through `dplyr::bind_cols()` does, so the answer does not
depend on which door the caller used. Implementation then found that
`vec_cbind()` consults neither of the vctrs generics that decision assumed: it
builds its output container through `vec_cbind_frame_ptype()`, which vctrs
exports but documents as experimental and keyword-internal, saying to expect
changes. Whether a user-facing invariant may rest there was escalated as RB04
and reviewed in `cairn/reviews/archive/RR04-vctrs-cbind-hook.md`.

**Decision:** the method stays registered. The review found no other mechanism
— `vec_restore()` dispatches on the template, so with no frame-prototype
method none of this package's code runs on the call at all — and found the
generic load-bearing inside vctrs itself for its `sf` support, with an
unchanged contract since 2020. The dependency's two failure directions are
both acceptable: a generic that stops being consulted drops the class, which
is the honest direction and the behavior rsample and tune already have, and a
generic that stops being exported fails the package at load, which is loud.
Removing the method instead was rejected on the review's ground that it buys
with certainty the state keeping it merely risks. Two further recommendations
are scheduled rather than taken here: a check leg against development vctrs,
and asking upstream to stabilize the generic or to restore `vec_cbind()`'s
output against its first input's type the way `dplyr::bind_cols()` already
patches in; both live on a ROADMAP candidate row. Rejected outright: a
load-time self-check probing whether the class still survives, which would
warn users who cannot act on it.

**Consequences:** one method in the package depends on an interface its own
package marks unstable, and the test asserting the behavior is what names the
day it moves. `dplyr::bind_cols()` is itself `vec_cbind()` followed by the
same reconstruction this package registers, so the two doors were never as
separate as the divergence from rsample suggested. Falsified by a vctrs
release that changes the generic's contract rather than removing it — a
silently different container shape is the one failure direction neither guard
covers.

### D-034 (2026-08-31): `tibble` joins Suggests, for the tests alone — extends the dependency set D-032 last touched

**Context:** `R CMD check` warns that the test suite calls `tibble::tibble()`
and `tibble::as_tibble()` while the package declares no dependency on tibble.
The calls are in `tests/testthat/test-vctrs-compat.R` only; M37's acceptance
criteria name them by hand, because the invariants under test are about what
happens when a tibble meets a `nested_results`. No code under `R/` uses tibble
— `new_tbl()` builds one by hand for exactly this reason.

**Decision:** `tibble` goes into Suggests, not Imports. Suggests is where a
package declares what its tests need, and this is a test dependency; keeping
`R/` free of tibble keeps the choice `new_tbl()` made. Rewriting the tests to
avoid tibble was rejected: it would mean amending three acceptance criteria to
say something other than what the invariant is about.

**Consequences:** nothing changes for anyone installing the package — tibble
already arrives with dplyr and tune, both Imports — and a contributor running
the tests needs it present, which `devtools` installs from Suggests. Falsified
by a test needing tibble outside the compatibility file, which would be a
signal that `R/` wants it too.

### D-035 (2026-08-31): a column added through `vec_cbind()` keeps the class only where the results object is the first argument, and combining with a table whose columns differ produces a table rather than refusing — annotates the two divergences D-032 recorded, on the defect returns M37's review made

**Context:** D-032 recorded three deliberate divergences from rsample and tune
and named its own falsifier as a coherence requirement in vctrs that the
registered pairs violate. The review of that work found one: the `vec_ptype2`
and `vec_cast` methods answered with one side's type rather than the type
holding both sides' columns, so combining a results object with a table whose
columns differ raised vctrs' own internal error where the package without any
of these methods returned a plain table. The same review found that a column
add kept the class in either argument position through vctrs while
`dplyr::bind_cols()` kept it only on the first argument's type.

**Decision:** the common type of a results object and a table carries both
sides' columns, and every cast reconciles its columns to the type it is asked
for. The common type wears the results class only where the results object is
the first argument, matching what `bind_cols()` already did, so the two doors
answer alike in both positions. The prototype these methods travel on carries
the source's record column names privately, and an assembled result missing
any of them sheds the class — which is what `vec_cbind()`'s name repair can do
to a record column, and the one thing that operation can do wrong that a row
count does not catch. Considered and rejected: keeping the class on both sides
and documenting the difference from `bind_cols()` (a caller cannot see which
door a verb uses, which is the property the help page states).

**Consequences:** two of the three divergences D-032 recorded read differently
now. A column added through `vec_cbind()` keeps the class where the results
object leads and not otherwise, so the divergence from rsample is narrower
than D-032 states; and combining a results object with a bare tibble produces
a plain table rather than refusing, which is what the acceptance criteria ask
for and not what D-032's Consequences paragraph says. The ten `vec_ptype2` and
`vec_cast` methods are no longer mirror images of each other, which vctrs asks
a lattice to be; the measurements showing nothing in the package reaches that
asymmetry are in `cairn/milestones/M37-vctrs-invariants.md`. Falsified by a
vctrs version that combines three or more tables in an order-dependent way
through this lattice, or by `dplyr::bind_cols()` changing which argument's
type it builds on.

### D-036 (2026-08-31): a `nested_results` records the columns its design labelled the folds with, and every reader takes them from that record — supersedes M36's milestone-local decision to recognize those columns by a name pattern, and narrows the invariant set D-031 fixed

**Context:** D-031 fixed the invariant set as every column
`new_nested_results()` writes, "the `id` columns" among them, and left the
class to work out which those were. M36 worked it out with a name pattern over
whatever names the object was carrying, and three review rounds each bought
exactly one more spelling: a bare `^id` prefix caught `ideal` and `id_extra`,
and the anchored `^id[0-9]*$` that replaced it still caught `id2` — a name
rsample gives a repeated design and a caller may perfectly well add to a plain
one. Those two cases are spelled identically, so no pattern separates them.

**Decision:** the constructor records `setdiff(names(resamples), c("splits",
"inner_resamples"))` as an `id_columns` attribute, and `id_columns()` returns
that record rather than matching anything. It travels in `run_attributes()`
with the rest of the run's description and is shed with the class. Every column
the constructor copies from the design is one set: the invariant record, the
fold label and the order key are all read from it, so no name pattern survives
anywhere in the class. An object carrying no such record gets the empty answer
and the rule refuses rather than guessing. Considered and rejected: narrowing
the pattern once more (a narrowing is a pattern again, and the previous two
each held for exactly one review round); a second private carrier beside
`nestedtune_template_record` (the record describes the call, and the three
sites that copy a run's description already carry `run_attributes()` whole).

**Consequences:** what a caller names a column decides nothing, at any of the
methods that go through the rule. `check_nested()` still admits a design
carrying columns beside `splits`, `inner_resamples` and `^id`-named ones, and
those columns are now recorded as fold labels rather than ignored; tightening
it has its own ROADMAP row. Falsified by a design whose columns beside `splits`
and `inner_resamples` are not all fold labels, or by a path that must preserve
the record onto a prototype carrying no run description.

### D-037 (2026-08-31): the default print of a `nested_results` is rendered by tibble's print method, and `tibble` stays in Suggests — annotates the placement D-034 fixed, on M39's plan gate

**Context:** M39 rewrites `print.nested_results()` to show the object's rows,
which is what issue #34 asks for. The rows can only be rendered as a tibble by
`print.tbl_df()`, which lives in tibble — a package D-034 put in Suggests on the
stated ground that "No code under `R/` uses tibble". A default print method is
code under `R/`, so the placement was re-examined at M39's plan gate.

**Decision:** `tibble` stays in Suggests, and `print.nested_results()` renders
the rows by removing `nested_results` from the object's class vector and letting
S3 dispatch reach tibble's method — never by calling `tibble::` directly.
Measured at the gate: `dplyr` is in Imports, R loads every Imports namespace
when nestedtune loads, loading dplyr loads tibble, and a class-stripped print
then renders `# A tibble: 3 x k`. Moving tibble to Imports was rejected because
it buys no install-time guarantee D-034 did not already have — tibble arrives
with dplyr and tune regardless — and it would undo `new_tbl()`'s reason for
existing.

**Consequences:** the package's default output format now depends on a package
it does not declare, guaranteed transitively by dplyr's own Imports rather than
by this DESCRIPTION. If dplyr ever drops tibble, printing degrades silently to
`print.data.frame` rather than erroring, which is the failure mode to watch for;
that, or a print rendering as a data frame in any supported configuration, is
what falsifies this. Nothing changes for anyone installing the package.

### D-038 (2026-09-01): `eval_time` is offered as its own argument on both orchestrators, and `censored` and `survival` join Suggests — the second slot the per-argument rule D-030 fixed reaches, and extends the dependency set D-034 last added to

**Context:** a censored-regression metric is evaluated at times the caller
names, and `eval_time` is the argument that carries them. Neither orchestrator
has one, so a caller tuning such a workflow through this package takes tune's
default times with no way to state its own. D-030 settled how a setting of
tune's reaches a caller here — one narrow argument per setting, decided one at
a time — and named `eval_time` as the next candidate. `eval_time` is not a
`control_grid()` slot at all but a direct argument of `tune::tune_grid()` and
`tune::last_fit()`, so that rule applies to it unamended.

**Decision:** an `eval_time` argument on `nested_tune_grid()` and
`nested_final_fit()`, defaulting to `NULL`, validated at entry by
`check_eval_time()` and forwarded untouched to `tune::tune_grid()` and
`tune::last_fit()` on the serial and the mirai path alike. The entry check
refuses only what tune has no use for — a non-numeric value, or one carrying a
missing, negative or non-finite element, or an empty vector — and accepts `0`,
duplicates and unsorted times, which tune normalizes itself. It is not
forwarded to `tune::select_best()`: left `NULL` there, tune reads the tuning
run's own evaluation times and takes the first, which is the time the caller
named, so passing it would change no selection and would repeat tune's own
message. Whether the mode is appropriate for the argument stays tune's warning
to give. `censored` and `survival` join Suggests so the tests can build a
censored-regression workflow whose dynamic survival metric moves when
`eval_time` moves. Considered and rejected: a `control` argument, on the
grounds D-030 states; refusing `eval_time` on a non-censored mode, which would
diverge from tune on tune's own argument; and proving the argument merely
arrives, from tune's "only used for models with mode censored regression"
warning, which moves no number the caller is shown.

**Consequences:** the entry check is stricter than tune's own cleanup, so a
value tune would have accepted after warning about it is refused here instead.
The test-only dependency closure grows by seven packages, several of them
compiled, on every check leg, and every test needing them skips where they are
absent; the count and its members are recorded in M41's work log. Falsified by
tune's value validation diverging from this check, or by the check legs failing
to install `censored`.

### D-039 (2026-09-01): `agreement()` is a package-owned S3 generic tabulating how often each selected parameter combination was chosen across the outer folds — the third generic this package defines, on the shape D-023 fixed, and answers issue #36

**Context:** Issue #36 (topepo) asks for a method reporting candidate
selection frequencies across the outer folds. The facts are on the object:
`.selected` holds each fold's `tune::select_best()` row, `summary()` prints
them per parameter and `autoplot(type = "parameters")` draws them, and nothing
returns them as a table. Verified 2026-09-01 by execution against the
installed tune, hardhat and generics namespaces: none exports `agreement`,
`consensus` or `collect_selections`, so an owned generic is the route D-023
already took.

**Decision:** `agreement()` — a `nested_results` method and a default method
aborting as a classed nestedtune condition — returns one row per distinct
combination of selected parameter values with `n` (completed folds that chose
it) and `prop` (`n` over the completed fold count), most frequent first,
`.config` dropped because it labels a fold's own tuning run and folds can
search different grids (M21). Considered and rejected at the M44 plan gate:
`consensus()` (reads as naming one winner, which is the modal-vote route to a
final model that D-014 rejected); `collect_selections()` (tune's `collect_`
family stacks per-resample rows rather than tallying them, so the name promises
another shape); a long-form `tidy()` method on `generics::tidy()` (a new import
and a dependency decision for a shape `.selected` already holds; declined, no
candidate row); one empty-tuple row for a workflow with nothing to tune (keeps
`sum(n)` universal, but claims a candidate where `summary()` says none was
tuned — zero rows instead).

**Consequences:** the export list gains one name and the namespace a third
owned generic beside `extract_tune_results()` and `extract_scored_candidates()`;
a later upstream definition of the name is a masking conflict resolved by
dropping ours, pre-1.0 without a deprecation cycle (D-003). D-010's and
D-014's refusals stand: nothing here ranks outer folds or names a model, and
the help page says the most frequent row is not the final model's parameters.
The refusal on an all-failed run is `check_any_completed()`'s, shared with the
other accessors (IP4).

### D-040 (2026-09-01): `nested_tune_bayes()` takes `iter`, `initial` and `objective` as its own arguments, `initial` as a count only, and seeds the Gaussian process from the fold's tuning seed — the third and fourth slots the per-argument rule D-030 fixed reach, and the first sibling the naming convention D-010 reserved

**Context:** issue #35 asks for a Bayesian inner loop without a second copy of
the orchestrator. D-010 reserved `nested_tune_bayes()` for it and rejected a
single function taking the tuning method as an argument; D-030 settled that a
setting of tune's reaches a caller here one narrow argument at a time, never
as a `control` object; D-016 said any `nested_tune_bayes()` inherits the
tuning seed's scope. `tune::tune_bayes()` adds three formals of its own —
`iter`, `initial`, `objective` — and a `control_bayes()` whose `seed` slot,
drawn from the stream by default, drives the Gaussian-process proposals.

**Decision:** `nested_tune_bayes()` is a sibling export mirroring
`nested_tune_grid()`, with `iter`, `initial` and `objective` in place of
`grid`; the loop that runs it is shared, told which tuner to call. `initial`
is a count only: a `tune_results` initial is refused, because one object
cannot serve every outer fold and its scores come from resamples that may
include a fold's assessment rows (IP1). `iter` and `initial` are refused
unless single whole numbers, `initial` at least 2 — stricter than tune's
`check_iter()`, which accepts `2.5`, on D-038's precedent. `control_bayes()`
is built inside the fold's seed scope with `seed = <the fold's tuning seed>`
and `allow_par = FALSE`; nothing else on it is settable. Considered and
rejected: a `control` argument (D-030's grounds); `no_improve`, `uncertain`
and `time_limit` as arguments (a ROADMAP candidate row holds them); a single
function with a tuner argument, topepo's sketch (D-010's rejection stands).

**Consequences:** the `nested_tune_*` family has two members and one loop;
the results object records which tuner ran and its static arguments
(M45's `procedure` attribute), which is what a final fit can re-run.
Falsified by a caller needing a `control_bayes()` slot beyond these to change
a number they are shown, or by tune changing `tune_bayes()`'s draw order so a
fixed control seed no longer reproduces a run.

### D-041 (2026-09-01): `nested_final_fit()` takes the results object and re-runs the procedure it recorded — supersedes the signature clause of D-014, and leaves its object and its refusals standing

**Context:** D-014 fixed `nested_final_fit(object, resamples, grid, metrics)`,
mirroring the one orchestrator that existed, so the user restated the
procedure. With a second orchestrator (D-040) the restatement would need a
method switch and every setting of both, and nothing would stop a user
handing the final fit a procedure other than the one their estimate
describes — the reading IP3 exists to forbid.

**Decision:** `nested_final_fit(object, results, ...)`, where `results` is a
`nested_results`; the inner specification, the data and the procedure are
read from it, which from M46 records the design's `inside` call beside M45's
`procedure` attribute. The former `grid`, `param_info`, `metrics`,
`event_level` and `eval_time` formals are removed without a deprecation cycle
(D-003). A results object lacking the record, or carrying no rows, is refused.
Considered and rejected: mirroring the orchestrators' arguments with a method
switch (lets the estimate and the model come from different procedures);
offering both routes (GP3, as D-014 argued); migrating pre-M46 objects
(pre-1.0).

**Consequences:** a final fit always follows a nested run whose estimate is
what the user reports, which is the pairing IP3 asks the documentation to
state. A user wanting a tuned fit with no nested run has `tune::fit_best()`
and `tune::last_fit()`. Falsified by a real need for a final fit from a
design alone that those two do not serve.

### D-042 (2026-09-02): `control` reaches the inner tuning call through `...`, merged with the slots this package forces — supersedes the per-slot clause of D-030 and the `control` rejection of D-040, and keeps D-010's "no `control` formal"

**Context:** issue #33 asked for `...` to reach `tune_grid()`, and issue #35
noted `nested_tune_bayes()` passes nothing and asked for `no_improve` and
`uncertain`. D-030 answered with one narrow argument per slot and D-040
rejected a `control` argument on those grounds, parking the three Bayesian
slots on a candidate row. topepo's replies of 2026-09-02 settle the shape:
no named `control` formal, since that name is reserved for a future control
of the outer work, but a `control` object passed through `...` reaches the
inner call, with the slots that are inert or not returned documented.

**Decision:** `...` on both orchestrators accepts `control` and nothing
else. The control that runs is the caller's, or tune's default, with the
forced slots overwritten — `allow_par = FALSE`, the fold's tuning seed as the
Bayesian `seed` — and `event_level` from the argument, a disagreeing control
refused. The `procedure` attribute records that effective control, `seed`
dropped, so the final fit re-runs it. Considered and rejected: a named
`control` formal (topepo reserves it); forwarding the Gaussian-process
fitter's options on the Bayes sibling (a second, unbounded name domain on
one sibling only, against GP3); refusing every forced slot (both controls
default `allow_par` to `TRUE`, so every default control would be refused).

**Consequences:** D-030's rule that every further slot is its own argument
is superseded; `event_level` and `eval_time` stay as arguments, and the help
pages classify every control slot under one heading. D-010's "no `control`
argument" survives as "no `control` formal". `time_limit` passes through
with a documented caveat: a wall-clock stop makes the candidate set depend
on the machine, outside what IP2 can promise. Falsified by a caller needing
a setting of the inner call that no control slot carries.

### D-043 (2026-09-02): `nested_results` keeps each fold's inner metrics as `.inner_metrics` in place of `.grid`, and `.selected` stays — supersedes D-031's column list and D-023's `.grid` clause, and annotates D-023's one-shape clause

**Context:** issue #57 asks for the inner run's metrics per fold, to plot a
Bayesian search's trajectory and to compute the best candidate on the fly,
and suggests dropping `.selected`. `.grid` holds candidate identities only,
derived from the same frames `collect_metrics()` summarizes; the summarized
table measured about the size of `.grid` and `.selected` together.

**Decision:** a `.inner_metrics` list column, each fold's
`tune::collect_metrics()` of its inner run (`.iter` for the Bayesian tuner),
replaces `.grid`; the candidate set a reader needs is derived from its
distinct parameter rows. `.selected` stays: it records what the fold's outer
fit used under `select_best()`'s tie rules, and DESIGN.md names retained
selections as first-class. The invariant column set D-031 fixed reads
`.inner_metrics` where it read `.grid`. `extract_scored_candidates()` on the
final fit keeps its candidate shape, so the two surfaces no longer share
one shape — the one-shape clause of D-023 is annotated, not kept.
Considered and rejected: dropping `.selected` (a tie may resolve
differently from what ran); keeping `.grid` beside the new column (a
derivable column, twice the record).

**Consequences:** a results object grows by the summarized inner table per
fold; the M23 payload tests measure outbound dispatch and do not bound it.
D-030's falsifier — the inner run retained — is not met: metrics are kept,
predictions and extracts are not, so `save_pred` and `extract` still have
nothing to act on. Pre-1.0, no deprecation (D-003). Falsified by a user
needing the inner run's predictions, which would reopen the retention
question.

### D-044 (2026-09-02): `finetune`, `lme4` and `BradleyTerry2` join Suggests for the racing exports, which refuse at entry when a package their race needs is absent — extends the dependency set D-038 last added to, and is the first Suggests addition that an exported function requires to run at all

**Context:** issue #35's remainder asks for finetune's tuners inside the
outer loop. M50 adds `nested_tune_race_anova()` and
`nested_tune_race_win_loss()`; `tune_race_anova()` calls
`rlang::check_installed("lme4")` and `tune_race_win_loss()`
`rlang::check_installed("BradleyTerry2")` inside the race, and finetune only
suggests both, so a user with finetune alone would meet a prompt or a
failure in the first fold, one outer loop's worth of checks later. The
package's earlier Suggests served tests, vignettes and engines the tests
name; none was a package an export needs to run.

**Decision:** finetune, lme4 and BradleyTerry2 go in Suggests, and each
racing export refuses at entry — before any fold runs, class
`nestedtune_pkg_not_installed` — when finetune or its own race's fitting
package is not installed, read from the tuner registry's `requires` so the
refusal and the daemon attach cannot name different packages. Considered
and rejected: finetune in Imports (every user of the grid and Bayesian paths
would install finetune, lme4 and their trees for a tuner they may never
call); leaving lme4 and BradleyTerry2 to finetune's own `check_installed()`
(the prompt fires inside the fold, after the checks GP3 places at entry);
lme4 refused but left out of Suggests (the ANOVA tests would skip on a CI
leg without it).

**Consequences:** the racing tests skip where any of the three is absent,
and run on the CI matrix, which installs Suggests. The M51 annealing export
takes finetune from the same registry entry shape and adds no package.
Falsified by a CI leg on which lme4 or BradleyTerry2 cannot install, which
would reopen whether the win/loss and ANOVA tests can be required.

### D-045 (2026-09-02): `finetune` carries a `>= 1.0.1` floor in Suggests — annotates the dependency set D-044 added, on M50's review

**Decision:** `finetune (>= 1.0.1)`. The racing record rests on one finetune argument, `collect_metrics(<tune_race>, all_configs = TRUE)`, which finetune's 1.0.1 release introduced (its `git log -S` places the argument in the commit before that release; the NEWS entry for 1.0.1 names the companion `complete` argument). An older finetune accepts the argument through `...` and returns the survivors alone, so the fold record would silently hold less than the help page and D-043 promise. A floor turns that into an install-time refusal. lme4 and BradleyTerry2 take no floor: each is reached through finetune's own `check_installed()` calls, and this package reads nothing of theirs directly.

**Alternatives considered:** a run-time probe of the returned table (a row with `n` below the resample count where an elimination is known to have happened) — there is no such row to look for on a race that eliminated nothing, so the probe cannot tell an old finetune from a clean race. No floor, on the precedent of the other Suggests — rejected because D-012 set the floor precedent where a load-bearing upstream behavior arrived at a known version, and this is that case.

**Consequences:** `R CMD check` and `install.packages()` refuse a finetune older than 1.0.1 for this package's racing tests and users; the CI matrix installs the current release. Falsified by finetune renaming or removing `all_configs`, which would make a ceiling rather than a floor the question.

### D-046 (2026-09-02): `nested_tune_sim_anneal()` takes `iter` and `initial` as its own arguments, `initial` a count of at least 1 and `iter` of at least 1 — extends D-040's `initial` clauses to finetune's annealing sibling and departs from its `iter` floor

**Context:** issue #35's remainder asks for finetune's simulated annealing
inside the outer loop. `tune_sim_anneal()` takes the Bayesian tuner's two
counts and no acquisition function, defaults `initial` to 1 where
`tune_bayes()` requires 2, and its control has no seed slot. Probed at M51's
implement gate: finetune 1.3.0 iterates over `(existing_iter + 1):iter`,
which at `iter = 0` is `1:0` — two iterations, labelled `Iter1` and `Iter0`,
where `tune_bayes()` at `iter = 0` proposes nothing; the loop header is the
same on finetune's GitHub main.

**Decision:** `iter` and `initial` are the export's own arguments, as D-040
made them on the Bayesian sibling, and `initial` is a count only — a
`tune_results` is refused for D-040's reason. `initial`'s floor is 1,
finetune's default: the 2 came from `tune_bayes()`'s own requirement, which
annealing does not share. `iter`'s floor is 1, refusing the 0 the Bayesian
sibling accepts: a user asking for no iterations would get two. Both floors
are arguments of the shared checks, so each sibling states its own. No seed
is injected into the control; the fold's tuning seed alone governs the
initial design and every perturbation. Considered and rejected: accepting
`iter = 0` and documenting finetune's behaviour there (documenting a defect
in place of refusing it); a floor of 2 on `initial` for parity (a
requirement finetune does not make).

**Consequences:** the control slots classify as on the racing page, with
`save_history` Not returned beside the three D-030 named, and `verbose_iter`
Passed through though finetune defaults it on, so a default run prints from
every fold. Falsified for `iter` by a finetune release whose loop runs no
iteration at 0, which would reopen accepting it.

### D-047 (2026-09-03): the orchestrators hold a design to rsample's reader contract at entry — label columns named `id` or `id[1-9]`, character or factor, with no `NA` and no repeated label tuple, and every inner `rset` non-empty — annotates the consequences clause D-036 left open

**Context:** D-036 records every column beside `splits` and `inner_resamples`
as a fold label and says `check_nested()` still admits a design carrying any
such column, leaving the tightening to a ROADMAP row. Probed at M55's plan
gate: a stray column is pasted into every fold label, a repeated label makes
`autoplot()` abort, an `NA` label and an integer `id` pass silently, and a
zero-row inner `rset` fails its fold after the run with tune's message.

**Decision:** the entry check refuses a label column whose name does not
match the pattern rsample's and tune's own readers find id columns by, or
that is neither character nor factor, along with `NA` labels, a label tuple
two rows share, and an inner `rset` with no rows. The rule binds the entry
check alone: the results class keeps reading its labels from D-036's record,
and no name pattern returns to it. Considered and rejected: rsample's
constructor prefix `^id` (admits names tune's readers ignore); no name rule,
type and uniqueness only (a stray column still prints into every fold label).

**Consequences:** a hand-built design must name its label columns as rsample
does; a `manual_rset()` of inner splits over another frame is still admitted
and handled by the parallel fat path. Falsified by a design rsample itself
builds that the rule refuses, or by an rsample or tune release whose readers
find id columns by another rule.

### D-048 (2026-09-03): a duplicated record name sheds the class like a moved one, counted over the record's names alone, and `names<-.nested_results()` decides on the names alone — annotates the name-repair clause of D-035 and narrows the `rename()` clause of D-032, on M56's review

**Context:** D-035 named name repair moving a record column as the one thing
`vec_cbind()` can do wrong that a row count does not catch. M56's review
found a second: with `.name_repair = "minimal"` a second column arrives
under a record name, `x$splits` answers with whichever came first, and the
record can no longer be found by name. Its first fix counted duplicates over
every name, and the defect return showed a clash between two caller-added
columns shedding the run's record. D-032 says `names<-.nested_results()`
carries the rule `dplyr_reconstruct.nested_results()` carries, which
compares values.

**Decision:** `duplicated_record_names()` counts a duplicate over the
record's names alone, and the three doors — `can_reconstruct_results()`,
`vec_restore.nested_results()` and `names<-.nested_results()` — shed the
class and every attribute on a duplicated or missing record name and keep
the object otherwise: the doors vouch for the record by name and read no
name outside it, so a clash between two caller-added columns is theirs to
keep. `names<-.nested_results()` decides on the names alone, with no value
comparison: base `names<-` relabels columns and never moves or alters a
value, so the record is intact exactly when each record column keeps its
name and no other column takes one. Considered and rejected: a name count
over every column (sheds on a clash the record does not feel); keeping the
value comparison on `names<-` (re-establishes what the names already
settle).

**Consequences:** the `rename()` method no longer shares
`dplyr_reconstruct()`'s rule as D-032 states; the two doors agree on every
input because a rename cannot move a value. Falsified by a `names<-` path
that reorders or drops a column, or by a reader of the record that resolves
a column by position rather than name.

<!-- Template:

### D-00N (YYYY-MM-DD): Title

**Context:** 1–2 lines.
**Decision:** 1–2 lines.
**Consequences:** 1–2 lines. (Supersedes D-0xx, if any.)

-->
