# Design

_Architecture as it **is**, not as it will be. Future work lives in
`ROADMAP.md`; status lives there too._

## Purpose & Scope

> **`/design-interview` complete, both phases (2026-07-25).** Purpose, contract
> boundary, conventions, and the IP/GP principle set below are elicited, not
> inferred. The package has no source yet; Function Families and Architecture
> stay empty until it does. Elicitation provenance: run on Opus 5 rather than
> the skill's recommended Fable, at the maintainer's choice.

**nestedtune orchestrates nested cross-validation for the tidymodels
ecosystem.** The package is named `nestedtune`, not `nestedcv` — that name is
taken on CRAN by an established caret/glmnet package (D-001).

**Contract boundary.** nestedtune drives the **outer loop**. For each outer
fold it calls `tune::tune_grid()` on that fold's inner `rset`, selects
parameters from the inner results, fits on the outer analysis set, and scores
on the outer assessment set. It returns a collected-results object with a
`collect_metrics()`-style idiom.

The boundary rests on a structural fact about the ecosystem: `tune` aborts on
an object of class `nested_cv`, but each element of that object's
`inner_resamples` column is an ordinary `rset` that `tune` accepts without
complaint. The refusal is at the top level only, so the outer loop is the
single genuinely missing piece.

Explicitly **not** nestedtune's job:

- **Building the resampling structure** — `rsample::nested_cv()` does that.
- **Implementing a tuning engine** — `tune` does that, and nestedtune
  delegates to it rather than reimplementing it.
- **Inference on the nested estimate** — variance estimation for nested CV is
  contested in the literature. Parked as a ROADMAP candidate; shipping an
  interval without oracle backing would violate the oracle convention below.

**Audience: applied analysts** who know nested CV is the right thing but not
its details. When convenience and flexibility conflict, nestedtune optimizes
for one obvious, hard-to-misuse path over configurability.

**Distribution ambition: CRAN.** Held to CRAN standards from the first
milestone — clean `R CMD check`, documented exports, `cran-comments.md`,
reverse-dependency checks at release. `/cairn-release` runs the CRAN walk; it
never self-submits.

The evidence behind the boundary is ledgered in
`cairn/references/tidymodels-nested-cv-gaps.md` (gaps G1–G8).

## Function Families

_(none yet — the package has no source. A family is a group of exported
functions sharing a contract and a naming convention.)_

## Conventions

- **Numeric results are oracle-verified.** Any statistical or numeric result
  the package produces is confirmed against **≥2 independent oracle types**
  before it ships (published worked example, reference implementation in
  another language/package, analytic result, simulation, invariant). A test
  that only checks the implementation against its author's expectations is
  not an oracle. See the plugin's `skills/shared/validation-doctrine.md`.
  For a resampling package this is load-bearing: a subtly wrong outer-loop
  estimate is self-consistent and will pass its own unit tests.
- **Pure R — no compiled code.** No `src/`, no `LinkingTo`, no C/C++/Fortran
  toolchain. Adding compiled code later is additive and would be a design
  decision recorded as a D-entry.
- **Delegate to tidymodels rather than reimplement.** Where a tidymodels
  package already does the job, nestedtune calls it. This is what keeps the
  surface small enough to verify.
- **Pre-1.0 breaking changes need no deprecation cycle.** The universal
  deprecation-cycle rule is explicitly waived while pre-1.0 (user decision,
  2026-07-25). This is a stated stance, not drift; it lapses at 1.0.
- **Parallelize the outer loop; keep `tune` serial within it.** Coarse-grained
  parallelism over outer folds, with tune's control set to sequential
  explicitly rather than by hope. Nested parallelism oversubscribes cores, a
  plausible contributor to the slowdown reported in tune#148.
- **Error on provably invalid resampling schemes.** An outer bootstrap is
  refused, not warned about — deliberately stricter than `rsample`, which only
  warns. _(Tension to stress-test in Phase 2: this makes the ecosystem
  inconsistent, and the stricter behavior must be defended in issues.)_
- **The final model is a separate object, never a field on the results.** A
  final-fit path exists because users need it, but the nested estimate
  describes the tune-and-fit *procedure*, not the shipped model. The structure
  refuses to imply otherwise, and print methods say so.
