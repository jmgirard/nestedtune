# RR03: Parallel outer folds and the IP2 reproducibility contract (M07)

- **Date:** 2026-07-26
- **Answers:** RB03 (`cairn/reviews/RB03-parallel-outer-folds.md`)
- **Reviewer basis:** All materials listed in RB03 read in full
  (`R/nested-tune-grid.R`, the M07 milestone file, D-011 and D-016,
  DESIGN.md's principle block and conventions, RR01, and
  `tests/testthat/helper-orchestration.R`). Environment: R 4.6.1, tune 2.1.0,
  mirai 2.7.2, ranger 0.18.0, all on this machine. Every probe below was
  **run by execution** against fresh daemons per measurement (the brief's
  state-persistence trap was respected: `daemons(0)`/`daemons(n)` brackets
  every reading). Claims are tagged *verified* (executed) or *inferred*
  (reasoned, not executed). Probe fixtures mirror
  `helper-orchestration.R`'s `stoch_workflow()` (ranger, 25 trees,
  `num.threads = 1`, `min_n` grid {2, 10, 25}) and `det_workflow()`, on a
  3-outer x 3-inner `nested_cv()` design over the same 90-row generator.
  `nestedtune` is not installed in any library on this machine, which made
  the Q5 loading probes clean.

## Answers

### 1. Does the kind pin compose correctly with tune inside a daemon?

**Yes. Verified by execution, exactly and at every daemon count probed.**
The full per-fold composition — `set_fold_seed(s1)` → `tune::tune_grid()`
(with `control_grid(allow_par = FALSE)`) → `select_best()` →
`finalize_workflow()` → `set_fold_seed(s2)` → `last_fit()` — was run with
the ranger workflow serially in the host and via `mirai_map()` +
collection on fresh daemons, seeds drawn once at entry
(`set.seed(2026); sample.int(.Machine$integer.max, 2 * 3)`) and assigned
by fold position:

| Probe | Result |
|---|---|
| Daemon ambient `RNGkind()` (all daemons, all counts) | `L'Ecuyer-CMRG / Inversion / Rejection` |
| Parallel (1 daemon) `identical()` to serial, all folds, metrics + selected | TRUE |
| Parallel (2 daemons) `identical()` to serial | TRUE |
| Parallel (3 daemons) `identical()` to serial | TRUE |
| Caller's `.Random.seed` and `RNGkind()` untouched by `mirai_map()` + collect | TRUE |
| Power guard: different entry seed changes the serial result | TRUE (not vacuous) |

The mechanism is the one D-011 and RR01 predicted: `set_fold_seed()`'s
pinned `set.seed()` overwrites whatever generator the daemon sits on
(mirai's own L'Ecuyer-CMRG stream) and establishes the identical
Mersenne-Twister state a serial run has at the same point; tune then
derives its per-resample substreams from that state and restores it
(RR01, verified there), and `last_fit()` consumes the pinned outer-fit
state. No divergence enters anywhere in the composition. The same
identity was re-verified end-to-end through the real
`nestedtune:::nested_fold_fit()` running from an installed copy on 2
daemons (see Q5): completed folds byte-identical to the serial run.

One scoping caveat found under Q5 and binding here: the identity is exact
for every fold-record field **except the `trace` column of `.notes`** when
a fold carries notes — rlang backtraces record the call stack, and a
daemon's stack (`mirai::daemon(...)` frames) can never equal the host's.
Note *text*, location, and type are identical; only the trace objects
differ (verified; see Q5 and BC6).

### 2. Is the planned verification design sufficient, or is it vacuous?

**Not vacuous with ranger — but one criterion as currently worded passes
against a wrong implementation, and one hole needs its existing guard
named.** Four wrong dispatchers were built and executed:

