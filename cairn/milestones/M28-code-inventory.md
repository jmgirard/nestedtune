# M28: What we keep, what is only glue, and what belongs to rsample

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** —

## Goal

There is a concrete, cited list separating the code this package will carry
permanently from the glue that exists only because it sits outside `tune`, and
from the pieces whose natural home is the resampling layer — so that joining the
`tidymodels` organization starts from a written account of what to ask upstream
for and what to keep.

## Scope

Surface tier: **internal** — the deliverable is a `cairn/references/` synthesis
note plus an unposted draft under `benchmarks/`, and no external consumer of the
R package relies on either.

**In:** Classify every top-level function in `R/` into one of five buckets —
`core` (logic this package carries regardless), `glue` (exists only because the
code sits outside tune, removable by a named tune-internal fact),
`resampling-layer` (naturally rsample's, whether or not it is ever proposed),
`furniture` (user-facing surface this package owns), `ambiguous` (with a stated
reason) — each with `file:line`, export status, and approximate line count.
Cite, for each `glue` entry, the tune-internal fact that removes it, and for
each `resampling-layer` entry, what rsample's own surface would have to accept.
Reconcile against `NAMESPACE`. Commit the result as a synthesis note and draft
an unposted upstream-asks list.

**Out:** Opening any issue or pull request against tune or rsample → after the
organization transfer lands, and the user's call, not this milestone's.
Performing any refactor the inventory suggests → its own milestone, planned
from the note. Transfer mechanics — the git remote, `DESCRIPTION`'s `URL` and
`BugReports`, the pkgdown configuration, README badges, a contributing guide and
code of conduct → the ROADMAP candidate row this plan adds, which unblocks when
the transfer completes. Any release or submission work → release timing is
user-declared and nothing here proposes one.

## Acceptance criteria

- [ ] AC1: A committed synthesis note at `cairn/references/code-inventory.md`,
      authored from `templates/synthesis-note.md`, carrying a Provenance block
      whose extraction status names a date. The note states its extraction
      procedure verbatim — `grep -nE '^[A-Za-z._][A-Za-z0-9._]* <- function'
      R/*.R` — and every definition that procedure emits appears in the note
      exactly once, with `file:line`, export status, approximate line count, and
      exactly one bucket drawn from core / glue / resampling-layer / furniture /
      ambiguous.
- [ ] AC2: Every entry the note buckets `glue` names the fact about being inside
      `tune` that would make the code unnecessary, cited to tune's own source
      (file and function name at a stated tune version), to a comment in this
      repo, or to a behaviour the note records having observed.
- [ ] AC3: Every entry the note buckets `resampling-layer` names what
      `rsample`'s own surface would have to accept for the code to live there,
      cited the same three ways AC2 allows.
- [ ] AC4: Every entry the note buckets `ambiguous` states the reason it resists
      a single bucket, rather than being forced into one.
- [ ] AC5: The note reconciles against `NAMESPACE`: every `export()` and
      `S3method()` line in the file is accounted for, and every `export()` line
      naming a symbol the extraction procedure's output does not define is
      listed as a re-export and excluded from the function inventory.
- [ ] AC6: An unposted draft under `benchmarks/` names, for every `glue` and
      `resampling-layer` entry in the note, the upstream ask that would retire
      it, and carries a framing sentence placed ahead of the ask list stating
      that this package continues.

## Coverage

- AC1 → T1, T2, T6
- AC2 → T3, T6
- AC3 → T4, T6
- AC4 → T5, T6
- AC5 → T1, T6
- AC6 → T7

## Tasks

- [ ] T1: Run the stated extraction procedure over `R/*.R` and list `NAMESPACE`'s
      exports and S3 methods; record the counts the note must reconcile against.
- [ ] T2: Classify each definition into core / glue / resampling-layer /
      furniture / ambiguous.
- [ ] T3: For each `glue` entry, find and cite the tune-internal fact that
      removes it — e.g. `checks.R:228-233` (tune raises exactly this, but per
      fold), `nested-tune-grid.R:421-424` (a `tune_results` carries no expanded
      grid), `nested-results.R:117-118` (`new_tbl()` exists only to avoid
      tibble).
- [ ] T4: For each `resampling-layer` entry, name what rsample would have to
      accept — the memory-lean constructor and the payload trio
      (`R/parallel.R:118-179`) are the expected members.
- [ ] T5: Record the `ambiguous` cases with reasons — at minimum
      `[.nested_results` (`R/nested-results.R:69`, furniture by shape, IP4
      invariant by content) and `outer_scheme_label()`
      (`R/nested-results.R:48`, assembly-time work for a print method).
- [ ] T6: Author the synthesis note; date every claim it makes about this repo's
      own current state; add its `INDEX.md` bullet.
- [ ] T7: Draft the upstream-asks list under `benchmarks/`, unposted.
- [ ] T8: Run the profile's `verify` slot.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned three findings here — AC1 and AC3 contradicted outright (every function must carry a bucket, yet ambiguous ones must not be forced into one); "every function defined in `R/*.R`" had no fixed referent (173 `function(` occurrences against 106 top-level definitions) so AC1's reconciliation had no target; and AC4's three re-exported generics define no function, so exactly the symbols needing a pass/fail state had none. All three fixed directly: `ambiguous` became a bucket, the extraction rule was stated, re-exports were excluded.
- 2026-07-31: the audit also found the Scope Out misread D-024 — it barred naming any separate home, where D-024 bars only the split-maintenance shape and explicitly permits proposing pieces to rsample or tune separately. Sent to the gate.
- 2026-07-31: plan gate chose descriptive-plus-separate-home-notes over purely descriptive, because withholding where a leftover plainly belongs is the least useful thing to hand a maintainer and D-024 permits saying it; falsified by the draft reading as a bid to keep this package alive.
- 2026-08-28: re-cut by /milestone-plan after D-025 killed D-024's clause (1). The port has no recipient, so the deliverable is no longer a handover document: the two-bucket loop/glue split becomes five buckets, the maintainer-facing split proposal (old AC5) becomes an upstream-asks draft, and the old Scope Out clauses about retirement and split maintenance are replaced. The extraction machinery and the 106-definition target are unchanged and were re-verified today.
- 2026-08-28: criteria audit ([O], fresh context, reduced mode — internal tier, no tripwire tags) returned four findings, all fixed directly. AC1's "every claim about this repo's own state carries an observation date" quantified over which sentences are state claims, which no procedure partitions — narrowed to the Provenance block's dated extraction status, the general habit moved to T6. AC5 carved out three re-exported generics by name, an exemption registry a fourth re-export would silently defeat — replaced with the rule that generates it. AC6's "so no ask reads as a handover" quantified over readers' construals — replaced with a framing sentence the draft contains. AC7 ("the `verify` slot runs clean") bound an instrument, not the deliverable: the deliverable is markdown, so a green suite is true before the milestone starts — dropped as a criterion, kept as T8.
- 2026-08-28: plan gate chose the upstream-asks framing over a purely descriptive internal-maintenance inventory, because organization membership is what makes the asks worth writing and a description alone discards the part the settlement changed; falsified by tune or rsample declining the asks on grounds the inventory could have anticipated.
- 2026-08-28: AC7's alternative repair — a criterion that the new paths carry `.Rbuildignore` coverage so `R CMD check` sees no new NOTE — was weighed and rejected: `^cairn$` and `^benchmarks$` are both already ignored (verified today), so the criterion could not fail.

## Decisions

## Review