- **Inner-loop selection stability is first-class.** The results object always
  retains each outer fold's selected parameters, and default print/summary
  surfaces disagreement between folds. Nothing else in the ecosystem does this.
- **Performance is a design constraint, not a later optimization.** Benchmarks
  and memory behavior are tracked from early releases. Slowness is the stated
  reason practitioners skip nested CV, so being usable on real data is part of
  the product. Subordinate to IP2 where the two conflict.
- **A failed fold keeps its partial results but never a complete summary.**
  Expensive compute is not discarded when one outer fold errors; the results
  object records the failure and summary methods refuse to report a
  nine-fold estimate as the ten-fold design that was requested. An instance
  of IP4, not a special case.
- Toolchain mechanics (test commands, check gates, release walk) live in
  `cairn/PROFILE.md`, not here.

## Design Principles

_Two strengths. **IP<n> — Inviolable Principle:** a hard constraint, never
violated in implementation; changing one requires an explicit user decision
recorded as a D-entry. **GP<n> — Guiding Principle:** a default stance,
tradeable with stated justification. The IP block comes first. Numbers run
within each type and are **never reused or renumbered** — retiring a
principle takes a D-entry and its number stays retired._

**The IP/GP split here follows a stated line: inviolable principles bind the
artifact, guiding principles bind the process** (D-004). All four inviolables
share a basis — each forbids a failure that is *invisible in the output*, one
a user cannot detect by inspection. That is why oracle verification, which is
equally about invisible wrongness, is guiding rather than inviolable: it
constrains how the package is developed, not what it does.

### Inviolable (IP)

**IP1 — No leakage across the outer boundary.** The outer assessment set never
influences anything upstream of its own scoring: not inner tuning, not
parameter selection, not preprocessing. This binds the final-fit path as well
as the loop — preprocessing is estimated on analysis data, never on the full
dataset. This is the property that makes the package's output mean anything.

**IP2 — Reproducible results.** The same seed produces the same result
regardless of the number of workers and regardless of whether execution is
parallel or serial. This requires RNG streams managed per outer fold rather
than inherited from a worker, and it constrains which parallel backends are
usable. Deliberately **not** claimed, because it cannot be honoured: identity
across R versions, across platforms, or across `tune` versions.

**IP3 — The estimate describes the procedure, never the shipped model.** The
nested estimate characterizes the whole tune-and-fit procedure. The API never
presents it as a property of a fitted model, however convenient that would be;
the final model is a separate object. Because this refuses the applied
audience's most natural request, it carries an obligation: the documentation
must say plainly what a user should report instead, and why.

**IP4 — The estimate describes the design actually executed.** No estimate is
reported as though it came from a design that did not run — a failed fold, a
truncated grid, a silently coerced scheme. The results object positively
records what ran (folds attempted and completed, the grid actually evaluated,
any coercion applied), so the principle is checkable rather than aspirational.

### Guiding (GP)

**GP1 — Delegation fidelity.** Inner results match what a user would get
calling `tune` directly. Divergence is permitted where necessary — forcing
tune's control to sequential for the parallelism split is one such case — but
it is documented, never silent.

**GP2 — Numeric results are oracle-verified.** Confirmed against ≥2
independent oracle types before shipping. Guiding rather than inviolable per
the artifact/process line above (D-004).

**GP3 — Hard to misuse over configurable.** Provably invalid designs are
refused rather than warned about, deliberately stricter than `rsample`; one
obvious path is preferred to a knob. Both faces of the same instinct.

**GP4 — Usable on real data is part of correctness.** Performance and memory
are design constraints, not polish. **Explicitly subordinate to IP2**: where
reproducibility and speed conflict, reproducibility wins, and the fastest
schedulers are ruled out on that basis.

**GP5 — Don't ship inference the literature hasn't settled.** Where the
statistics are contested, the package declines rather than picking a side.

_Not at principle strength, by decision: surfacing what other tools hide
(selection instability). It remains a convention below — the only positive
obligation among a set of prohibitions — and nothing at principle strength
defends it if default output gets crowded._

_Still open, deliberately not invented by the interview: posture toward
upstream's dormant prototype (tune#969), pending the maintainer's reply._

## Architecture

_(none yet — no source. This section describes the structure as it exists,
once it exists.)_

## Known issues

_(none yet.)_
