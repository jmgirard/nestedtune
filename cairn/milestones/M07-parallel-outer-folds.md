<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M07: Parallel outer folds

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M02   <!-- owner: plan · create/amend-via-gate -->
- **Driving RR:** RR03   <!-- owner: plan · create/amend-via-gate -->
- **Principles touched:** IP2, GP1, GP3, GP4   <!-- owner: plan · create/amend-via-gate -->
- **Branch/PR:** `m07-parallel-outer-folds`   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal

`nested_tune_grid()` runs its outer folds concurrently on mirai daemons when
the user has started them, producing results identical to a serial run.

## Scope

**In:** Dispatch of the existing per-fold worker over mirai daemons, detected
as `tune` detects them and enabled by `mirai::daemons(n)` alone (M07-D1).
`mirai` joins Suggests; below threshold the loop stays serial and unchanged.
Worker failure is a recorded fold failure, an interrupt an abort (M07-D2).
The D-011/D-016 reproducibility contract is reused, never redesigned.

**Out**, none carrying a ROADMAP row: L'Ecuyer-CMRG stream seeding (D-011,
RR03 rec 11) · parallelism inside `tune` · a `future` backend and a
user-supplied mapper (plan gate) · per-task `.timeout` (RR03 rec 10; the
all-daemons-dead hang is documented instead, BC8) · parallelizing
`nested_final_fit()`. Plotting instability and per-worker payload size →
candidate rows.

## Acceptance criteria

- [ ] AC1 (BC1): With daemons active, `nested_tune_grid()` returns a result
      `identical()` to the serial (daemons-off) result from the same entry
      seed, using the ranger stochastic workflow, at two daemon counts both
      at or above the implementation's parallel-dispatch threshold; each such
      test also asserts that the parallel branch was selected for the run, so
      the identity is never serial-vs-serial.
- [ ] AC2 (BC2): The non-default-`RNGkind()` identity test (AC3) sets a caller
      generator kind that is neither `"Mersenne-Twister"` nor
      `"L'Ecuyer-CMRG"` (e.g. `"Wichmann-Hill"`), and a comment records why:
      a pin-less implementation reproduces serial results exactly under a
      caller on L'Ecuyer-CMRG because mirai daemons sit on that same kind.
- [ ] AC3 (BC3): The dispatcher classifies each collected element by positive
      validation of the fold-record shape; any element failing validation —
      including a `miraiError` and an `errorValue` from a daemon that died
      mid-task, neither of which inherits `"condition"` — is recorded via
      `failed_fold()` with `.completed` FALSE and a note whose stage names
      the worker/infrastructure, and the run returns rather than aborting. A
      test kills a daemon mid-run and asserts: the affected fold has
      `.completed` FALSE, every other fold's record is `identical()` to its
      serial counterpart, and no fold executed more than once.
- [ ] AC4 (BC4): A `miraiInterrupt` collected from a worker is not recorded as
      a failed fold: the call aborts, and the caller's `.Random.seed` and
      `RNGkind()` triple are restored per the existing exit contract.
- [ ] AC5 (BC5): The dispatcher's collection does not use mirai's `.stop`
      option or any mechanism that discards completed folds on first failure.
- [ ] AC6 (BC6): Serial-vs-parallel comparisons of any fold whose `.notes` is
      non-empty exclude the `trace` column and assert `identical()` on all
      other fold-record fields, including the notes' `location`, `type`, and
      `note` text; the exported documentation states that backtraces inside
      `.notes` reflect where the fold executed and are outside the
      reproducibility identity.
- [ ] AC7 (BC7): The contract-derived reference-loop oracle tests
      (`reference_nested_loop()` and its assertions) remain present and
      passing, unmodified in their derivation-from-documentation structure.
- [ ] AC8 (BC8): The documentation added by T6 states all of: parallelism is
      enabled solely by `mirai::daemons(n)` with no argument on
      `nested_tune_grid()`; inner tuning remains serial; results are
      identical to a serial run regardless of daemon count; daemons are
      separate R processes that do not inherit the calling session's options,
      environment variables set after launch, or `.libPaths()` changes; the
      package must be installed in a library the daemons can load, which
      `devtools::load_all()` alone does not provide; and a run whose daemons
      have all died blocks until interrupted.
- [ ] AC9 (BC9): A pollution-immunity test executes a fold on a daemon on
      which prior tasks have changed the RNG kind triple (including
      `sample.kind = "Rounding"`), consumed draws, run a prior fold, and
      written to the daemon's global environment, and asserts the fold record
      is `identical()` to the same fold on a freshly started daemon.
- [ ] AC10: With `mirai` absent or below the dispatch threshold, the loop runs
      serially and every existing test in `tests/testthat/` passes unchanged.