- **W1 — kind pin omitted** (plain `set.seed()` in the worker):
  - AC1 (default caller kind, 1 daemon): parallel != serial → **reddens**
    (verified). The daemon sits on L'Ecuyer-CMRG, so the unpinned seed
    seeds a different generator than the serial run's Mersenne-Twister.
  - **AC3 with caller `RNGkind("L'Ecuyer-CMRG")`: PASSES against W1**
    (verified `identical()` TRUE). The caller's kind triple
    (L'Ecuyer/Inversion/Rejection) then coincides exactly with the daemon's
    ambient triple, so the unpinned `set.seed()` produces the same state on
    both sides. L'Ecuyer-CMRG is the one non-default kind with **zero**
    detection power against the missing pin.
  - AC3 with caller `RNGkind("Wichmann-Hill")`: **reddens** (verified).
- **W2 — seeds drawn inside the worker** from the daemon's ambient state:
  AC1 **reddens** (verified); W2 is not even self-reproducible across
  daemon restarts (verified FALSE).
- **W3 — caller state copied to each daemon, workers draw own seeds in
  arrival order**: reddens at every daemon count (verified) — the pin
  inside the fold destroys the shared stream between draws.
- **W4 — chunk-scheduled dispatcher** (each daemon gets the caller's
  post-`set.seed` state and draws seeds for its fold subset locally):
  **AC1 passes at 1 daemon** (verified `identical()` TRUE — sequential
  split draws reproduce the single `sample.int()` call exactly, also
  verified in isolation); **AC2 reddens at 2 daemons** (verified). AC2 is
  therefore not redundant with AC1: it is the only criterion that catches
  schedulers wrong in a way that degenerates to correct at one worker.
- **M02's lesson confirmed live**: W1 run with the deterministic
  PCA + lm workflow passes AC1 **vacuously** (verified `identical()` TRUE,
  wrong implementation, deterministic engine). The ranger requirement in
  AC1 is load-bearing, not decorative.

Two structural limits of the AC1–AC3 design, with their guards:

1. **AC1's power against the missing pin currently rests on mirai's
   incidental choice** to pre-seed daemons with L'Ecuyer-CMRG. A future
   mirai that left daemons on default Mersenne-Twister would make W1 pass
   AC1 under a default-kind caller — at which point a correctly-chosen
   AC3 kind is the *only* criterion that reddens. AC3 must therefore use
   a kind that is neither Mersenne-Twister nor L'Ecuyer-CMRG
   (Wichmann-Hill verified to redden) — see BC2.
2. **A symmetrically wrong implementation passes all of AC1–AC3.** Any
   defect present identically in the serial and parallel paths (e.g. both
   deriving seeds as a function of fold index instead of the caller's
   entry state) preserves serial/parallel identity while breaking the
   documented contract. The guard already exists: the contract-derived
   reference-loop oracle (`reference_nested_loop()`, written from the
   docs, never from the driver). It anchors absolute correctness; the
   AC1–AC3 identities anchor mode-independence. Both must stay in the
   suite (BC7).

One more vacuousness trap, from reading tune's own detection: tune goes
parallel only at `status()$connections >= 2` (`tune:::choose_framework`,
read in source — "too few workers" → sequential). If M07's detection
mirrors that threshold, a test that starts **one** daemon and expects the
parallel path exercises serial-vs-serial and proves nothing. Every
identity test must assert the parallel branch actually ran (BC1).

### 3. Is there a residual state-leakage failure mode across daemons?

**On the RNG channel: no — verified immune.** With fold 1's result on a
fresh daemon as baseline, the same fold was re-run on daemons polluted by
prior tasks, `identical()` to baseline in every case:

| Pollution left by a prior task on the daemon | Fold identical to fresh daemon |
|---|---|
| `RNGkind("Knuth-TAOCP-2002", "Box-Muller")` + `sample.kind = "Rounding"` + 10^4 draws | TRUE |
| A full prior fold run (residue of a previous nested call, different seeds) | TRUE |
| Global-environment scribbles shadowing `seeds`/`wf` + `options()` change + `set.seed(1)` | TRUE |

The pin covers all three kind components, so even the legacy `Rounding`
sample-kind residue is neutralized. Globals cannot shadow the worker's
inputs because `mirai_map()` supplies `.args` as function arguments, not
via the daemon's global environment (verified by the scribble probe).
Since `nested_fold_fit()` reads nothing ambient except the RNG state it
immediately overwrites, and every stochastic stage downstream re-derives
from that pinned state (RR01), there is no path by which fold *i*'s
*numbers* depend on what ran before it on that daemon.

**Outside the RNG channel: a documented-divergence class exists, not a
correctness defect in the loop.** Verified: `options()` and environment
variables set by one task persist into later tasks on the same daemon;
and a caller's session options do **not** transfer to daemons (probe:
option set in host reads `ABSENT` in daemon). So a fold's behavior can in
principle depend on daemon-session state (a user's own `everywhere()`
calls, a prior task's `options()`), and a caller who relies on session
state (e.g. `options(warn = 2)`, non-default `contrasts`) gets the
daemon's defaults instead (*inferred* impact; persistence and
non-transfer both verified). This is inherent to persistent daemons and
identical in kind to what `tune`'s own mirai parallelism exposes; the
right discharge is GP1 documentation — daemons are fresh R processes that
do not inherit the calling session — not engineering (BC8).

