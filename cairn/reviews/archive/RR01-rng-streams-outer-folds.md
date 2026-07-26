# RR01: Per-outer-fold RNG streams for the nested driver (M02)

- **Date:** 2026-07-25
- **Answers:** RB01 (`cairn/reviews/RB01-rng-streams-outer-folds.md`)
- **Reviewer basis:** All materials listed in RB01 read in full. `tune` was not
  installed in the checkout, so per the brief's instruction it was installed
  from CRAN (`tune` 2.1.0, with its dependency tree and `ranger` for a
  stochastic-engine probe) and its behavior **verified by execution**, not
  inferred. Source read at `tidymodels/tune` (dev 2.1.0.9000, matching 2.1.0 in
  the files cited). Every claim below is tagged *verified* (ran code or read
  the shipped source) or *inferred* (reasoned, not executed).

## The finding that reframes the question

The brief's three schemes were framed on the assumption that `tune_grid()`
consumes randomness from whatever stream it inherits. **That assumption is
false for tune >= 2.0.0, and the current CRAN version is 2.1.0.** The tune
2.0.0 rewrite (NEWS: "Sequential and parallel processing all use the same
L'Ecuyer-CMRG seeds (conditional on `parallel_over`)", #1033) made
`tune_grid()` manage its own per-resample RNG streams internally, *even when
execution is sequential*:

- `tune_grid_loop()` (`R/tune_grid_loop.R` lines 22–29) calls
  `get_parallel_seeds(nrow(resamples))` unconditionally for anything that is
  not `last_fit()`, with the comment "generate parallel seeds even if work is
  being executed sequentially".
- `get_parallel_seeds()` (`R/parallel.R` lines 183–206) snapshots the caller's
  `.Random.seed` and `RNGkind()`, switches to L'Ecuyer-CMRG, derives one
  substream per resample via `parallel::nextRNGSubStream()` /
  `nextRNGStream()`, and **restores the caller's kind and state on exit**.
- `.loop_over_all_stages()` (`R/loop_over_all_stages.R` lines 11–26) attaches
  packages first ("Some packages may use random numbers so attach them prior
  to initializing the RNG seed"), then assigns the resample's substream to
  `.Random.seed`, and restores the previous state via `withr::defer()`.
- `last_fit()` is the deliberate exception: its resamples get zero-length
  seeds ("For last_fit, we want to keep the RNG stream as-is to maintain
  reproducibility with manual execution"), so it consumes the ambient stream
  exactly as a hand-written `fit()` + `predict()` would.

Verified by execution against tune 2.1.0 with `control_grid(allow_par =
FALSE)` and a ranger workflow (all `identical()`, exact):

| Probe | Result |
|---|---|
| Same `set.seed()` before `tune_grid()` → identical per-fold metrics (stochastic engine) | TRUE |
| `.Random.seed` after `tune_grid()` == before (net-zero, kind restored too) | TRUE |
| `runif()` after `tune_grid()` == `runif()` with the call skipped entirely | TRUE |
| Result changes when entry seed changes | TRUE |
| Works, restores state and kind, when caller is already on L'Ecuyer-CMRG | TRUE |
| Permuting the rset's row order changes per-fold metrics (substreams are positional) | TRUE |
| `last_fit()` advances the caller stream and matches manual `fit()`+`predict()` under the same seed | TRUE |
| `tune_grid()` interposed between `set.seed()` and `last_fit()` leaves `last_fit()`'s numbers unchanged | TRUE |

Consequences: within a fold, **the entire stochastic outcome is a
deterministic function of exactly two RNG states** — the state at entry to
`tune_grid()` (from which tune derives its substreams and which it then
restores) and the state at entry to `last_fit()` (which it consumes
in-stream). `select_best()` and `finalize_workflow()` consume nothing.
Whatever scheme nestedtune picks only has to pin those two states per fold.
This is what makes the questions below mostly easy.

One more executed result that matters for Scheme B: when the caller is
*already* on L'Ecuyer-CMRG, `RNGkind("L'Ecuyer-CMRG")` inside
`get_parallel_seeds()` is **not** a state-preserving no-op — R re-seeds the
generator (deterministically) from the current state. So tune re-scrambles
whatever state it finds, MT or L'Ecuyer alike; a provably-independent
L'Ecuyer stream handed to a fold does **not** propagate its independence
guarantee into tune's internal substreams. Verified by execution.

## Answers

### 1. Does Scheme A satisfy IP2 as written?

**Yes, for (a) worker count, (b) serial vs parallel, and (c) execution order —
conditional on four implementation requirements.** Since fold work =
f(fold split, RNG state at fold start) (verified above), `set.seed(seed_i)` at
the top of fold *i* makes each fold's result a pure function of `(split_i,
seed_i)`, which no scheduler can perturb. The concrete ways it can still fail,
each with its fix:

1. **Seed assignment must be keyed to fold identity, not to execution
   sequence.** Draw all seeds once at entry, indexed by the fold's position in
   the M01 object. A parallel backend that hands folds to workers in
   completion-dependent order must look seeds up by fold index, never draw
   them worker-side.
2. **RNG kind divergence between serial and parallel runs.** `set.seed(s)`
   seeds *the currently active kind*. Serially, a caller who has set
   `RNGkind("L'Ecuyer-CMRG")` (or legacy `sample.kind = "Rounding"`) gets
   folds run under that kind; a fresh parallel worker defaults to
   Mersenne-Twister. Same seed, different numbers — an IP2 violation
   arriving exactly when the parallel milestone lands. Fix now: seed folds
   with the kind pinned, `set.seed(seed_i, kind = "Mersenne-Twister",
   normal.kind = "Inversion", sample.kind = "Rejection")`, and restore the
   caller's kind triple on exit. This is the one *latent* defect in Scheme A
   as stated in the brief.
3. **Worker-side RNG consumption before the seed is set.** Packages can
   consume randomness at load time; tune's own loop guards against exactly
   this (source comment quoted above). Serially this is moot (packages are
   loaded before the loop); the parallel milestone must load required
   packages in the worker *before* `set.seed()`. Bind the ordering now by
   making the seed call the first statement of the per-fold worker function.
4. **Backend re-seeding after our seed.** `future` with `future.seed = TRUE`
   assigns its per-element seed *before* evaluating the element, so a
   `set.seed()` inside the fold function overwrites it — safe (*inferred*
   from future's documented semantics, not executed; the parallel milestone
   must verify against its chosen backend). No path was found by which tune
   leaks a worker's inherited state into the result: tune re-derives its
   substreams from the state our `set.seed()` just established, and restores
   after (verified).

Not a failure of IP2 but worth stating: identity holds only for engines whose
randomness flows through R's RNG. parsnip's ranger template routes it through
R (`seed = sample.int(10^5, 1)`, `num.threads = 1` — verified); kernlab's SVM
and the deep-learning engines do not, and no R-side scheme can pin them (tune's
own docs say so). See Beyond the brief, B4.

### 2. Is the stream-correlation concern material here?

**Theoretical, not material.** Three independent reasons:

1. **Most of the randomness never runs on the MT streams Scheme A creates.**
   Everything inside `tune_grid()` runs on L'Ecuyer-CMRG substreams that tune
   derives by scrambling the fold's entry state (verified). Scheme A's MT
   seeds determine *which* substreams tune derives, plus the `last_fit()`
   draws. The cross-fold correlation question therefore reduces to: can two
   arbitrary derived L'Ecuyer states plus two arbitrary MT states be
   correlated enough to matter — the same theoretical residue Scheme B would
   leave (see Q3).
2. **The overlap/correlation probability is astronomically small.** The known
   hazard for arbitrarily seeded MT streams is subsequence overlap; for k
   streams of length L in a period P generator the union bound is ~k²L/P.
   With k ≤ hundreds of folds and L generously 10⁹ draws per fold, against
   P = 2^19937−1 this is beyond negligible. The documented MT seeding
   weaknesses (slow escape from low-entropy states, correlations from
   *sequential* small seeds under the pre-2002 initializer) do not apply:
   R scrambles `set.seed()`'s integer through an LCG warm-up, and Scheme A's
   seeds are themselves random draws, not 1..n.
3. **Even a correlation would not bias the point estimate.** Each fold's
   stream is marginally a valid MT stream, so E[metric_i] is unaffected by
   the joint seeding; correlation could only perturb the *co-variation of the
   Monte Carlo noise components* across folds. That noise is second-order
   against the dominant source of fold-to-fold variation — the data
   partitioning itself — so any deflation/inflation of the apparent spread is
   a perturbation of a minor variance component by a vanishing correlation.

No empirical demonstration of practically detectable cross-fold correlation
from R's MT seeding is known to me at this scale; the parallel-RNG literature's
insistence on designed streams (L'Ecuyer et al.) targets simulations where the
stream draws *are* the estimate, at draw counts many orders beyond this use.
Plainly: a real hazard for a billion-replicate Monte Carlo study; a
theoretical one for tens of folds of model fitting.

### 3. What does Scheme B actually buy, and what does it cost?

**It buys almost nothing here, because tune destroys the guarantee at its
boundary.** The verified re-scramble result above means tune's internal
substreams are derived by re-seeding from whatever state the fold establishes
— under Scheme B exactly as under Scheme A. The provable
`nextRNGStream()` independence would survive only for the draws nestedtune's
own state governs directly, i.e. `last_fit()`'s single fit per fold. The
guarantee delta over Scheme A is therefore precisely the theoretical residue
Q2 already dismissed.

The costs are concrete:

- **A new gated dependency** on `parallel` (base-priority, but D-006/D-007
  make any addition a maintainer gate).
- **Generator-kind surgery in an exported function.** Must capture and
  restore the full `RNGkind()` triple; handle `.Random.seed` not existing
  (reading it in a fresh session errors — tune's own `get_parallel_seeds()`
  does exactly that, verified); handle a caller already on L'Ecuyer (works,
  but the "already independent" state gets re-scrambled anyway); handle
  legacy `sample.kind = "Rounding"`. tune does this dance correctly, but tune
  *has* to — it is the component that consumes the randomness. nestedtune
  sits above a delegate that already does it.
- **Hand-replication becomes exotic.** Under Scheme A a fold is reproduced by
  `set.seed(seed_i)` plus the same tune calls — a natural hand loop, which is
  what GP1 and AC2 want. Under Scheme B replication requires assigning a raw
  `.Random.seed` vector, which the applied audience will never do, and the
  numbers match no plain-MT workflow under any user-visible seed.

**Reject Scheme B** (and Scheme C falls immediately: with inherited state,
fold i's numbers depend on how much randomness folds 1..i−1 consumed, so any
reordering or parallel execution changes results — it fails IP2(b) and (c) by
construction, as the maintainer already read it).

### 4. How does `tune::tune_grid()` itself interact with the RNG?

Answered in the opening section; summary with verification status:

- With `allow_par = FALSE`, `choose_framework()` returns `"sequential"`
  unconditionally (`R/parallel.R`, first branch — verified in source) and the
  loop is a plain `lapply()` (`.par_fns()` — verified in source). No future
  machinery is touched: `future.seed = TRUE` is attached only inside the
  `framework == "future"` branch of `loop_call()` (verified in source).
- It does **not** consume randomness from the current stream in a
  deterministic order; it **reseeds internally per resample** with
  L'Ecuyer-CMRG substreams derived from the entry state, runs each resample
  under its substream, and restores the caller's state and kind exactly
  (verified by execution, tune 2.1.0; net-zero confirmed by the `runif()`
  probe).
- Substream assignment is positional in the rset: permuting the rset's rows
  reassigns substreams and changes per-fold numbers (verified by execution).
- With exactly one resample and a non-empty grid, `.update_parallel_over()`
  flips `parallel_over` to `"everything"`, and every candidate then starts
  from the *same* resample seed rather than continuing one stream (source,
  `.loop_over_all_stages2()`; *inferred*, not executed). An inner
  `validation_split` would take this path; results remain deterministic given
  the entry state, so nothing for nestedtune changes.
- `last_fit()` alone runs with the ambient stream and matches manual
  execution (verified by execution).
- All of this is tune >= 2.0.0 behavior. tune 1.x used foreach and different
  seeding; NEWS for 2.0.0 states flatly that results differ from earlier
  versions. **M02 should pin `tune (>= 2.0.0)` in DESCRIPTION** — the
  invariances this review relies on do not hold below it.

### 5. Where must the seed be set within a fold?

**Two seeds per fold: one for the tuning step, one set immediately before
`last_fit()`.** Verified today, one seed would suffice: `tune_grid()` is
net-zero on the stream, so `last_fit()` would start from the pristine
post-`set.seed` state regardless of what tuning consumed. But that
sufficiency rests entirely on tune's current restore discipline — exactly the
kind of internal detail IP2's final sentence declines to promise stability
across. With a dedicated outer-fit seed, the outer fit's stream is independent
of tune's net RNG behavior *by construction*: a future tune that consumes or
reshuffles stream state changes only the tuning numbers (which a tune version
bump changes anyway), never the coupling. It costs one extra
`set.seed()` and keeps the AC2 hand loop just as natural (it sets the same two
seeds). It also removes the one aesthetic oddity of the single-seed design —
`last_fit()` drawing from the very state tune's substreams were derived from.

### 6. Exit state: restore or advance?

**Restore the caller's `.Random.seed` and `RNGkind()` triple to their entry
values exactly (net-zero).** Grounds:

- **It is the tidymodels convention for this kind of function.** tune >= 2.0's
  `tune_grid()`/`fit_resamples()` are exactly net-zero (verified). The
  advancing exception, `last_fit()`, advances *specifically* so its numbers
  match a manual fit — a property `nested_tune_grid()` cannot offer anyway,
  since it reseeds per fold. The closest analog is the resampling estimator,
  not the single fit.
- **It is the only exit state that is trivially identical under serial and
  parallel execution.** "Leave it wherever the folds left it" is
  serial-schedule-dependent and, under parallelism, main-process-vs-worker
  dependent — a downstream IP2 violation for any script that draws after the
  call. "Advance by a defined amount" is definable but has no precedent to
  match. Entry state is mode-independent by definition.
- A user who calls the function and then does further random work gets draws
  as if the call were not there — the same contract `tune_grid()` gives them
  today.

Two consequences to document and pin, not hide: (i) two consecutive
`nested_tune_grid()` calls with no reseeding in between return **identical**
results (true of `tune_grid()` 2.x as well — verified); (ii) this deliberately
diverges from M01's `nested_resamples()` convention of leaving the stream
where `rsample` would, because the delegate being mirrored differs — rsample's
constructor advances the stream, tune's estimator restores it. Note the
implementation guard: if `.Random.seed` does not exist at entry (fresh
session), reading it errors (verified); draw the fold seeds first —
`sample.int()` auto-initializes the RNG — and only then snapshot.

### 7. Can AC2 remain a genuine independent oracle?

**Yes, with the seeds-as-contract construction.** Concretely:

1. The results object **exposes each fold's (tuning seed, outer-fit seed)**,
   and the roxygen documents the replication contract: fold *i* is reproduced
   by `set.seed(tuning_seed_i)` → `tune_grid()` on the fold's inner rset →
   `select_best()` → `finalize_workflow()` → `set.seed(outer_fit_seed_i)` →
   `last_fit()` on the outer split. This is GP1 made mechanical, and it is
   user-facing value independent of testing.
2. The AC2 test derives its expected seeds **from the documented contract,
   not from the driver's output**: `set.seed(S)` and one
   `sample.int(.Machine$integer.max, 2 * n_folds)` call in the documented
   layout. It first asserts the driver's exposed seeds equal that derivation,
   then runs the hand-rolled loop with them and asserts identical per-fold
   metrics *and* identical selected parameters. Run it twice: once with a
   deterministic engine (isolates pipeline plumbing) and once with a
   stochastic engine (gives the test power against reseeding bugs — with a
   deterministic engine, every scheme including Scheme C passes AC2
   vacuously).

What this keeps independent: call order, argument plumbing, selection,
finalization, metric collection — the *pipeline* — all exercised by code that
shares nothing with the driver but two documented sentences. What it cannot
catch, stated rather than left to be discovered: (i) a defect *in the
contract itself* — if the documented derivation and the implementation are
both wrong in the same way, AC2 passes; the mitigations are that the contract
is exactly what this review has now examined, and that the derivation line in
the test is written from the docs, not copied from the source; (ii) a driver
that misassigns seeds to folds *and* misreports the assignment consistently —
excluded by deriving expected seeds in the test rather than consuming the
driver's report as ground truth. The brief's weaker alternative (reference
loop reads the seeds off the results object) would reopen (ii); do not use it.

### 8. How is IP2 tested in a milestone that ships no parallelism?

Precondition making any of this non-vacuous: **at least one test engine whose
fits consume R RNG** — ranger via parsnip qualifies (seed drawn from the R
stream, single-threaded by default; verified) — in Suggests with
`skip_if_not_installed()`. With a deterministic engine, every scheme passes
every RNG test.

The tests, in the spirit of the M01 RNG file:

1. **Same-seed identity (stochastic engine):** two full runs under the same
   `set.seed()` → `identical()` per-fold metrics and selected parameters.
2. **Seed sensitivity:** a different seed changes the numbers (guards the
   trivial pass, as M01's second test does).
3. **Execution-order invariance:** factor the driver so each fold runs
   through an internal per-fold worker that is a pure function of (outer
   split, inner rset, fold seeds, static inputs). The test invokes the
   workers directly in a permuted order (e.g. reversed) with the same seed
   assignment and asserts per-fold results identical to the driver's in-order
   run. This is the serial half of IP2's "independent of execution order",
   and the factoring it forces is itself the property the parallel milestone
   needs.
4. **Ambient-state independence of fold work:** the per-fold worker returns
   identical results whether the ambient state before it is MT, L'Ecuyer, or
   mid-stream garbage — this is what pinning the kind inside `set.seed()`
   buys, and it is exactly the fresh-worker condition of the parallel
   milestone simulated serially.
5. **Exit-state pin:** `.Random.seed` and `RNGkind()` identical before and
   after the call; a follow-up `runif()` matches a run without the call
   (M01's third test, adapted to the restore convention).

What these establish about the parallel case: that every input a worker needs
is explicit, every fold result is schedule-independent, and the fold
computation is insensitive to the ambient RNG conditions a fresh process
presents. What they do **not** establish, and the parallel milestone must test
with real multi-worker backends: package load-time RNG consumption in fresh
processes ordered before the worker's `set.seed()`; the backend's own seed
injection (`future.seed`, mirai's RNG handling) not interfering; globals
serialization preserving the seed table; and the exit-state contract when
folds ran in other processes. A serial permutation test is evidence of the
right factoring, not of backend behavior.

## Beyond the brief

- **B1 — tune version floor.** Everything above is tune >= 2.0.0 behavior;
  tune 1.x (foreach era) consumed and seeded differently, and NEWS 2.0.0
  declares cross-version irreproducibility. Without a `tune (>= 2.0.0)` pin,
  a user on an old tune gets a driver whose IP2 evidence was gathered on a
  different machine. (It also simplifies life: 2.0.0 removed foreach.)
- **B2 — AC3 cannot be "identical" with a stochastic engine.** Verified:
  `fit_resamples()` fold metrics under a fixed seed do not match any naive
  per-fold `set.seed()` hand loop, because tune assigns internal substreams
  positionally. Matching it from the driver would mean replicating
  `get_parallel_seeds()`'s derivation — coupling to tune internals for a test
  aesthetic. AC3 should therefore run a **deterministic engine** (where the
  invariant is exact and RNG-free — verified that `fit_resamples()` equals
  the unseeded hand loop for `linear_reg()`); AC2's stochastic variant
  carries the RNG burden. GP2's two-oracle-type structure survives intact:
  AC2 = live reference implementation, AC3 = invariant; nothing collapses.
- **B3 — fresh-session guard.** `.Random.seed` does not exist until the first
  draw; reading it unconditionally errors (tune's `get_parallel_seeds()`
  does, verified). The driver must draw seeds (auto-initializing) before
  snapshotting state for the exit restore.
- **B4 — IP2's enforceable scope should be written down.** Engines whose RNG
  does not flow through R (kernlab SVM — the engine the canonical nested-CV
  article uses — keras/tensorflow/torch) are irreproducible under *any*
  R-side scheme; tune's own docs disclaim them. A sentence in the roxygen
  (and eventually DESIGN.md next to IP2's existing disclaimers) keeps IP2
  honest: it binds randomness that R's RNG governs. Maintainer edit; not
  bound into M02's criteria here.
- **B5 — positional substreams are a user-facing subtlety.** Since tune's
  substreams are positional, reordering rows of an rset changes per-fold
  numbers (verified). nestedtune's per-fold seeding makes the same true of
  fold-seed assignment. No action needed; worth remembering when a future
  milestone lets users subset or reorder folds.

## Recommendations

1. **Apply — Scheme A, refined (call it A′):** at entry, draw
   `2 * n_folds` seeds in one documented `sample.int()` call; per fold, seed
   the tuning step and the outer fit separately with the RNG kind triple
   pinned; expose per-fold seeds on the results object; restore the caller's
   state and kind on exit. No new dependency; hand-replication stays a
   natural loop.
2. **Reject — Scheme B (L'Ecuyer streams):** its provable-independence
   guarantee does not survive tune's boundary (verified re-scramble), so it
   buys only Q2's theoretical residue at the price of a gated `parallel`
   dependency, kind-surgery edge cases, and an exotic replication story.
3. **Reject — Scheme C (inherit):** fails IP2(b)/(c) by construction; the
   maintainer's own reading is confirmed.
4. **Apply — pin `tune (>= 2.0.0)`** in DESCRIPTION when T1 adds it (B1).
5. **Apply — add `ranger` to Suggests** for the stochastic-engine tests,
   flagged explicitly as a dependency addition requiring its own gate/D-entry
   per D-006 convention. Without some R-RNG stochastic engine, every RNG test
   in M02 is vacuous; ranger is small, parsnip-native, single-threaded by
   default, and R-seeded (verified).
6. **Apply — AC3 runs a deterministic engine** (B2); AC2 runs both a
   deterministic and a stochastic variant.
7. **Reject — a `seed` argument on `nested_tune_grid()`:** unnecessary under
   A′ and contrary to the ecosystem convention tune documents verbatim
   ("always run set.seed() ... just prior"); the ambient-seed idiom plus
   exposed fold seeds covers every reproduction need surfaced here.
8. **Consider — document IP2's R-RNG scope** in the roxygen and DESIGN.md
   (B4); maintainer wording, outside M02's criteria.

## Binding criteria

Tolerances: every equality below is exact (`identical()`), same process, same
platform, same package versions — no numeric tolerance is granted or needed.

- BC1: `nested_tune_grid()` derives all per-fold seeds from the caller's RNG
  state at entry in a single documented `sample.int()` call producing one
  tuning seed and one outer-fit seed per outer fold, assigned by fold position;
  no seed is drawn inside the fold loop or worker.
- BC2: Each fold's work seeds the RNG with its own seeds and a pinned kind:
  the tuning step runs after `set.seed(<tuning seed>, kind = "Mersenne-Twister",
  normal.kind = "Inversion", sample.kind = "Rejection")` and `last_fit()` runs
  immediately after the same call form with that fold's outer-fit seed.
- BC3: The returned `nested_results` object exposes each fold's tuning seed
  and outer-fit seed, and the exported documentation states the
  hand-replication contract in terms of those seeds.
- BC4: On exit (including on error), `.Random.seed` and the full `RNGkind()`
  triple equal their entry values; a test asserts that draws following the
  call are identical to draws with the call absent. If `.Random.seed` does not
  exist at entry, the function neither errors nor leaves the session without a
  valid RNG state.
- BC5: DESCRIPTION declares `tune (>= 2.0.0)`.
- BC6: Same-seed identity is asserted with a stochastic engine whose
  randomness flows through R's RNG (ranger via Suggests, test skipped if
  unavailable): two runs under the same `set.seed()` produce `identical()`
  per-fold metrics and `identical()` selected parameters; a companion
  assertion shows a different seed changes the metrics.
- BC7: The per-fold computation is an internal function of (outer split,
  inner rset, fold seeds, static inputs) only; a test executes the folds
  through it in a permuted order and asserts per-fold results `identical()`
  to the driver's in-order output.
- BC8: A test asserts the per-fold worker's output for fixed seeds is
  `identical()` regardless of the caller's RNG kind and state at its
  invocation (at minimum: default Mersenne-Twister state and an
  L'Ecuyer-CMRG state).
- BC9: The AC2 reference-loop test derives its expected fold seeds from the
  documented contract (its own `set.seed()` + `sample.int()` call, not the
  driver's output), asserts they equal the exposed seeds, and then asserts
  the hand-rolled `tune_grid()` → `select_best()` → `finalize_workflow()` →
  `last_fit()` loop reproduces per-fold metrics and selected parameters
  `identical()`ly, in both a deterministic-engine and a stochastic-engine
  variant.
- BC10: The AC3 single-candidate-grid invariant against
  `tune::fit_resamples()` is asserted with a deterministic engine; no
  criterion claims stochastic-engine identity with `fit_resamples()`.
