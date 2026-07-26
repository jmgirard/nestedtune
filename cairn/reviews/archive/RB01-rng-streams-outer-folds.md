# RB01: Per-outer-fold RNG streams for the nested driver (M02)

- **Date:** 2026-07-25
- **Output required:** write findings to `cairn/reviews/RR01-rng-streams-outer-folds.md`

You are performing an independent expert review. This brief is fully
self-contained — do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

**The package.** `nestedtune` is an R package (pre-1.0, no CRAN release yet)
that orchestrates nested cross-validation for the tidymodels ecosystem. Its
contract boundary is deliberately narrow: it drives the **outer loop** and
delegates inner tuning to `tune`. For each outer fold it calls
`tune::tune_grid()` on that fold's inner `rset`, selects parameters with
`select_best()`, finalizes the workflow, and fits/scores on the outer split
with `last_fit()`. It does not implement a tuning engine. The reason this
package exists is that `tune` hard-aborts on an object of class `nested_cv`,
while each element of that object's `inner_resamples` column is an ordinary
`rset` that `tune` accepts — so the outer loop is the single missing piece in
the ecosystem.

**What has shipped.** One milestone (M01) is done. It exports
`nested_resamples()`, a memory-lean replacement for `rsample::nested_cv()` that
stores index vectors into the original data instead of materializing each outer
fold's analysis set. No orchestration code exists yet.

**What this milestone (M02) is doing.** Shipping the orchestrator:
`nested_tune_grid()`, returning a `nested_results` object that retains per-fold
metrics *and* each fold's selected parameters. Execution is **serial** in M02;
parallelism over outer folds is a separate, later milestone (already a roadmap
candidate).

**Why this needs independent review.** The milestone's task T4 — "implement the
serial driver over outer folds with RNG streams managed per fold rather than
inherited, so the seed determines the result independently of execution order" —
is tagged as touching an inviolable principle. The package's IP2 reads, verbatim:

> IP2: **Reproducible results.** The same seed produces the same result
> regardless of the number of workers and regardless of whether execution is
> parallel or serial. This requires RNG streams managed per outer fold rather
> than inherited from a worker, and it constrains which parallel backends are
> usable. Deliberately **not** claimed, because it cannot be honoured: identity
> across R versions, across platforms, or across `tune` versions.

An inviolable principle in this repo is a hard constraint that is never violated
in implementation; changing one requires an explicit maintainer decision. IP2 is
also the principle GP4 (performance) is explicitly subordinate to.

The decision is being made **now, in a serial milestone**, precisely because the
seeding scheme chosen here is what the later parallel milestone will inherit —
and because it determines what the milestone's oracle tests must look like. A
scheme that is merely adequate serially, but has to be replaced when parallelism
arrives, changes every number the package produces.

**The three candidate schemes on the table.** Stated precisely so you can
evaluate them as written, not as you might reconstruct them:

- **Scheme A — per-fold integer seeds.** At function entry, draw one integer
  seed per outer fold from the caller's current RNG state, e.g.
  `fold_seeds <- sample.int(.Machine$integer.max, n_folds)`. At the top of each
  fold's work, `set.seed(fold_seeds[[i]])`. Uses R's default generator
  (Mersenne-Twister). Adds no dependency.
- **Scheme B — L'Ecuyer-CMRG streams.** Switch the RNG kind to
  `"L'Ecuyer-CMRG"`, derive one independent stream per outer fold with
  `parallel::nextRNGStream()`, and assign each fold its stream by setting
  `.Random.seed` before that fold's work. This is what `future`/`furrr` do for
  parallel-safe RNG. Adds `parallel` (a base-priority package, but still an
  Imports declaration) and changes the generator kind, so the *values* drawn
  differ from a plain Mersenne-Twister run under the same user-visible seed.
- **Scheme C — inherit the caller's state.** Do not reseed at all; run folds in
  order under whatever RNG state the caller established. Simplest; the
  maintainer's own reading is that this violates IP2 the moment folds run in
  parallel or out of order, and would have to be replaced by the parallelism
  milestone.

The maintainer's provisional preference was Scheme A, and the question was
escalated rather than settled.

**The oracle problem this creates.** The milestone's acceptance criteria include
two numeric-verification oracles for the nested estimate:

- AC2 — "For a fixed seed, per-outer-fold metrics are identical to a
  hand-rolled reference loop running `tune_grid()` → `select_best()` →
  `finalize_workflow()` → `last_fit()` explicitly." (A *live reference
  implementation* oracle.)
- AC3 — "With a single-candidate grid, per-fold metrics are identical to
  `tune::fit_resamples()` on the outer `rset` under the same workflow, seed, and
  metrics — with nothing to select, nested CV degenerates to ordinary CV." (An
  *invariant* oracle.)