### 4. Worker failure and IP4

**Routing through `failed_fold()` can discharge IP4 faithfully, but not
with condition-based detection, and interrupts must not be recorded as
failures.** The failure surfaces, all verified by execution on mirai
2.7.2:

| Event | Collected value | `is_mirai_error` | `is_error_value` | `inherits(., "condition")` | `conditionMessage()` |
|---|---|---|---|---|---|
| Error raised in task | `miraiError` (classes `miraiError/errorValue/try-error`) | TRUE | TRUE | **FALSE** | works ("boom") |
| Daemon killed mid-task | `errorValue` int 19, prints "Connection reset" | FALSE | TRUE | **FALSE** | **errors** |

Consequences for the dispatcher:

- `inherits(x, "condition")` — the idiom `nested_fold_fit()` uses
  internally — catches **neither** shape. `conditionMessage()` **errors**
  on an `errorValue`. Detection must use `mirai::is_mirai_error()` /
  `mirai::is_error_value()`, or better, positive validation of the fold
  record shape (BC3). Note text for an `errorValue` is available as
  `nanonext::nng_error(as.integer(x))` → `"19 | Connection reset"`
  (verified); `as.character()` alone yields just `"19"`.
- **A dead daemon cannot yield a completed fold.** Verified: the
  in-flight task on a killed daemon returns `errorValue` 19; queued tasks
  are redistributed to surviving daemons and complete; a side-effect
  counter (each task appends to a file) shows **every task ran exactly
  once** — no retry, so no double-execution and no partial result can
  masquerade as complete. `nested_fold_fit()` returns only at its end, so
  there is no partial-record path either.
- **All daemons dead is a hang, not a wrong answer.** Verified: with the
  sole daemon killed and tasks queued, the tasks remain unresolved
  indefinitely (`status()$connections` = 0; still unresolved after 20 s;
  collection would block). `daemons(0)` or a user interrupt resolves
  them (to `errorValue`s / `miraiInterrupt`). IP4 is not violated — no
  estimate is reported — but the behavior must be documented (BC8), and
  the dispatcher must not collect with mirai's `.stop` option, which
  would abort the run on the first failure and discard completed folds
  (contra M03).
- **Stage label**: an infrastructural failure is neither `"inner tuning"`
  nor `"outer fit"` — the run cannot know which stage the worker died in.
  `failed_fold()` accepts any stage string; use a dedicated label (e.g.
  `"worker"`) so the note names what is actually known (IP4: record what
  ran, not a guess).
- **`miraiInterrupt` is not a fold failure.** A user interrupt during
  collection is a cancelled run, not a design that failed. Recording
  interrupted folds via `failed_fold()` would let a cancelled run
  masquerade as a completed run with failures — an IP4 inversion. Rethrow
  it and let the existing `on.exit()` restore the caller's RNG state
  (BC4).

### 5. What must the daemon have loaded?

**The daemon must be able to load `nestedtune` from an installed library;
`devtools::load_all()` alone does not reach the daemons.** Verified, with
`nestedtune` deliberately absent from every library:

