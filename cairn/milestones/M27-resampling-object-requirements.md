# M27: What the outer loop needs from the resampling object, in writing

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4
- **Branch/PR:** m27-resampling-object-requirements

## Goal

The maintainer gets a cited account of what a nested-resampling object must
carry for a driver to run the outer loop, and what today's shape forces the
driver to reconstruct.

## Scope

**In:** The maintainer has opened the resampling object itself to redesign and
proposed keeping one `data` and reindexing the inner splits — the conclusion
`nested_resamples()` already reached from the memory side. Inventory every read
this package's driver makes of the resampling object; what it reconstructs
because the object does not carry it; where the rsample class boundary forces a
workaround. Measure the reindexing benefit on two axes, each with a closed-form
model beside the measurement. Commit a synthesis note; draft the
maintainer-facing writeup.

**Out:** Proposing a concrete class or API for a replacement object → joint work
at the call; this milestone supplies requirements, not a design. Changing
`nested_resamples()` or the driver. Re-cutting
`references/tidymodels-nested-cv-gaps.md`, which snapshots the ecosystem where
this note snapshots our own driver. The backend/transfer question → M26; this
note flags which of its arguments M26's finding could affect rather than waiting
on it.

## Acceptance criteria

- [ ] AC1: A committed synthesis note at
      `cairn/references/outer-loop-object-requirements.md`, authored from
      `templates/synthesis-note.md`, with a Provenance block, its `INDEX.md`
      bullet, and every claim about this repo's own state dated
      `— observed YYYY-MM-DD`; it lists every read the driver makes of the
      resampling object — column, field, attribute, or class — each cited
      `file:line`, and every citation resolves to a line performing the
      described read.
- [ ] AC2: The note separately lists what the driver reconstructs because the
      object does not carry it — at minimum the training data
      (`R/nested-resamples.R:218`), the one-shared-frame invariant
      (`R/parallel.R:129-137`), fold labels (`R/nested-results.R:324`), the
      id-column set defined by subtraction (`R/nested-results.R:10`), the
      re-evaluable inner spec (`R/checks.R:312`), and the fold↔seed binding
      (`R/nested-tune-grid.R:318`) — each naming what the object would have to
      carry for the reconstruction to disappear.
- [ ] AC3: Peak in-process object size for `rsample::nested_cv()` against
      `nested_resamples()` is measured at ≥ 2 (n, v, inner_v) settings not
      covered by M13's 10×10 and 5×2, and serialized per-fold wire bytes are
      measured for the same two constructors under the current dispatch path.
      Each axis carries a closed-form model beside the measurement, as M13 and
      M23 both shipped, so the number has two independent oracle types (GP2).
- [ ] AC4: Every place the package strips, re-adds, or dispatches around an
      rsample class, or writes an `rsplit` field for want of a public accessor,
      is listed with its `file:line` and the rsample behaviour that forces it.
- [ ] AC5: An unposted draft writeup for the maintainer exists under
      `benchmarks/`, marking each claim as measured here or inferred, and naming
      which of its transfer-cost argument M26's finding could change.
- [ ] AC6: The `verify` slot of `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1, T6
- AC2 → T2, T6
- AC3 → T4, T5, T6
- AC4 → T3, T6
- AC5 → T7
- AC6 → T8

## Tasks

- [x] T1: Inventory every read of the resampling object across `R/checks.R`,
      `R/nested-tune-grid.R`, `R/nested-resamples.R`, `R/parallel.R`,
      `R/nested-final-fit.R`, `R/nested-results.R`; verify each citation by
      re-reading the cited line.
- [x] T2: Inventory the reconstructions, each with the carrying field that would
      remove it.
- [x] T3: Inventory the class-boundary workarounds and the rsample behaviour
      behind each.
- [ ] T4: Extend `benchmarks/rsample-283-reprex.R` (or add a sibling) to cover
      the two new size settings and the wire-byte axis, with a closed-form model
      per axis.
- [ ] T5: Run the measurements; record results against the models.
- [ ] T6: Author the synthesis note; add its `INDEX.md` bullet.
- [ ] T7: Draft the maintainer-facing writeup under `benchmarks/`, unposted.
- [ ] T8: Run the profile's `verify` slot.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned three findings here — AC1 named no note path so the references-page rules did not bind; AC3's memory axis was satisfiable with no new measurement, M13 having already covered two settings; AC3's wire-byte axis named no comparison and stated no oracle against GP2. Path and Provenance fixed directly, the comparison named, the oracle required; the measure-vs-reuse choice went to the gate.
- 2026-07-31: plan gate chose fresh measurement at uncovered sizes over reusing M13's numbers, because a criterion satisfiable with no new measurement is what the audit flagged; falsified by the new settings agreeing with M13's model closely enough that the argument never needed them.
- 2026-08-01: implement gate: AC3's new settings are 5×5 and 20×5 on LetterRecognition (one practical scheme, one stressing the v-scaling term); T4 takes the sibling-script option so the committed #283 recipe stays byte-stable.
- 2026-07-31: plan gate chose running in parallel with M26 over depending on it, because the maintainer signalled this thread first and the call is under three weeks out; falsified by M26 finding that shared memory removes the transfer-cost argument this note builds.

- 2026-08-01: T1-T3 done in one authoring pass — the synthesis note's R (19 reads), C (7 reconstructions), W (11 workarounds) tables; every file:line read directly at 9b8dd07 before citing; a grep sweep confirmed no design reads outside the six files, and the "outside attr is test-only" claim was verified by grep.

## Decisions

## Review
