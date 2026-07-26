# Design

_Architecture as it **is**, not as it will be. Future work lives in
`ROADMAP.md`; status lives there too._

## Purpose & Scope

> **Provisional (2026-07-25).** Seeded by `/cairn-init` from the greenfield
> openers — there was no source or `DESCRIPTION` to read. Refine via
> `/design-interview`; do not treat these lines as elicited design.

- nestedcv provides **nested cross-validation** for model evaluation in R:
  an inner resampling loop tunes hyperparameters, an outer loop yields a
  performance estimate that is not optimistically biased by that tuning.
- It is built as a **tidymodels-ecosystem extension**, composing with
  rsample/parsnip/tune rather than standing alone with its own model API.
- **Distribution ambition: CRAN.** The package is held to CRAN standards from
  the first milestone — clean `R CMD check`, documented exports,
  `cran-comments.md`, reverse-dependency checks at release. `/cairn-release`
  runs the CRAN walk; it never self-submits.
- Out of scope: _(not yet elicited)_.

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

_(none yet — principles are elicited, never invented. Run
`/design-interview`.)_

### Guiding (GP)

_(none yet — see above.)_

## Architecture

_(none yet — no source. This section describes the structure as it exists,
once it exists.)_

## Known issues

_(none yet.)_