| Probe | Result |
|---|---|
| Closure over a local environment passed via `.args` | Captured values transfer (returns 42) — ordinary environments serialize fine |
| `nestedtune:::nested_fold_fit` (namespace closure) passed to a bare daemon | Deserializes, but its environment **falls back to `R_GlobalEnv`**; running it fails: `could not find function "set_fold_seed"` |
| `nestedtune:::nested_fold_fit` referenced by name in the task, bare daemon | `miraiError`: `there is no package called 'nestedtune'` |
| Same closure passed after `everywhere(pkgload::load_all(pkg))` | Environment resolves to the `nestedtune` namespace; works |
| Package installed to a scratch lib; host does `.libPaths(c(lib, ...))` (session-only) | Daemon **cannot** load it — `.libPaths()` changes do not propagate |
| Same, with `R_LIBS=<lib>` set in the env before `daemons(n)` | Daemon loads it — daemons inherit environment variables |
| Full `nested_fold_fit` on 2 daemons from the installed copy vs serial host | Completed folds `identical()`; failed fold identical in every field **except `notes$trace`** |

The trace finding: for a fold that fails (or completes with notes),
`completed`, `metrics`, `selected`, and the notes' `location`/`type`/
`note` text are all `identical()` serial vs parallel; only the
`rlang_trace` objects in the `trace` column differ (host stack, 50
frames, vs daemon stack rooted at `mirai::daemon(...)`, 35 frames —
verified on the same engineered inner-tuning failure the test helpers
use). Traces are execution-context diagnostics; the IP2 identity claim
and every serial-vs-parallel assertion must scope them out (BC6), and the
docs should say so in one sentence.

User-visible constraints this creates (GP1 — documented, never silent):

- Parallel execution requires `nestedtune` installed where the daemons
  can load it. For local `mirai::daemons(n)` this is automatic for any
  user who installed the package normally (daemons inherit the
  environment, hence the same library paths). For remote daemons the
  package must be installed on the remote host (*inferred* from the same
  mechanism; not probed).
- The development workflow is the sharp edge: under
  `devtools::load_all()` with no installed copy, every fold dispatched to
  a daemon fails (cleanly, as `miraiError` → recorded failures, if BC3's
  routing is implemented — but all-folds-failed is a confusing way to
  discover a loading problem). Worse, with a **stale installed copy**
  present, daemons silently run the stale code while the host runs the
  dev code. T5 should prime daemons with
  `everywhere(pkgload::load_all(<path>))` when running under pkgload
  (verified working), and rely on the installed copy otherwise —
  `R CMD check` installs the package and passes the library through the
  environment, which daemons inherit (mechanism verified via the
  `R_LIBS` probe; the check-time path itself is *inferred* and AC9's
  check runs will confirm it).
- Split and workflow objects serialize faithfully — the end-to-end
  identity is the proof. Each task ships its fold's full split data;
  payload size is the already-tracked candidate row, not an M07 concern.

### 6. Does parallel dispatch endanger IP1?

**No.** Mechanism by mechanism, with the probes that close each:

- **Process isolation, copy semantics.** Each daemon receives serialized
  *copies* of its fold's split, inner rset, and the static inputs; the
  only channel back to the host is the returned fold record. There is no
  shared memory, no aliasing across processes; a daemon mutating its copy
  can affect nothing else (structural property of mirai's transport;
  copies verified faithful in Q5).
- **No new data exposure.** The worker receives exactly what the serial
  loop's `nested_fold_fit()` already receives — including the outer
  split, whose assessment rows were always present in-process serially.
  Dispatch changes where the fold runs, not what it sees. Inner resamples
  are built upstream of M07, from analysis data only; M07 does not touch
  construction.
