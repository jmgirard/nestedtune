# M29: The assessment says only what the manifest measured

- **Status:** planned
- **Priority:** normal
- **Depends on:** M26
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** —

## Goal

The mori assessment, the maintainer-facing draft and the tracking records carry
only figures M26's manifest measured, checked mechanically rather than by
reading.

## Scope

**In:** The write-up half of M26's split. Consumes M26's machine-readable
manifest: the committed synthesis note, the unposted maintainer draft, a drift
check that fails when a document's figure is not in the manifest, the durable
lessons this work established, the M13-style handoff so the posting pointer
survives archiving, and the M23 candidate row the earlier note wrongly claimed
already existed. Also records what a real adoption would send that M26's model
does not — the `nested_cv()` per-fold frame, the retained by-value branch, and
the host-side `share()` cost.

**Out:** Any measurement — M26 owns the probe and the manifest, and this
milestone may not add a figure the manifest lacks. Adopting `mori`. Posting
anything upstream: the draft ships unposted and the handoff records the target.

## Acceptance criteria

- [ ] AC1: A committed synthesis note at
      `cairn/references/mori-backend-assessment.md`, authored from
      `templates/synthesis-note.md`, recording what `mori` does and does not
      change about how an object reaches a mirai daemon, pinned to `mori` 0.2.2
      and `mirai` 2.7.2, carrying a Provenance block and its `INDEX.md` bullet,
      with every claim about this repo's own state dated `— observed YYYY-MM-DD`.
- [ ] AC2: A drift check fails when any per-route total, ratio or component
      figure in the note, the maintainer draft or the M26 ROADMAP row is absent
      from M26's manifest. It reads the manifest rather than parsing prose for
      what counts as a figure, and skips entries the manifest marks
      install-dependent.
- [ ] AC3: Every explanatory statement about the gap in the note and the draft —
      and in those two documents only, since work-log and Review text is
      append-only history under IP4 — names terms the manifest carries, with no
      term asserted that the manifest does not measure.
- [ ] AC4: The note records what a real mori adoption would send that M26's
      model does not: the per-fold frame `lean_payload()` attaches when a fold's
      frame is not the shared one (`R/parallel.R:150-155`), the by-value branch
      retained for remote pools, and the host-side `share()` cost.
- [ ] AC5: `cairn/LESSONS.md` gains, one line each, the durable facts this work
      established: a top-level `on.exit()` in an `Rscript` never fires (M12
      review D scored this at 75 and never harvested it, so M26 paid to
      rediscover it); mirai serializes the per-task bundle as one stream, so
      any accounting summing parts double-counts shared structure; and a
      srcref-laden closure's serialized size tracks its whole source file, so an
      unrelated edit to that file moves it.
- [ ] AC6: The milestone carries an M13-style HANDOFF block naming the posting
      target for `benchmarks/tune-1188-mori-findings.md` and the condition for
      re-running M26's probe before posting, so the pointer survives archiving.
- [ ] AC7: A ROADMAP candidate row records M23's under-reported wire accounting
      (that it never counted `.f`), stated as either an amendment to the
      existing srcref-closure row or a distinct row, with the choice named.
- [ ] AC8: The `verify` slot of `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T1, T2, T3
- AC4 → T1
- AC5 → T4
- AC6 → T5
- AC7 → T5
- AC8 → T6

## Tasks

- [ ] T1: Rewrite the note against M26's manifest, citing measured values only,
      and add the adoption-gap section AC4 names.
- [ ] T2: Rewrite the maintainer draft against the same manifest; keep it
      unposted and free of em dashes, each claim marked measured or inferred.
- [ ] T3: Write the drift check and run it against all three documents.
- [ ] T4: Harvest the three lessons into `cairn/LESSONS.md`.
- [ ] T5: Add the HANDOFF block and the M23 candidate row.
- [ ] T6: Run the profile's `verify` slot.

## Work log

- 2026-08-01: created by /milestone-plan, as the write-up half of M26's re-cut after three review returns.
- 2026-08-01: criteria audit ([O], fresh context) ran over the combined 11-criterion draft before the split and returned eleven findings. Those bearing here: AC1 had been reduced to existence plus scaffolding and lost its pinned-content clause, restored above; the drift check could not be a prose grep, since the documents legitimately carry numbers the probe never emits (line ranges, R version floors, review scores, M23's committed totals), so it reads a manifest instead; and the "no explanatory sentence without an asserted term" clause collided with IP4 by reaching work-log and Review history, so AC3 is scoped to the note and draft only.
- 2026-08-01: plan gate chose splitting the re-cut over one milestone, because both sizing tripwires fired at 11 criteria and the seam between measuring and writing up is exactly where four returns landed; falsified by the write-up proving unable to proceed without re-opening the measurement.

## Decisions

## Review
