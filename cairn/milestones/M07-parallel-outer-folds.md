<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M07: Parallel outer folds

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M02   <!-- owner: plan · create/amend-via-gate -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate -->
- **Principles touched:** IP2, GP1, GP3, GP4   <!-- owner: plan · create/amend-via-gate -->
- **Branch/PR:** `m07-parallel-outer-folds`   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal

`nested_tune_grid()` runs its outer folds concurrently on mirai daemons when
the user has started them, producing results identical to a serial run.

## Scope

**In:** Dispatch of the existing per-fold worker over mirai daemons, detected
the way `tune` detects them — `rlang::is_installed("mirai")` plus
`mirai::status()$connections`, no argument to set. `mirai` joins Suggests;
absent or with no daemons started, the loop stays serial and unchanged.
Infrastructural worker failure is recorded as a failed fold under M03's
existing discipline rather than aborting the run. `mirai` is added to Suggests
by a D-entry amending the dependency chain D-006 opened. The reproducibility
contract is D-011's as amended by D-016 and is reused, not redesigned. A
recorded wall-clock benchmark is evidence in this file, never a CI threshold.

**Out:** L'Ecuyer-CMRG stream seeding — rejected by D-011 and not reopened
here; this milestone reuses the position-assigned seeds already drawn.
Parallelism inside `tune` — `control_grid(allow_par = FALSE)` stays forced,
per the DESIGN convention and GP1's documented divergence. A `future`
backend and a user-supplied mapper → both declined at the M07 plan gate as
ecosystem divergence and as a knob GP3 argues against; neither carries a
ROADMAP row. Parallelizing `nested_final_fit()` → nothing to parallelize
over; it is one fit. Plotting selection instability → stays a candidate row.
Reducing what each worker must serialize → candidate row, added by this plan.

## Acceptance criteria

- [ ] AC1: With daemons started, `nested_tune_grid()` returns a result
      `expect_identical()` to the serial result from the same seed, on an
      engine whose randomness flows through R's RNG (`ranger`) — a
      deterministic engine passes this vacuously (M02 lesson).
- [ ] AC2: AC1's identity holds at two different daemon counts, so the result
      does not depend on how many workers ran it (IP2).
- [ ] AC3: AC1's identity holds when the caller has set a non-default
      `RNGkind()` before the call — the defect the kind pin exists to prevent,
      and the one a fresh worker exposes (D-011 Consequences).
- [ ] AC4: With `mirai` absent or its daemon count 0, the loop runs serially
      and every existing test in `tests/testthat/` passes unchanged.
- [ ] AC5: A fold whose worker fails infrastructurally is recorded with
      `.completed` FALSE and a note naming the stage, and the run finishes —
      the run never aborts because a worker died (IP4, M03's discipline).
- [ ] AC6: The caller's `.Random.seed` and `RNGkind()` triple are restored on
      exit from a parallel run exactly as from a serial one, including when
      the call errors (D-011's net-zero clause).
- [ ] AC7: `?nested_tune_grid` documents how to turn parallelism on, that
      inner tuning stays serial and why, and that results are unchanged by
      worker count (GP1: divergence documented, never silent).
- [ ] AC8: A wall-clock benchmark comparing serial to parallel on a
      multi-fold design is recorded in this file's Review section with the
      machine, daemon count, and design that produced it. Evidence, not a
      threshold — no test asserts a speedup.
- [ ] AC9: `devtools::check()` clean — no ERRORs, WARNINGs, or new NOTEs —
      with `mirai` installed and again with the mirai-dependent tests skipped.

## Coverage

- AC1 → T3, T5
- AC2 → T5
- AC3 → T5
- AC4 → T2, T5
- AC5 → T4, T5
- AC6 → T5
- AC7 → T6
- AC8 → T7
- AC9 → T8

## Tasks

- [ ] T1: Add `mirai` to Suggests in `DESCRIPTION`; draft the D-entry amending
      the dependency chain (D-006 → D-007 → D-009 → D-012 → D-013 → D-017) and
      recording the backend choice with the alternatives declined at the gate.
- [ ] T2: Write the daemon-detection helper mirroring tune's
      (`rlang::is_installed("mirai")` + `mirai::status()$connections`), plus
      its unit tests for the absent, installed-but-idle, and active cases.
- [ ] T3: Replace the `lapply()` at `R/nested-tune-grid.R:157` with a
      dispatcher that maps `nested_fold_fit()` over folds via
      `mirai::mirai_map()` + `mirai::collect_mirai()` when daemons are active
      and `lapply()` otherwise. Seeds stay drawn at entry and assigned by fold
      position — nothing new is drawn per worker. (RB tripwire: ip-touching)
- [ ] T4: Handle a worker that fails outside `nested_fold_fit()`'s own
      `tryCatch` — a `miraiError` or a dead daemon — by routing it through
      `failed_fold()` so it lands as a recorded failure, not an abort.
- [ ] T5: Write the parallel test file: serial-vs-parallel identity with
      `ranger` under `skip_if_not_installed()`, at two daemon counts, under a
      caller-set non-default `RNGkind()`, plus RNG restoration and the
      worker-failure path. Prove each guard by inversion (M05 lesson) — a
      guard that passes against the pre-change code is testing nothing.
- [ ] T6: Document the parallel path in `nested_tune_grid()`'s roxygen —
      a new `@section Parallel execution:` and an amendment to the existing
      "Differences from calling tune directly" section.
- [ ] T7: Run and record the benchmark for AC8; capture machine, daemon count,
      design, and both wall-clock figures.
- [ ] T8: Run `devtools::check()` both ways per AC9; update `NEWS.md`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-07-26: created by /milestone-plan; mirai backend, plotting remainder left as a candidate, and the benchmark-as-evidence bar all settled at the plan gate.
- 2026-07-26: in-progress on `m07-parallel-outer-folds`, cut from `main` at ca0cc66.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
