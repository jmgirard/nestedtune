# Design

_Architecture as it **is**, not as it will be. Future work lives in
`ROADMAP.md`; status lives there too._

## Purpose & Scope

> **`/design-interview` complete, both phases (2026-07-25).** Purpose, contract
> boundary, conventions, and the IP/GP principle set below are elicited, not
> inferred. Elicitation provenance: run on Opus 5 rather than the skill's
> recommended Fable, at the maintainer's choice. _(The note here originally
> added that the package had no source, so Function Families and Architecture
> would stay empty until it did; both sections were filled at M02 and the
> clause is corrected out — 2026-07-25.)_

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

- **Building the resampling structure**, except where rsample's own version is
  memory-inefficient — `rsample::nested_cv()` builds it, but materializes each
  outer fold's analysis set, so size scales with the outer fold count.
  nestedtune ships a memory-lean constructor beside it. _(D-005 narrowed this
  from a blanket exclusion, 2026-07-25.)_
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

Two families, each a group of exported functions sharing a contract and a
naming convention.

- **Resampling construction** — `nested_resamples()`. Builds a nested
  resampling design and returns an object carrying rsample's `nested_cv`
  classes, so it is a drop-in for `rsample::nested_cv()`'s output (D-008).
- **Orchestration — `nested_tune_*`** — `nested_tune_grid()` and
  `nested_tune_bayes()`: one outer loop, told which inner tuner to call by an
  internal *tuner description* — the tune function's name and its static
  arguments (`R/tuner.R`, D-040) — plus the `collect_metrics()` method on the
  `nested_results` object both return and `agreement()`, the package-owned
  generic tabulating how often each selected parameter combination was chosen
  across the outer folds (D-039). The suffix names the inner tuning method
  (D-010).
- **Final fit** — `nested_final_fit()`, returning a `nested_final_fit` object
  reached with `extract_workflow()`. It runs the same procedure the estimate
  describes over the whole dataset, and answers none of tune's ranking or
  collecting generics, so no number it holds can be read as the model's score
  (D-014).

## Conventions

- **Numeric results are oracle-verified.** Any statistical or numeric result
  the package produces is confirmed against **≥2 independent oracle types**
  before it ships (published worked example, reference implementation in
  another language/package, analytic result, simulation, invariant). A test
  that only checks the implementation against its author's expectations is
  not an oracle. See the plugin's `skills/shared/validation-doctrine.md`.
  For a resampling package this is load-bearing: a subtly wrong outer-loop
  estimate is self-consistent and will pass its own unit tests.
- **Oracle records: provenance headers in the asserting test file.** Each oracle
  is recorded at the top of the `tests/testthat/test-*.R` file that asserts it,
  by ID, type, source, and which test pins it — the asserting test is the single
  source of truth, never a restated value. This is the declared location every
  ≥2-types audit reads off. _(added 2026-07-25, M01.)_
- **`air` is the formatter, and a committed tree is clean under it.** `air.toml`
  at the root declares the settings (the tidymodels shape: `[format]` with
  `skip = ["tribble"]`), `air format .` is expected to change nothing on a
  committed tree, and `.github/workflows/format-suggest.yaml` posts any
  difference on a pull request as a review suggestion. One consequence to know
  before reformatting: `tests/testthat/helper-time-budget.R` holds a budget
  ledger of `file:line` positions in the daemon test files and
  `test-suite-hygiene.R` fails when a row points at a moved line, so a
  formatting pass re-points that ledger in the same commit. _(added 2026-08-30,
  M33 — the first code-style convention recorded here.)_
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
  refuses to imply otherwise, and the print and summary methods say so
  _(corrected M39: for `nested_results` the sentence is emitted by
  `print(summary(x))`, not by `print(x)`)_.
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

- IP1: **No leakage across the outer boundary.** The outer assessment set never
  influences anything upstream of its own scoring: not inner tuning, not
  parameter selection, not preprocessing. This binds the final-fit path as well
  as the loop: any preprocessing that feeds a reported estimate is estimated on
  the analysis set of the resample being scored, never on data that includes the
  corresponding assessment rows. The final model's own training preprocessing,
  which yields no estimate, is estimated on its training data — the full dataset
  — and is outside this clause. _(Middle clause narrowed at M05 by D-015, on
  RR02's finding that the original wording forbade a correct final fit; git
  holds the original.)_ This is the property that makes the package's output
  mean anything.