- **No mirai-side caching or replay.** `daemons()`' `memory` argument is
  queue backpressure, not result caching (docs read); tasks are
  independent, collected positionally, and verified to run exactly once
  each even under daemon death (Q4's side-effect counter).
- **Daemon-persistent state as a leakage channel** — the one mechanism
  parallel execution genuinely adds (fold *j*'s residue visible to fold
  *i*'s task on the same daemon) — is closed for this worker because
  `nested_fold_fit()` reads nothing ambient except the RNG state it
  overwrites: the Q3 pollution probes, including a prior fold's own
  residue, produced `identical()` results.
- **No accidental nested parallelism.** Inside a daemon,
  `mirai::status()$connections` is 0 and `tune:::get_mirai_workers()`
  reports 0 (verified) — the host's pool is invisible to its daemons —
  and `control_grid(allow_par = FALSE)` is forced regardless. tune inside
  the daemon cannot re-partition anything across workers.

## Beyond the brief

- **B1 — tune's parallel threshold is 2 workers.** `tune` stays
  sequential at `status()$connections < 2` (source, verified). "Detection
  mirrors tune's" therefore implies a >= 2 threshold, and any test that
  starts 1 daemon and assumes the parallel path would be vacuous. Decide
  the threshold explicitly and make identity tests assert the branch
  taken (BC1). Results are IP2-identical either way, so this is test
  design and doc wording, not correctness.
- **B2 — `daemons(seed=)` exists** (mirai 2.7.2 formals). It seeds the
  daemons' own L'Ecuyer streams; irrelevant to the scheme — the pin
  overwrites daemon state unconditionally, and the Q3 probes cover
  arbitrary prior state. No action.
- **B3 — collection semantics.** The dispatcher should collect with the
  plain blocking collect (results in place, errors as values). mirai's
  `.stop` collection option aborts on first error — incompatible with
  M03's record-don't-abort discipline. Per-task `.timeout` exists (with
  dispatcher) and would convert the all-daemons-dead hang into
  `errorValue` 5, but see recommendation 10.
- **B4 — mirai strips nothing it shouldn't.** Ordinary closures with
  captured locals transfer intact (verified); the `R_GlobalEnv` fallback
  applies specifically to namespace environments that the daemon cannot
  reconstruct. Worth knowing when reading future mirai NEWS, since Q2's
  AC1 power and Q5's loading behavior both rest on current mirai
  behavior.

## Recommendations

1. **Apply** — Dispatcher validates every collected element by positive
   fold-record shape check and routes failures through `failed_fold()`
   with a dedicated worker stage label; never `inherits(x, "condition")`
   (catches neither mirai shape) and never `conditionMessage()` on an
   `errorValue` (errors). Use `nanonext::nng_error()` for `errorValue`
   note text. (Q4; BC3.)
2. **Apply** — Rethrow `miraiInterrupt` as an abort; a cancelled run must
   not be recorded as a run with failed folds. (Q4; BC4.)
3. **Apply** — AC3's non-default kind must be neither Mersenne-Twister
   nor L'Ecuyer-CMRG (Wichmann-Hill verified). As written, AC3 run with
   L'Ecuyer-CMRG passes against the missing kind pin. (Q2; BC2.)
4. **Apply** — Every serial-vs-parallel identity test asserts the
   parallel branch actually executed (detection helper reports parallel /
   dispatch evidence), with daemon counts at or above the chosen
   threshold. (Q2, B1; BC1.)
5. **Apply** — Keep the existing contract-derived `reference_nested_loop`
   oracle tests green and untouched; they close the symmetric-wrong hole
   AC1–AC3 cannot see. (Q2; BC7.)
6. **Apply** — Scope `notes$trace` out of the IP2 identity claim: one doc
   sentence, and serial-vs-parallel assertions on note-carrying folds
   exclude the trace column. (Q5; BC6.)
7. **Apply** — Document under GP1: enablement via `mirai::daemons(n)`;
   inner tuning stays serial and why; results identical to serial at any
   worker count; daemons are separate R processes that inherit neither
   session options nor `.libPaths()` changes (env vars yes); the package
   must be installed where daemons can load it (`load_all()` is not
   enough); if every daemon dies the call blocks until interrupted.
   (Q3, Q4, Q5; BC8.)
8. **Consider** — A pre-flight round-trip at dispatch
   (`mirai(requireNamespace("nestedtune"))`-style) that fails fast with
   an informative message, or falls back to serial with a warning, when
   daemons cannot load the package. Costs one round-trip; the
   alternative — every fold failing with the same cryptic note — is a
   poor discovery path for the one setup error users will actually make.
   (Q5.)
9. **Consider** — T5 primes daemons with
   `everywhere(pkgload::load_all(<path>))` when `pkgload::is_dev_package("nestedtune")`,
   avoiding both the bare-daemon failure and the stale-installed-copy
   skew during development; under `R CMD check` the installed copy is
   used. (Q5.)
10. **Reject — per-task `.timeout` as a hang mitigation.** There is no
    defensible universal timeout for model fits; a chosen number converts
    a legitimately slow fold into a recorded failure, which is a worse
    IP4 outcome than a hang the user can see and interrupt. Document the
    hang instead (BC8).
11. **Reject — reopening D-011.** Nothing found requires it. The scheme
    composes with tune inside daemons exactly as designed; the kind pin
    is confirmed load-bearing (Q1, Q2). L'Ecuyer stream seeding stays
    rejected.

## Binding criteria

Every equality is exact (`identical()`), same machine, same package
versions; no numeric tolerance is granted or needed.

- BC1: With daemons active, `nested_tune_grid()` returns a result
  `identical()` to the serial (daemons-off) result from the same entry
  seed, using the ranger stochastic workflow, at two daemon counts both
  at or above the implementation's parallel-dispatch threshold; each such
  test also asserts that the parallel branch was selected for the run, so
  the identity is never serial-vs-serial.
- BC2: The non-default-`RNGkind()` identity test (AC3) sets a caller
  generator kind that is neither `"Mersenne-Twister"` nor
  `"L'Ecuyer-CMRG"` (e.g. `"Wichmann-Hill"`), and a comment records why:
  a pin-less implementation reproduces serial results exactly under a
  caller on L'Ecuyer-CMRG because mirai daemons sit on that same kind.
- BC3: The dispatcher classifies each collected element by positive
  validation of the fold-record shape; any element failing validation —
  including a `miraiError` and an `errorValue` from a daemon that died
  mid-task, neither of which inherits `"condition"` — is recorded via
  `failed_fold()` with `.completed` FALSE and a note whose stage names
  the worker/infrastructure, and the run returns rather than aborting. A
  test kills a daemon mid-run and asserts: the affected fold has
  `.completed` FALSE, every other fold's record is `identical()` to its
  serial counterpart, and no fold executed more than once.
- BC4: A `miraiInterrupt` collected from a worker is not recorded as a
  failed fold: the call aborts, and the caller's `.Random.seed` and
  `RNGkind()` triple are restored per the existing exit contract.
- BC5: The dispatcher's collection does not use mirai's `.stop` option or
  any mechanism that discards completed folds on first failure.
- BC6: Serial-vs-parallel comparisons of any fold whose `.notes` is
  non-empty exclude the `trace` column and assert `identical()` on all
  other fold-record fields, including the notes' `location`, `type`, and
  `note` text; the exported documentation states that backtraces inside
  `.notes` reflect where the fold executed and are outside the
  reproducibility identity.
- BC7: The contract-derived reference-loop oracle tests
  (`reference_nested_loop()` and its assertions) remain present and
  passing, unmodified in their derivation-from-documentation structure.
- BC8: The documentation added by T6 states all of: parallelism is
  enabled solely by `mirai::daemons(n)` with no argument on
  `nested_tune_grid()`; inner tuning remains serial; results are
  identical to a serial run regardless of daemon count; daemons are
  separate R processes that do not inherit the calling session's options,
  environment variables set after launch, or `.libPaths()` changes; the
  package must be installed in a library the daemons can load, which
  `devtools::load_all()` alone does not provide; and a run whose daemons
  have all died blocks until interrupted.
- BC9: A pollution-immunity test executes a fold on a daemon on which
  prior tasks have changed the RNG kind triple (including
  `sample.kind = "Rounding"`), consumed draws, run a prior fold, and
  written to the daemon's global environment, and asserts the fold record
  is `identical()` to the same fold on a freshly started daemon.