- [ ] AC11: A wall-clock benchmark comparing serial to parallel on a
      multi-fold design is recorded in this file's Review section with the
      machine, daemon count, and design that produced it. Evidence, not a
      threshold — no test asserts a speedup.
- [ ] AC12: `devtools::check()` clean — no ERRORs, WARNINGs, or new NOTEs —
      with `mirai` installed and again with the mirai-dependent tests skipped.

### Deviations from RR03

All nine are ingested verbatim; two are *satisfied* differently than their wording assumes, both found by execution in T5 (work log has the detail).

| BC | Departure | Why |
|---|---|---|
| BC6 | note text compared whitespace-normalized, not `identical()` | cli wraps to the formatting process's console width, so a daemon wraps at its own; words, location, type identical |
| BC3 | daemon killed at the dispatch layer, not inside a real fold | no injection point in production code, and mocking cannot reach another process; the real collect → classify path still runs |

## Coverage

- AC1 → T3, T5
- AC2 → T5
- AC3 → T4, T5
- AC4 → T4, T5
- AC5 → T3
- AC6 → T5, T6
- AC7 → T5
- AC8 → T6
- AC9 → T5
- AC10 → T2, T5
- AC11 → T7
- AC12 → T8

## Tasks

- [x] T1: `mirai` → Suggests; D-entry amending the dependency chain
      (D-006 → D-007 → D-009 → D-012 → D-013 → D-017) with M07-D1 and M07-D4.
- [x] T2: Daemon-detection helper (M07-D1) that also reports the branch a run
      took, so tests can assert it (BC1); unit tests for absent,
      below-threshold, active.
- [x] T3: Replace the `lapply()` at `R/nested-tune-grid.R:157` with a
      dispatcher mapping `nested_fold_fit()` via `mirai::mirai_map()` + a plain
      blocking collect, never `.stop` (BC5); `lapply()` otherwise. Seeds stay
      drawn at entry by fold position.
- [x] T4: Classify collected elements by fold-record shape (BC3, M07-D2);
      `nanonext::nng_error()` for `errorValue` text, `"worker"` stage label;
      rethrow `miraiInterrupt` (BC4); pre-flight namespace round-trip (rec 8).
- [x] T5: Parallel test file, daemons primed under pkgload (rec 9): BC1, BC2,
      BC3, BC4, BC6, BC9, with BC7's oracles left untouched and green. Prove
      every guard by inversion (M05 lesson).
- [ ] T6: Roxygen `@section Parallel execution:` carrying BC8 in full, plus
      BC6's trace caveat and an amendment to "Differences from calling tune
      directly".