The repo requires every numeric result to be backed by at least two
*independent* oracle types; AC2 and AC3 are that pair. The difficulty: under any
reseeding scheme, the hand-rolled reference loop of AC2 must reproduce the same
per-fold seeding to produce matching numbers — which risks the reference loop
becoming a restatement of the implementation rather than an independent check of
it. Similarly, `tune::fit_resamples()` in AC3 does its own thing with RNG, and
matching it may constrain where the driver is allowed to reseed.

## Materials

Read these files in the repository root. They are short.

- `cairn/DESIGN.md` — purpose, contract boundary, conventions, and the full
  IP/GP principle set. The "Design Principles" section carries IP1–IP4 and
  GP1–GP5. Note especially IP1 (no leakage across the outer boundary), IP2
  (quoted above), GP1 (delegation fidelity — divergence from what a user would
  get calling `tune` directly is permitted but must be documented, never
  silent), and GP4 (performance, explicitly subordinate to IP2).
- `cairn/milestones/M02-outer-loop-orchestration.md` — the milestone's goal,
  scope, acceptance criteria AC1–AC7, coverage map, and tasks T1–T9. T4 is the
  task this brief concerns; T8 is the leakage test.
- `cairn/DECISIONS.md` — read D-002 (contract boundary), D-003 (pre-1.0
  deprecation waiver), D-006 and D-007 (dependency set and the gate on changing
  it), D-009, and D-010 (the exported API shape settled for M02).
- `R/nested-resamples.R` — the whole file (177 lines). This is M01's export,
  the object `nested_tune_grid()` will consume. `inner_resamples_from_split()`
  at lines 138–170 is where the inner `rset`s come from.
- `tests/testthat/test-nested-resamples-rng.R` — the whole file (91 lines).
  This is the existing RNG-testing convention in this repo. The third test,
  "the same amount of randomness is consumed as `rsample::nested_cv()`"
  (lines 36–52), is directly relevant to question 6: M01 deliberately leaves the
  caller's RNG stream in the same place `rsample` would, so that a seeded script
  doing anything after the call is unaffected.
- `tests/testthat/helper-nestedtune.R` — the fixture generator and the
  identity helpers (52 lines).
- `cairn/references/tidymodels-nested-cv-gaps.md` — the evidence ledger behind
  the contract boundary (gaps G1–G8), for context on what the ecosystem does and
  does not already provide.

**Running code.** `rsample` 1.3.2, `future` 1.70.0, `furrr` 0.4.0, and `withr`
3.0.3 are installed; R is 4.6.1. **`tune`, `workflows`, `parsnip`, `dials`, and
`yardstick` are NOT currently installed in this checkout** — M02's task T1 is
what adds them. If you need to read or run `tune`'s source to answer question 4,
install with `pak::pak("tune")` or read the source on GitHub
(`tidymodels/tune`). If you cannot get access to it, answer question 4 from the
documented behavior and say explicitly that you could not verify against the
source; do not guess silently.

`Rscript -e 'devtools::test()'` runs the existing suite.

## Questions

1. **Does Scheme A satisfy IP2 as written?** Specifically: with per-fold integer
   seeds drawn once at entry from the caller's state, and `set.seed()` applied
   at the top of each fold, is the result invariant to (a) the number of
   parallel workers, (b) serial versus parallel execution, and (c) the order in
   which folds are executed? Identify any concrete way it can fail — including
   any path by which a worker's own RNG state, a backend's seeding policy, or
   code inside `tune` could leak into the result.

2. **Is the stream-correlation concern material here?** Arbitrary integer seeds
   into Mersenne-Twister do not give provably independent streams. In this
   specific use — each outer fold produces one performance estimate, and those
   estimates are averaged (and, later, their spread may be summarized) across
   folds — can correlation between fold streams bias the nested point estimate
   or deflate the apparent variability across folds to a degree that matters in
   practice? Give the reasoning, and say plainly whether this is a real hazard
   or a theoretical one, with any evidence you can cite.

3. **What does Scheme B actually buy, and what does it cost?** Given that the
   randomness consumed inside each fold is generated by `tune` and by the model
   engine (not by nestedtune), does per-fold L'Ecuyer stream assignment deliver
   a guarantee Scheme A does not? Assess the specific hazards of switching the
   generator kind inside an exported function: restoring the caller's kind on
   exit, behavior if the caller has already selected L'Ecuyer-CMRG, behavior
   under a caller-set `RNGkind()` the package does not expect, and the fact that
   results under Scheme B will not match a plain `tune_grid()` run under the
   same user-visible seed.

4. **How does `tune::tune_grid()` itself interact with the RNG?** With
   `control_grid(allow_par = FALSE)`, does it consume randomness from the
   current stream in a deterministic order, does it reseed internally, and does
   it do anything with `future`'s RNG machinery even when parallelism is
   disabled? State what you verified against source versus inferred.

