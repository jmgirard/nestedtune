# M27: What the outer loop needs from the resampling object, in writing

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4
- **Branch/PR:** m27-resampling-object-requirements · https://github.com/jmgirard/nestedtune/pull/29

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

- [x] AC1: A committed synthesis note at
      `cairn/references/outer-loop-object-requirements.md`, authored from
      `templates/synthesis-note.md`, with a Provenance block, its `INDEX.md`
      bullet, and every claim about this repo's own state dated
      `— observed YYYY-MM-DD`; it lists every read the driver makes of the
      resampling object — column, field, attribute, or class — each cited
      `file:line`, and every citation resolves to a line performing the
      described read.
- [x] AC2: The note separately lists what the driver reconstructs because the
      object does not carry it — at minimum the training data
      (`R/nested-resamples.R:218`), the one-shared-frame invariant
      (`R/parallel.R:129-137`), fold labels (`R/nested-results.R:324`), the
      id-column set defined by subtraction (`R/nested-results.R:10`), the
      re-evaluable inner spec (`R/checks.R:312`), and the fold↔seed binding
      (`R/nested-tune-grid.R:318`) — each naming what the object would have to
      carry for the reconstruction to disappear.
- [x] AC3: Peak in-process object size for `rsample::nested_cv()` against
      `nested_resamples()` is measured at ≥ 2 (n, v, inner_v) settings not
      covered by M13's 10×10 and 5×2, and serialized per-fold wire bytes are
      measured for the same two constructors under the current dispatch path.
      Each axis carries a closed-form model beside the measurement, as M13 and
      M23 both shipped, so the number has two independent oracle types (GP2).
- [x] AC4: Every place the package strips, re-adds, or dispatches around an
      rsample class, or writes an `rsplit` field for want of a public accessor,
      is listed with its `file:line` and the rsample behaviour that forces it.
- [x] AC5: An unposted draft writeup for the maintainer exists under
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
- [x] T4: Extend `benchmarks/rsample-283-reprex.R` (or add a sibling) to cover
      the two new size settings and the wire-byte axis, with a closed-form model
      per axis.
- [x] T5: Run the measurements; record results against the models.
- [x] T6: Author the synthesis note; add its `INDEX.md` bullet.
- [x] T7: Draft the maintainer-facing writeup under `benchmarks/`, unposted.
- [x] T8: Run the profile's `verify` slot.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned three findings here — AC1 named no note path so the references-page rules did not bind; AC3's memory axis was satisfiable with no new measurement, M13 having already covered two settings; AC3's wire-byte axis named no comparison and stated no oracle against GP2. Path and Provenance fixed directly, the comparison named, the oracle required; the measure-vs-reuse choice went to the gate.
- 2026-07-31: plan gate chose fresh measurement at uncovered sizes over reusing M13's numbers, because a criterion satisfiable with no new measurement is what the audit flagged; falsified by the new settings agreeing with M13's model closely enough that the argument never needed them.
- 2026-08-01: implement gate: AC3's new settings are 5×5 and 20×5 on LetterRecognition (one practical scheme, one stressing the v-scaling term); T4 takes the sibling-script option so the committed #283 recipe stays byte-stable.
- 2026-07-31: plan gate chose running in parallel with M26 over depending on it, because the maintainer signalled this thread first and the call is under three weeks out; falsified by M26 finding that shared memory removes the transfer-cost argument this note builds.

- 2026-08-01: T1-T3 done in one authoring pass — the synthesis note's R (19 reads), C (7 reconstructions), W (11 workarounds) tables; every file:line read directly at 9b8dd07 before citing; a grep sweep confirmed no design reads outside the six files, and the "outside attr is test-only" claim was verified by grep.
- 2026-08-01: T4-T5 — sibling script `benchmarks/outer-loop-object-requirements.R` (sources helper-payload-size.R, reuses the #283 models); memory axis 3.228x at 5x5 and 5.094x at 20x5 (model resid ≤1%), wire axis: a leaned nested_cv fold still carries its own analysis frame (~70% of its payload; copy-count oracle 1 vs 0), which leaning cannot remove; a raw shared-copy count at 20x5 read 4 from a sentinel coincidence, fixed by netting out the fold's own frame.
- 2026-08-01: T6 — note complete with Provenance, Scope, Evidence snapshot, and Measurements; INDEX.md bullet added.
- 2026-08-01: T7 — `benchmarks/resampling-object-writeup.md`, unposted, every claim tagged (measured)/(inferred); the mori caveat names the absolute wire figures and the serialized-shared-frame premise as what M26's finding changes, and argues shared memory strengthens rather than weakens the reindexing case.
- 2026-08-01: T8 — devtools::test() clean: 1628 pass, 0 fail, 0 warn, 0 skip (no package code changed this milestone). Status → review.

## Decisions

## Review

Reviewed 2026-08-01 on branch m27-resampling-object-requirements (PR #29).

- AC1: `cairn/references/outer-loop-object-requirements.md` committed, template-shaped (Provenance with ingested date/milestone/pagination/extraction status, Scope with tracking disclaimer, Evidence snapshot); INDEX.md bullet present (references index<->disk PASS); repo-state claims carry `— observed 2026-08-01`; all 40 file:line citations across R/C/W tables re-resolved by command at review — every cited line performs the described read or write.
- AC2: C table lists 7 reconstructions with the carrying field per row; the six criterion-named sites all present — split_data (C1), is_fold_payload invariant (C2), fold_ids (C3), id-by-subtraction (C4), eval_inside_spec (C5), seed binding (C6).
- AC3: benchmark re-run fresh at review — 5x5 and 20x5 (neither covered by M13), obj_size 3.228x/5.094x vs model 3.247/5.142 (resid ≤1.02%); wire axis both constructors under the leaned dispatch path, payload model resid ≤2.39%, copy-count oracle 0 frames (nested_resamples) vs 1 own frame (nested_cv) — two independent oracle types per axis (closed form + live; closed form + copy count).
- AC4: W table, 11 rows, each with file:line and the forcing rsample behaviour; citations re-resolved in the same command sweep as AC1.
- AC5: `benchmarks/resampling-object-writeup.md` exists, header says "Not posted", every claim tagged (measured)/(inferred), and the mori caveat paragraph names the absolute wire figures and the serialized-shared-frame premise as what M26's finding changes.
- AC6: devtools::test() 1628 pass / 0 fail / 0 warn / 0 skip; devtools::document() no diff; pkgdown::check_pkgdown() clean; cairn_validate all 16 checks PASS (staleness advisory pre-existing, new page not in it); no README.Rmd; NEWS: no entry owed, no user-visible change; devtools::check() recorded below.
