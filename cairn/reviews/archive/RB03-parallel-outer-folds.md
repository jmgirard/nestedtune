# RB03: Parallel outer folds and the IP2 reproducibility contract (M07)

- **Date:** 2026-07-26
- **Output required:** write findings to `cairn/reviews/RR03-parallel-outer-folds.md`

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

**What has shipped.** Six milestones. M01 exports `nested_resamples()`, a
memory-lean replacement for `rsample::nested_cv()`. M02 exports
`nested_tune_grid()`, returning a `nested_results` object that keeps each outer
fold's selected parameters. M03 made a failed outer fold recorded rather than
fatal. M04 added the print method. M05 added `nested_final_fit()`. M06 added
the vignette. Execution is **serial** today: the loop is a plain `lapply()`.

**What this milestone (M07) is doing.** Making the outer loop run its folds
concurrently on `mirai` daemons. The intended change is narrow — replace the
`lapply()` at `R/nested-tune-grid.R:157` with a dispatcher that uses
`mirai::mirai_map()` + `mirai::collect_mirai()` when daemons are active, and
`lapply()` otherwise. Detection mirrors `tune`'s own:
`rlang::is_installed("mirai")` plus `mirai::status()$connections`. There is
deliberately no argument — the user starts daemons with `mirai::daemons(n)`
and parallelism follows, exactly as with `tune`. `mirai` goes in Suggests.

**The reproducibility contract.** IP2 (an inviolable principle of this
package) states: *the same seed produces the same result regardless of the
number of workers and regardless of whether execution is parallel or serial.*
The scheme that implements it was itself escalated to a prior review (RB01) and
settled as D-011:

> At entry `nested_tune_grid()` draws `2 * n_folds` seeds in one
> `sample.int()` call from the caller's state and assigns them by fold
> position; each fold seeds its tuning step and its outer fit separately with
> the RNG kind triple pinned (`kind = "Mersenne-Twister"`,
> `normal.kind = "Inversion"`, `sample.kind = "Rejection"`). […] On exit the
> caller's `.Random.seed` and `RNGkind()` triple are restored exactly.

D-011 explicitly **rejected** L'Ecuyer-CMRG streams via
`parallel::nextRNGStream()`, on RR01's finding that `tune` re-seeds from
whatever state it finds, so stream independence never reaches tune's own
substreams. D-011 also anticipated exactly this milestone:

> The kind pin is what makes a fresh parallel worker produce the same numbers
> as a serial run under a caller who set a non-default `RNGkind()` — the one
> latent defect in the unrefined scheme.

RR01 established by execution against tune 2.1.0 that tune >= 2.0.0 derives its
own per-resample L'Ecuyer-CMRG substreams *even under
`control_grid(allow_par = FALSE)`*, is net-zero on the caller's `.Random.seed`
and `RNGkind()`, and that `last_fit()` alone consumes the ambient stream. D-016
later extended the tuning seed's scope to cover building an `rset`, for
`nested_final_fit()`; `nested_tune_grid()` receives its resamples already built
and is unaffected.

**Evidence already gathered in this session.** Probes were run against mirai
2.7.2 using **bare `rnorm()` only — no `tune` involvement**. Findings:

- mirai pre-seeds each daemon with its **own distinct L'Ecuyer-CMRG stream**
  (`RNGkind()` inside a fresh daemon reads `L'Ecuyer-CMRG / Inversion /
  Rejection`). D-011's kind pin is therefore load-bearing, not theoretical.
- With `set.seed(s, kind = "Mersenne-Twister", normal.kind = "Inversion",
  sample.kind = "Rejection")` applied inside the worker, draws are
  **identical** across 1, 2, and 3 daemons and **identical to a serial
  `lapply()`**.
