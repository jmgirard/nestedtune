# Design

_Architecture as it **is**, not as it will be. Future work lives in
`ROADMAP.md`; status lives there too._

## Purpose & Scope

> **Phase 1 of `/design-interview` complete (2026-07-25).** Purpose, contract
> boundary, and conventions below are elicited. The Design Principles block is
> still pending Phase 2.

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
  the product.
- Toolchain mechanics (test commands, check gates, release walk) live in
  `cairn/PROFILE.md`, not here.

## Design Principles

_Two strengths. **IP<n> — Inviolable Principle:** a hard constraint, never
violated in implementation; changing one requires an explicit user decision
recorded as a D-entry. **GP<n> — Guiding Principle:** a default stance,
tradeable with stated justification. The IP block comes first. Numbers run
within each type and are **never reused or renumbered** — retiring a
principle takes a D-entry and its number stays retired._

### Inviolable (IP)

_(pending Phase 2 of `/design-interview`.)_

### Guiding (GP)

_(pending Phase 2.)_

### Banked candidates (Phase 1 → Phase 2)

_Working ledger, not commitments. Each arrives at Phase 2 classified as
proposed IP / GP / skip; this section is deleted at Phase 2 write-out._

| # | Candidate | Source |
|---|---|---|
| BC1 | Delegate to tidymodels rather than reimplement | boundary choice |
| BC2 | Numeric results are oracle-verified — promote to IP? | scaffold convention |
| BC3 | Don't ship inference the literature hasn't settled | G6 disposition |
| BC4 | The estimate describes the procedure, never the shipped model | misreading wart |
| BC5 | Refuse invalid designs rather than warn about them | strictness choice |
| BC6 | Surface what other tools hide (selection instability) | instability wart |
| BC7 | Usable on real data is part of correctness, not polish | speed wart |
| BC8 | One obvious path over configurability | audience choice |

_Still open, deliberately not invented by the interview: posture toward
upstream's dormant prototype (tune#969), pending the maintainer's reply._

## Architecture

_(none yet — no source. This section describes the structure as it exists,
once it exists.)_

## Known issues

_(none yet.)_