- [ ] T7: Run and record the AC11 benchmark — machine, daemon count, design, both wall-clock figures.
- [ ] T8: `devtools::check()` both ways per AC12; update `NEWS.md`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-07-26: created by /milestone-plan; mirai backend, plotting remainder left as a candidate, and the benchmark-as-evidence bar all settled at the plan gate.
- 2026-07-26: in-progress on `m07-parallel-outer-folds`, cut from `main` at ca0cc66.
- 2026-07-26: implement gate — mirai 2.7.2 installed locally (user approved); daemon tests run on CI but `skip_on_cran()`; T3's ip-touching tripwire escalated to a brief at user request.
- 2026-07-26: probe (mirai 2.7.2, bare RNG, no tune): mirai pre-seeds each daemon with a distinct L'Ecuyer-CMRG stream, so D-011's kind pin is load-bearing rather than theoretical — without it a worker draws from a different generator than the serial run.
- 2026-07-26: probe: with the kind pin applied, draws are identical across 1, 2, and 3 daemons and identical to serial `lapply()`; `mirai_map()` leaves the caller's `.Random.seed` and kind untouched, including under an ambient `RNGkind("L'Ecuyer-CMRG")`.
- 2026-07-26: probe caveat: daemon RNG state persists across `mirai_map()` calls, so an early probe read a later question's answer off the earlier one's residue; every reading above was re-taken against freshly started daemons. Bare `rnorm()` only — `tune_grid()` inside a daemon is not yet probed.
- 2026-07-26: blocked on RB03 (T3's ip-touching tripwire); brief committed on this branch rather than `main`, since the branch already carries M07's tracking state and a `main` commit would split the status mirror.
- 2026-07-26: RR03 ingested, back to in-progress. IP2 confirmed by execution through the real composition; 9 binding criteria ingested verbatim (no deviations), AC block replaced, 5 milestone-local decisions recorded, recs 8 and 9 folded into T4 and T5, recs 10 and 11 rejected as RR03 advised.
- 2026-07-26: RR03 found a defect in the plan's own AC3 — it would have passed against a pin-less implementation, because a caller on L'Ecuyer-CMRG matches the daemons' own kind; BC2 replaces it with a kind that reddens.
- 2026-07-26: amendment compressed Scope, Tasks, and the milestone-local Decisions in one pass each to fit the 149-line cap; body now at 149/149 with no headroom.
- 2026-07-26: T1 done — `mirai (>= 2.4.0)` and `pkgload` into Suggests, D-018 records the backend choice, the >= 2 threshold, and the daemons-must-load-it constraint; suite 943 pass / 0 fail.
- 2026-07-26: T2 done — `R/parallel.R` holds detection (`mirai_workers()`, `use_parallel()`, threshold >= 2) and an out-of-band dispatch record, since putting the branch on the result object would break the very identity BC1 also demands; both guards proved by inversion; suite 957 pass / 0 fail.
- 2026-07-26: T3+T4 landed together — the dispatcher cannot return safely without classification, so splitting the commit would have put a knowingly unsafe collect on the branch; tasks stay separately ticked.
- 2026-07-26: T3 done — `dispatch_folds()` maps per-fold payloads via `mirai_map()` + a plain `collect_mirai()` (never `.stop`, BC5), `lapply()` below threshold; the worker resolves the namespace by name rather than carrying it, since a captured namespace silently degrades to the global environment on a daemon (RR03 Q5).
- 2026-07-26: T4 done — `classify_fold_result()` validates fold-record shape positively; `failed_fold()` gained an optional `message` for the path where no condition exists. Inverting to the natural `inherits(x, "condition")` implementation reddens so many tests the run aborts, and dropping the interrupt branch reddens BC4's test.
- 2026-07-26: deviation from RR03 rec 1 — `nanonext::nng_error()` is reached via `getExportedValue()` guarded by `tryCatch` rather than a hard `::` call, because nanonext is mirai's dependency and not ours; declaring it would need its own dependency gate for a note-text nicety. BC3 is unaffected, requiring only that the stage name the worker.
- 2026-07-26: suite 980 pass / 0 fail; `document()` produces no diff.
- 2026-07-26: T4 was ticked a commit early — the pre-flight round-trip rec 8 asked for was missing. `check_daemons_can_load()` now runs one round-trip before any fold is dispatched and aborts with the fix named; tests cover both the bare-daemon refusal and the primed-daemon pass.
- 2026-07-26: test helper `helper-parallel.R` adds `prime_daemons()`/`start_daemons()` (RR03 rec 9); cleanup is left to each caller's `on.exit` so the helpers need no dependency beyond mirai, and `withr` stays undeclared.
- 2026-07-26: suite 982 pass / 0 fail.
- 2026-07-26: T5 done — `test-parallel-identity.R` covers BC1, BC2, BC4's exit contract, BC6, BC9, and BC3's daemon kill; suite 1024 pass / 0 fail / 0 warn.
- 2026-07-26: T5 found BC6 unsatisfiable as worded — cli hard-wraps a note to the console width of the process that formats it, so a daemon wraps at its own width and serial/parallel note text differs by line breaks alone. Words, location, and type are identical. Comparison normalizes whitespace; recorded as a Deviations row. RR03's probe formatted both sides at one width and so did not see it.
- 2026-07-26: T5 deviation on BC3 — the daemon is killed at the dispatch layer, since production code has no injection point and mocking cannot cross a process boundary; the real `collect_mirai()` → `classify_fold_result()` path still runs against a genuinely dead worker. Recorded as a Deviations row.
- 2026-07-26: two bugs of my own found during T5, both mine not mirai's — a shared append-only ledger raced across processes and produced a phantom double-execution (per-task files fixed it), and an integer metrics column was compared against a double. mirai retries nothing: verified each task ran exactly once.
- 2026-07-26: the 19 `'package:nestedtune' may not be available when loading` warnings are a pkgload artifact — verified absent when the package is installed to a scratch library, where parallel was also `identical()` to serial. Tests muffle that one message by text so real warnings still surface; T8's check confirms the installed path.
- 2026-07-26: fourth compression pass to fit the cap — Scope, Decisions, and two task lines; body back to 149/149. The 12-criteria advisory and zero headroom both stand as reported at ingestion.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

_All five decided 2026-07-26 on RR03's evidence (archived), cross-referenced not restated._

- M07-D1: dispatch threshold mirrors tune's `>= 2` connections, so "parallel" means the same in both packages (GP1; RR03 B1).
- M07-D2: worker failures classified by positive fold-record shape, never condition inheritance; `miraiInterrupt` aborts (RR03 Q4).
- M07-D3: `notes$trace` is outside the IP2 identity claim — a daemon's backtrace can never equal the host's (RR03 Q5).
- M07-D4: parallel use requires `nestedtune` installed where daemons load it; `load_all()` does not reach them (RR03 Q5).
- M07-D5: RR03's rejections stand — no per-task `.timeout`, and D-011 is not reopened.

## Review
<!-- owner: review · exclusive -->
