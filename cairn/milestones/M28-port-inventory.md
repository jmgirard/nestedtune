# M28: A port inventory, not a package to translate

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** —

## Goal

There is a concrete, cited list separating the outer-loop logic tune would
actually receive from the glue that exists only because this code lives outside
tune.

## Scope

**In:** Classify every top-level function in `R/` into outer-loop logic, glue
around tune's current surface, or user-facing furniture, with `file:line`,
export status, and line count. Justify each glue entry against the tune-internal
fact that would make it unnecessary. Record cases that do not fall cleanly into
one bucket as ambiguous, with the reason. Where a non-loop piece plainly belongs
to the resampling layer rather than the tuning layer, note that as an
observation — D-024 clause (1) "does not forbid proposing those pieces to
rsample or tune separately". Commit a synthesis note; draft the
maintainer-facing list.

**Out:** Doing the port or opening a PR against tune's `nested` branch → after
the call. Deciding the fate of the user-facing furniture → D-024's clause-1
retirement question, settled with the maintainer. Recommending that nestedtune
*retain* any piece — D-024 rejected "porting the loop while keeping nestedtune
for the pieces tune may not want", so the inventory may name a separate home but
never argues for a split-maintenance shape.

## Acceptance criteria

- [ ] AC1: A committed synthesis note at
      `cairn/references/port-inventory.md`, authored from
      `templates/synthesis-note.md`, with a Provenance block, its `INDEX.md`
      bullet, and every claim about this repo's own state dated
      `— observed YYYY-MM-DD`; every top-level function defined in `R/*.R`
      (a definition matching `^<name> <- function` at column zero, the
      extraction rule stated in the note) appears exactly once with its
      `file:line`, export status, approximate line count, and bucket — one of
      loop / glue / furniture / ambiguous.
- [ ] AC2: Every glue-bucket entry names the specific fact about being inside
      tune that would make it unnecessary, cited to a source comment, tune's own
      source, or measured behaviour.
- [ ] AC3: Cases that do not fall cleanly into one bucket carry the `ambiguous`
      bucket and a stated reason, rather than being forced into another.
- [ ] AC4: The inventory reconciles against `NAMESPACE`: every `export()` and
      `S3method()` is accounted for, with the three re-exported foreign generics
      (`autoplot`, `collect_metrics`, `extract_workflow`, `R/reexports.R`)
      listed as re-exports and excluded from the function inventory.
- [ ] AC5: An unposted draft list for the maintainer exists under `benchmarks/`,
      describing the split, naming a separate home where one is plain, and
      arguing for no split-maintenance outcome.
- [ ] AC6: The `verify` slot of `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T3, T5
- AC3 → T4, T5
- AC4 → T1, T5
- AC5 → T6
- AC6 → T7

## Tasks

- [ ] T1: Mechanically extract top-level function definitions from `R/*.R` and
      the export/method list from `NAMESPACE`; record the counts the inventory
      must reconcile against.
- [ ] T2: Classify each into loop / glue / furniture.
- [ ] T3: For each glue entry, cite the tune-internal fact that removes it —
      e.g. `checks.R:228-233` ("tune raises exactly this, but per fold"),
      `nested-tune-grid.R:421-424` (a `tune_results` carries no expanded grid),
      `nested-results.R:117-118` (`new_tbl()` exists only to avoid tibble).
- [ ] T4: Record the ambiguous cases with reasons — at minimum
      `[.nested_results` (`R/nested-results.R:69`, furniture by shape, IP4
      invariant by content), the payload trio (`R/parallel.R:118-179`, shaped by
      this package but caused by rsample objects), and `outer_scheme_label()`
      (`R/nested-results.R:48`, assembly-time work for a print method).
- [ ] T5: Author the synthesis note; add its `INDEX.md` bullet.
- [ ] T6: Draft the maintainer-facing list under `benchmarks/`, unposted.
- [ ] T7: Run the profile's `verify` slot.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned three findings here — AC1 and AC3 contradicted outright (every function must carry a bucket, yet ambiguous ones must not be forced into one); "every function defined in `R/*.R`" had no fixed referent (173 `function(` occurrences against 106 top-level definitions) so AC1's reconciliation had no target; and AC4's three re-exported generics define no function, so exactly the symbols needing a pass/fail state had none. All three fixed directly: `ambiguous` became a bucket, the extraction rule was stated, re-exports were excluded.
- 2026-07-31: the audit also found the Scope Out misread D-024 — it barred naming any separate home, where D-024 bars only the split-maintenance shape and explicitly permits proposing pieces to rsample or tune separately. Sent to the gate.
- 2026-07-31: plan gate chose descriptive-plus-separate-home-notes over purely descriptive, because withholding where a leftover plainly belongs is the least useful thing to hand a maintainer and D-024 permits saying it; falsified by the draft reading as a bid to keep this package alive.

## Decisions

## Review