- IP2: **Reproducible results.** The same seed produces the same result
  regardless of the number of workers and regardless of whether execution is
  parallel or serial. This requires RNG streams managed per outer fold rather
  than inherited from a worker, and it constrains which parallel backends are
  usable. Deliberately **not** claimed, because it cannot be honoured: identity
  across R versions, across platforms, or across `tune` versions.

- IP3: **The estimate describes the procedure, never the shipped model.** The
  nested estimate characterizes the whole tune-and-fit procedure. The API never
  presents it as a property of a fitted model, however convenient that would be;
  the final model is a separate object. Because this refuses the applied
  audience's most natural request, it carries an obligation: the documentation
  must say plainly what a user should report instead, and why.

- IP4: **The estimate describes the design actually executed.** No estimate is
  reported as though it came from a design that did not run — a failed fold, a
  truncated grid, a silently coerced scheme. The results object positively
  records what ran (folds attempted and completed, the grid actually evaluated,
  any coercion applied), so the principle is checkable rather than aspirational.

### Guiding (GP)

- GP1: **Delegation fidelity.** Inner results match what a user would get
  calling `tune` directly. Divergence is permitted where necessary — forcing
  tune's control to sequential for the parallelism split is one such case — but
  it is documented, never silent.

- GP2: **Numeric results are oracle-verified.** Confirmed against ≥2
  independent oracle types before shipping. Guiding rather than inviolable per
  the artifact/process line above (D-004).

- GP3: **Hard to misuse over configurable.** Provably invalid designs are
  refused rather than warned about, deliberately stricter than `rsample`; one
  obvious path is preferred to a knob. Both faces of the same instinct.

- GP4: **Usable on real data is part of correctness.** Performance and memory
  are design constraints, not polish. **Explicitly subordinate to IP2**: where
  reproducibility and speed conflict, reproducibility wins, and the fastest
  schedulers are ruled out on that basis.

- GP5: **Don't ship inference the literature hasn't settled.** Where the
  statistics are contested, the package declines rather than picking a side.

_Not at principle strength, by decision: surfacing what other tools hide
(selection instability). It remains a convention below — the only positive
obligation among a set of prohibitions — and nothing at principle strength
defends it if default output gets crowded._

_Posture toward upstream's prototype (tune#969) is settled by D-025: this
package continues, and the repository moves into the `tidymodels` organization
as `tidymodels/nestedtune` with its current maintainer retained. The outer loop
is not ported into tune. What the package asks of tune is unchanged and costs
tune nothing — that the `nested_cv` refusal stay a top-level refusal, each
`inner_resamples` element still accepted as an ordinary `rset` — but it is now
an ask between packages in one organization. (This line first recorded the
question as open, deliberately not invented by the interview; corrected
2026-07-30 when the maintainer replied, and corrected again 2026-08-28 when the
maintainer meeting settled it — git holds both earlier versions.)_

## Architecture

`nested_resamples()` (`R/nested-resamples.R`) evaluates the inner specification
against each outer fold's analysis frame exactly as rsample does, then keeps
only the row indices and remaps them onto the original data, so the inner
splits reference the one copy the caller already holds.

`nested_tune_grid()` (`R/nested-tune-grid.R`) and `nested_tune_bayes()`
(`R/nested-tune-bayes.R`) each validate their arguments (`R/checks.R`), build a
tuner description — `tuner_grid(grid)` or `tuner_bayes(iter, initial,
objective)` (`R/tuner.R`) — and hand it to `nested_loop()`, the one outer
loop. It draws every fold's seeds up front and hands each fold to
`nested_fold_fit()` — a worker whose inputs are the outer split, the inner
`rset`, the fold's two seeds, the tuner description and the static
workflow/metrics. The worker delegates the entire statistical pipeline to
tune: `run_tuner()` assembles the inner call with `rlang::call2()` —
`tune_grid()` under `control_grid(allow_par = FALSE, event_level)`, or
`tune_bayes()` under `control_bayes(allow_par = FALSE, event_level, seed =
<the fold's tuning seed>)`, the control built inside the fold's seed scope —
then `select_best()`, `finalize_workflow()`, `last_fit()` on the outer split
under `control_last_fit(event_level = event_level)`. The results object
records the description as its `procedure` attribute.
Nothing is read from the enclosing loop and nothing is drawn inside it, which
is what makes fold results independent of execution order and the loop safe to
parallelize later.