- `mirai_map()` leaves the caller's `.Random.seed` and `RNGkind()` triple
  untouched, including when the caller's ambient kind is `L'Ecuyer-CMRG`.
- Daemon RNG state **persists across `mirai_map()` calls**. An early probe
  read one question's answer off a previous question's residue and reported a
  false negative; all readings above were re-taken against freshly started
  daemons.

**Why this needs independent review.** The probes cover the RNG mechanics in
isolation. They do **not** cover the composition that actually ships:
`tune::tune_grid()` — which derives its own L'Ecuyer-CMRG substreams from
whatever state it finds — running inside a daemon that mirai has independently
placed on an L'Ecuyer-CMRG stream, with our Mersenne-Twister pin applied in
between. This package has been burned by exactly this class of gap before: a
recorded lesson from M02 reads *"with a deterministic engine every RNG test
passes vacuously, including under seeding schemes that are wrong."* A test
suite that looks thorough and proves nothing is the specific failure mode to
guard against here, and IP2 is the principle at stake.

## Materials

Work in the repository root. The branch is `m07-parallel-outer-folds`; use
ref-based git only (`git diff`, `git show`, `git log`) — never `git checkout`,
`git switch`, `git worktree`, or `git reset`, as this checkout is shared.

Read:

- `R/nested-tune-grid.R` in full. The loop to be replaced is at lines 157–166;
  the per-fold worker `nested_fold_fit()` is lines 180–245; `failed_fold()` is
  250–262; the seeding and restoration helpers `set_fold_seed()` and
  `restore_rng()` are 343–364. The roxygen `@section Reproducibility:` block
  (lines 37–68) is the documented contract.
- `cairn/milestones/M07-parallel-outer-folds.md` — the milestone plan, its nine
  acceptance criteria, and its work log.
- `cairn/DECISIONS.md` entries **D-011** and **D-016** in full. D-011 is the
  RNG contract; D-016 amends its scope for resample construction.
- `cairn/DESIGN.md` — the IP/GP principle block, and the conventions
  "Parallelize the outer loop; keep `tune` serial within it" and "Performance
  is a design constraint, not a later optimization."
- `cairn/reviews/archive/RR01-rng-streams-outer-folds.md` — the prior review
  that settled the seeding scheme, including its verified probe table.
- `tests/testthat/helper-orchestration.R` — the fixtures, notably
  `stoch_workflow()` (ranger, single-threaded, draws from R's RNG) and
  `det_workflow()` (deterministic, and therefore vacuous for RNG assertions).

Environment: R 4.6, `tune` 2.1.0, `mirai` 2.7.2, `ranger` installed. You may
run R freely. `mirai::daemons(n)` starts daemons; `mirai::daemons(0)` stops
them. Always start fresh daemons per measurement — state persists otherwise,
which is the trap noted above.

## Questions

1. **Does the kind pin compose correctly with tune inside a daemon?** With
   `set_fold_seed()` applied inside a mirai daemon that mirai has placed on its
   own L'Ecuyer-CMRG stream, does a full `tune::tune_grid()` +
   `select_best()` + `last_fit()` sequence with the `ranger` engine produce
   results identical to the same sequence run serially from the same seed?
   Verify by execution, not by reading. If it does not, identify precisely
   where the divergence enters.

2. **Is the planned verification design sufficient, or is it vacuous?** M07's
   AC1–AC3 assert serial/parallel identity with `ranger`, at two daemon counts,
   under a caller-set non-default `RNGkind()`. Given M02's lesson that
   deterministic engines make RNG tests pass vacuously: would this suite
   actually fail against a *wrong* implementation? Construct at least one
   plausible wrong dispatcher (for example, one that omits the kind pin, or
   that draws seeds inside the worker rather than assigning them by position)
   and state whether each criterion reddens against it. Name any criterion that
   passes against a wrong implementation.

3. **Is there a residual state-leakage failure mode across daemons?** Daemon
   RNG state persists between `mirai_map()` calls. Since `nested_fold_fit()`
   sets its own seed unconditionally at entry, is the loop genuinely immune to
   whatever state a previous unrelated task left on that daemon — including a
   previous `nested_tune_grid()` call, a previous `tune` call by other code, or
   a user's own task? Is there any path by which fold `i`'s result depends on
   what ran on its daemon before it?

4. **Worker failure and IP4.** `nested_fold_fit()` catches errors internally
   and returns a record. A failure *outside* that — a `miraiError`, a daemon
   that dies mid-task, a serialization failure — surfaces differently. IP4
   states that no estimate is reported as though it came from a design that did
   not run. Does routing such failures through the existing `failed_fold()`
   discharge IP4 faithfully? Is there any way a dead or failing daemon can
   yield a result that is recorded as a *completed* fold?

5. **What must the daemon have loaded?** `nested_fold_fit()` is an internal,
   unexported function. Determine empirically what `mirai_map()` requires for
   it to run on a daemon — whether the package must be installed in the
   daemon's library, whether `devtools::load_all()` development workflow works,
   and whether the split objects and workflow serialize faithfully. State any
   user-visible constraint this creates that must be documented (GP1 requires
   documented divergence, never silent).

6. **Does parallel dispatch endanger IP1?** IP1 forbids the outer assessment
   set influencing anything upstream of its own scoring. Dispatch sends each
   fold's split to a worker. Is there any mechanism — shared state, object
   aliasing, mirai's own caching — by which parallel execution could leak
   across the outer boundary in a way serial execution does not? A negative
   answer with reasoning is a perfectly good answer here.

## Constraints

Fixed; do not relitigate. Flag disagreement explicitly rather than silently
working around it.

- **D-011** fixes the seeding scheme: `2 * n` seeds drawn at entry from the
  caller's state, assigned by fold position, kind triple pinned per fold,
  caller's state restored on exit. M07 reuses it and must not redesign it.
- **D-011 rejected** L'Ecuyer-CMRG streams via `parallel::nextRNGStream()`.
  If your findings genuinely require reopening that, say so explicitly and
  argue it — it would need a superseding decision entry, not a quiet change.
- **mirai is the chosen backend**, settled at the M07 plan gate; `future` and a
  user-supplied mapper were both declined. Backend choice is not open.
- **Parallelism stays over the outer folds only.** `control_grid(allow_par = FALSE)`
  remains forced inside each fold; nested parallelism oversubscribes cores.
- **GP4 is subordinate to IP2.** Where speed and reproducibility conflict,
  reproducibility wins, and the faster option is rejected on that basis.
- The package is **pure R** — no compiled code of its own, no `src/`.
- Do not modify any file outside `cairn/reviews/RR03-parallel-outer-folds.md`.
  Recommend changes; do not implement them.

## Output format

In `RR03-parallel-outer-folds.md`: answer each question by number with your
reasoning and the evidence (including code you ran and its output) behind it.
List any additional findings separately under "Beyond the brief". End with
concrete recommendations, each marked apply / consider / reject-with-reason.

Where findings bind implementation, also emit a `## Binding criteria` section:
numbered `BC1…`, each a measurable assertion checkable against evidence, with
any numeric projection stating its tolerance. These are ingested VERBATIM into
M07's acceptance criteria and mechanically diffed against this file, so write
them as criteria a test can be pointed at, not as prose advice.