5. **Where must the seed be set within a fold?** Each fold does inner tuning
   (`tune_grid()`), then a final fit and score on the outer split (`last_fit()`).
   Both can be stochastic (e.g. a random-forest or boosted-tree engine). Should
   one fold seed cover the whole fold's work, or should the fold derive separate
   seeds for the tuning step and the outer fit? Which choice makes the result
   more robust to a future change in how many random draws `tune` makes
   internally — a change the repo explicitly does not promise stability across
   (IP2's final sentence)?

6. **Exit state: restore or advance?** M01's `nested_resamples()` deliberately
   leaves the caller's RNG stream exactly where `rsample::nested_cv()` would
   leave it, and a test pins that (`test-nested-resamples-rng.R` lines 36–52).
   Under any reseeding scheme, `nested_tune_grid()`'s exit state is otherwise
   whatever the last fold's seed left behind. Should `nested_tune_grid()`
   restore the caller's `.Random.seed` on exit, advance it by a defined amount,
   or leave it wherever the folds left it? Which is most consistent with
   tidymodels convention, and which best serves a user whose script calls the
   function and then does further random work?

7. **Can AC2 remain a genuine independent oracle?** Under your recommended
   scheme, the hand-rolled reference loop must reproduce the same per-fold
   seeding for its numbers to match. Propose a concrete construction that keeps
   AC2 an independent check of the *pipeline* (tuning → selection → finalization
   → outer fit) rather than a restatement of the seeding code — for example, by
   having the driver expose the fold seeds it used and the reference loop
   consume them as inputs, or by some better arrangement you can see. State any
   way your recommendation weakens AC2's independence, rather than leaving it
   for the implementer to discover.

8. **How is IP2 tested in a milestone that ships no parallelism?** M02 is
   serial, so the "regardless of workers" half of IP2 has no backend to exercise.
   Propose the specific test(s) that would demonstrate compliance now — a
   permuted fold-execution order asserting identical per-fold metrics is one
   candidate — and say what such a test does and does not establish about the
   parallel case that arrives in a later milestone.

## Constraints

Fixed, and not to be relitigated. Flag disagreement with a constraint
explicitly in your report rather than silently working around it.

- **D-002 — the contract boundary.** nestedtune orchestrates the outer loop and
  delegates inner tuning to `tune`. Recommendations that involve reimplementing
  any part of tune's tuning engine are out of scope.
- **D-010 — the exported API shape for M02** is settled: the function is
  `nested_tune_grid()`, it returns a standalone `nested_results` class that does
  **not** inherit `tune_results`, and it takes no `control` argument (it builds
  `control_grid(allow_par = FALSE)` internally). Do not re-open naming or class
  inheritance. You may, however, recommend *additional arguments* if the RNG
  answer requires one (a `seed` argument, say) — that is inside this brief's
  scope and D-010 does not foreclose it.
- **M02 scope is serial execution.** Parallelism over outer folds is a separate
  later milestone. Your recommendation must be implementable serially now, and
  must not foreclose the parallel milestone.
- **Dependency changes are gated.** The current hard dependencies are `rsample`,
  `cli`, `rlang`, and (added by this milestone) `tune`, `workflows`, `parsnip`
  (D-006, D-007, D-009). Any recommendation that adds another dependency —
  including base-priority packages like `parallel`, and including `withr` — must
  say so explicitly and justify it, because it triggers a separate maintainer
  gate and a recorded decision.
- **D-003 — pre-1.0, deprecation cycle waived.** Breaking changes are cheap
  right now. Do not water down a recommendation to preserve compatibility that
  the project has explicitly declined to promise.
- **IP2's own disclaimers hold.** Identity across R versions, across platforms,
  and across `tune` versions is deliberately *not* claimed. Do not recommend
  machinery whose only purpose is to defend a guarantee the package has
  explicitly declined to make.
- **GP2 — numeric results are oracle-verified** against at least two
  independent oracle types before shipping. AC2 (live reference implementation)
  and AC3 (invariant) are that pair for M02; a recommendation that collapses
  them into one type is a problem you should name.

## Output format

In `cairn/reviews/RR01-rng-streams-outer-folds.md`: answer each question by
number with your reasoning and evidence; list any additional findings separately
under "Beyond the brief"; end with concrete recommendations, each marked
apply / consider / reject-with-reason.

Where findings bind implementation, also emit a `## Binding criteria` section:
numbered `BC1…`, each a measurable assertion checkable against evidence, with
any numeric projection stating its tolerance. These are ingested VERBATIM into
M02's acceptance criteria and mechanically diffed against this file; departures
are legal only through a shown "Deviations from RR01" table. Keep binding
criteria to what genuinely binds — each one becomes a criterion the milestone
cannot ship without satisfying.