The reproducibility contract is D-011: `2 * n` seeds from one `sample.int()`
call at entry, assigned by fold position, applied with the generator kind
pinned, and the caller's RNG state restored on exit including on error. The
kind pin is what makes a fresh worker agree with a serial run.

`new_nested_results()` (`R/nested-results.R`) assembles one row per outer fold
— split, id, metrics, selected parameters, and the fold's two seeds — as a
plain tibble carrying class `nested_results`. It deliberately does **not**
inherit `tune_results`: that would bring `show_best()` and `select_best()`
along, and both would rank outer folds, which is the reading IP3 forbids
(D-010). `collect_metrics()` is registered against tune's generic.

`nested_final_fit()` (`R/nested-final-fit.R`) is the deployment path. It reuses
the same argument checks, then draws two seeds and hands everything to
`final_fit_worker()`, which sets the tuning seed, re-evaluates the design's
stored `inside` call against the full data, tunes, selects, finalizes, sets the
fit seed, and fits on every row. The seed scope is D-016: building an `rset`
draws from the RNG, so the construction sits inside the tuning seed's scope
rather than before it, and the run is reproducible from the two seeds alone.
The worker exists as a separate function for the same reason `nested_fold_fit()`
does — everything it needs is an argument — which is also what makes its
independence from the ambient generator testable, since the entry draw itself
is kind-dependent and so cannot be.

`new_nested_final_fit()` assembles a plain list carrying the trained workflow,
the selection, the tuning run, and both seeds. The tuning run travels with it as
the record of what selection saw; its metrics are selection-time quantities, so
nothing in the package's own surface turns them into a claim — the print method
shows no number from it, and tune's ranking generics are left unregistered.

The dependency surface is rsample, cli, rlang, tune (>= 2.0.0), workflows,
parsnip, and ggplot2 _(ggplot2 added 2026-07-26 at M08, D-019: the first Import
that is not needed to compute a result — it carries `autoplot()`)_. The tune
floor is load-bearing rather than defensive: every
reproducibility guarantee above rests on tune >= 2.0.0 deriving its own
per-resample streams and leaving the caller's RNG state untouched, verified by
execution in RR01, and tune 1.x seeded differently (D-012).

## Known issues

- The two vendored community pages carry defects inherited verbatim from the
  organization's shared texts, accepted at M32's review because repairing them
  locally would fork the texts this repo adopted for being byte-identical
  across the organization. `.github/CODE_OF_CONDUCT.md` has a reference-style
  Markdown link with a URL where its label belongs and no matching definition,
  so it renders as literal bracketed text on the published page; and
  `.github/CONTRIBUTING.md` links Contributor Covenant 2.0 while the code of
  conduct beside it on the site is 2.1. Both are upstream problems; fixing
  either means fixing it upstream first.

- The three vendored organization CI workflows carry properties this repository
  would not choose, accepted at M33's review for the same reason: each is held
  at the organization's shared blob, and editing one puts it off that blob.
  `.github/workflows/pr-commands.yaml` offers a `/style` command that runs
  `styler::style_pkg()`, a different formatter from the `air` this repository
  adopted, so using it commits a tree `format-suggest.yaml` then flags line by
  line — treat `/style` as unavailable here. `format-suggest.yaml` runs on
  `pull_request_target` with `posit-dev/setup-air@v1` and
  `reviewdog/action-suggester@v1` on moving tags under `pull-requests: write`,
  and its `permissions:` block zeroes `contents`, which works only because this
  repository is public. `lock.yaml` declares no `permissions:` block at all, so
  its nightly run depends on the repository's default workflow token being
  writable; that setting could not be read at review. The moving-tag half is
  carried by the standing candidate row that tracks the pkgdown deploy pin.

- `dplyr::group_by()`, `dplyr::rowwise()` and `tibble::as_tibble()` leave the
  run's recorded attributes readable on the object they return. None of the
  three returns a `nested_results` — the classes are `grouped_df`, `rowwise_df`
  and `tbl_df` (measured 2026-08-31) — so nothing they hand back claims to be a
  results object, and rsample's own `rset` behaves the same way. M37 documented
  this rather than intercepting three further entry points to strip attributes
  off objects that have already stopped answering for the run. The **Value**
  section of `?nested_tune_grid` states it, and `test-vctrs-compat.R` asserts
  it.
