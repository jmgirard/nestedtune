# M29: The assessment says only what the manifest measured

- **Status:** review
- **Priority:** normal
- **Depends on:** M26
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** m29-mori-assessment-writeup · PR #28 https://github.com/jmgirard/nestedtune/pull/28

## Goal

The mori assessment note and the tracking records carry only figures M26's
manifest measured — history marked as history — checked mechanically rather
than by reading.

## Scope

**In:** The write-up half of M26's split, downscoped at the maintainer's
2026-08-01 gate to the internal record only: rewriting the committed synthesis
note against `benchmarks/mori-wire-manifest.json`, a drift check locking the
note's and the ROADMAP candidate row's figures to that manifest, recording the
three adoption deltas M26's model omits, and deleting the audience-less
maintainer draft.

**Out:** Any measurement — M26 owns the probe and the manifest, and this
milestone may not add a figure the manifest lacks. Adopting `mori` (ROADMAP
candidate row). The external tune#1188 maintainer draft and its posting
handoff — dropped at the maintainer's gate, the port context (D-024, M28)
having removed the audience; the draft file itself is deleted here (gate
2026-08-01). The lessons harvest the earlier plan carried — already done at
M26's review (`LESSONS.md`). The M23 wire-accounting candidate row — its
premise dissolved in the installed state (note correction 2026-08-01);
nothing is owed.

## Acceptance criteria

- [x] AC1: `cairn/references/mori-backend-assessment.md` is rewritten against
      `benchmarks/mori-wire-manifest.json`: every wire figure it states as
      current is a manifest value, printed exactly in bytes or rounded so the
      rounded form's implied interval contains the manifest value (the
      manifest's ~20 B band governs re-measurement, never this comparison);
      figures explicitly attributed to a prior milestone's committed record
      (M23's totals) or named as superseded captures may remain, marked as such
      and never supporting a current claim; the 2026-08-01 block banner and
      every inline `(corrected 2026-08-01 …)` parenthetical are collapsed into
      corrected text (current knowledge; git holds the layered original);
      values the manifest does not carry (the 267–268 range, the name-length
      counts) are dropped; the Provenance extraction status records the rewrite
      with its own `— observed` date; and every claim about this repo's own
      state — the premise table's rows included — is dated
      `— observed YYYY-MM-DD`.
- [x] AC2: A drift check in `tests/testthat/` fails when any manifest figure
      the note or the ROADMAP's mori adoption candidate row cites drifts from
      the manifest: each document declares the manifest figure names it cites
      in a list the check reads, the check enumerates figures from the manifest
      (never parses prose for what counts as a figure), compares each cited
      figure at the precision the document prints it, skips figures a document
      does not declare, and skips cleanly when the repo-only files are absent
      from a built package. Evidence shows it run red once against a scratch
      copy of the note with one figure perturbed; the committed manifest is
      never edited.
- [x] AC3: Every explanatory statement about the gap in the note names terms
      the manifest carries (`gap_bytes`, `lean_bundle_bytes`,
      `mori_bundle_bytes`, `worker_closure_bytes`) or an oracle the manifest
      records for one of them, with no quantity asserted that neither a figure
      nor an oracle covers.
- [x] AC4: The note records what a real mori adoption would send that M26's
      model does not: the per-fold frame `lean_payload()` attaches when a
      fold's frame is not the shared one (`R/parallel.R:150-155`), the by-value
      branch retained for remote pools, and the host-side `share()` cost — as
      unmeasured deltas, citing no figure for them.
- [x] AC5: `benchmarks/tune-1188-mori-findings.md` is deleted from the tree
      (git holds it), and `grep -rn 'tune-1188-mori-findings'` over the
      tracked tree returns no hit outside this milestone's own file and
      append-only work-log and Review text.
- [x] AC6: `Rscript -e 'devtools::test()'` is clean, with the AC2 drift check
      running under it.

## Coverage

- AC1 → T1
- AC2 → T3
- AC3 → T1
- AC4 → T1
- AC5 → T2
- AC6 → T4

## Tasks

- [x] T1: Rewrite the note against the manifest: collapse the correction
      layers, mark historical figures as history, add the adoption-delta
      section, date the repo-state claims, update the Provenance block, and
      refresh the `INDEX.md` line if its summary drifts.
- [x] T2: Delete the maintainer draft and sweep tracked references to it
      outside append-only history.
- [x] T3: Write the drift check with the per-document cited-figure
      declarations; run it red against a perturbed scratch copy of the note,
      then green against the tree.
- [x] T4: Run `devtools::test()` clean.

## Work log

- 2026-08-01: created by /milestone-plan, as the write-up half of M26's re-cut after three review returns.
- 2026-08-01: criteria audit ([O], fresh context) ran over the combined 11-criterion draft before the split and returned eleven findings. Those bearing here: AC1 had been reduced to existence plus scaffolding and lost its pinned-content clause, restored above; the drift check could not be a prose grep, since the documents legitimately carry numbers the probe never emits (line ranges, R version floors, review scores, M23's committed totals), so it reads a manifest instead; and the "no explanatory sentence without an asserted term" clause collided with IP4 by reaching work-log and Review history, so AC3 is scoped to the note and draft only.
- 2026-08-01: plan gate chose splitting the re-cut over one milestone, because both sizing tripwires fired at 11 criteria and the seam between measuring and writing up is exactly where four returns landed; falsified by the write-up proving unable to proceed without re-opening the measurement.
- 2026-08-01: maintainer decision at M26's unblock gate: DOWNSCOPE to correcting the internal assessment note against the manifest only — the external tune#1188 maintainer draft is dropped from scope, the package being ported (M28) having removed that audience. To be applied through this milestone's own plan gate before work starts; M26 meanwhile stamped the note and draft with superseded-figures corrections so neither is harvested as written. This may also resolve the inherited `sizing (split tripwires)` advisory (8 criteria) by shedding the draft-owned ones.
- 2026-08-01: downscope applied via /milestone-plan gated amendment: 6 criteria replace 8. Cut with reasons — the draft rewrite and its HANDOFF (audience removed, file deleted per gate); the lessons-harvest AC (all three lessons already landed at M26's review, LESSONS.md); the M23 wire-accounting candidate-row AC (premise dissolved installed-state, note correction 2026-08-01: "none is owed").
- 2026-08-01: criteria audit ([O], fresh context) over the amended six-criterion wording returned 15 findings. Blocking ones fixed as the auditor's own rewordings: precision-at-print replaces the manifest's ~20 B band (which governs re-measurement, not prose-vs-static-JSON); per-document cited-figure lists resolve absent-vs-drifted; the copy-count clause dropped (copy counts live in oracle strings, not figures); AC3 admits oracle-covered terms so the data-dominance conclusion stays sayable; the historical-figures exemption went to the gate.
- 2026-08-01: gate: historical figures kept marked-as-history over strict manifest-only — preserves the reconciliation argument the no-measurement rule could never rebuild; falsified if review finds a history-marked figure supporting a current claim.
- 2026-08-01: gate: draft deleted over kept-stamped — audience gone, git holds it; falsified if the posting question reopens before the port settles.
- 2026-08-01: gate: drift check as a testthat test over a benchmarks/ script — runs unprompted on every suite and in CI, skipping when repo-only files are absent; falsified if the skip logic ever masks a real drift a hand-run script would have caught.
- 2026-08-01: implement started; branch m29-mori-assessment-writeup. Amendment (gated): AC5 exempts this milestone's own file from the no-reference grep — the criterion and T2 must name the file they delete, so the strict bar failed on itself (missed by the criteria audit that proposed the wording).
- 2026-08-01: T1 done — note rewritten against the manifest: all current figures are manifest values (exact-bytes renderings), block banner and seven inline correcteds collapsed, M23 reconciliation and the 3.87x capture moved to a marked [historical] subsection, adoption-delta section added, drift-check declaration comment added (name=rendering pairs, all 9 figures), premise-table repo-state cites dated. INDEX.md line still accurate, left alone. The 267–268 range, name-length counts, and the 160,187 B by-value comparison dropped (non-manifest values).
- 2026-08-01: T2 done — `git rm benchmarks/tune-1188-mori-findings.md`; the no-reference grep already returns no hit outside this file (the M26 archive summary and the tune-969 reply drafts never named it by filename).
- 2026-08-01: T3 done — helper-drift-manifest.R + test-drift-manifest.R: base-regex manifest parse (jsonlite declined, same reasoning test-ci-workflows.R records for yaml), name=rendering declarations in the note (9 figures) and the ROADMAP candidate row (5), half-ULP-at-printed-precision tolerance, declaration line excluded from the presence search (or every rendering finds itself). Both red shapes are permanent tests: a value perturbed in a scratch copy and a rendering vanished from prose while still declared. Skips from a built tarball; asserts checked >= 14 so a skipping harness cannot pass vacuously.
- 2026-08-01: T4 done — devtools::test() clean: 1622 pass, 0 fail, 0 warn, 0 skip. Status → review.

## Decisions

## Review

- AC1 (2026-08-01): drift test green against the note (9 declared figures, exact-byte renderings, all matching the manifest at printed precision); greps: 0 `corrected 2026-08-01` parentheticals, 0 block banners, 0 hits for the dropped 267–268 range / 160,187 B / name-length counts; `[historical]` subsection present and marked; Provenance records the M29 rewrite with its own observed date; 18 `— observed 2026-` datings including the premise-table rows. ✓
- AC2 (2026-08-01): `test-drift-manifest.R` fresh-run green — 7 assertions including both permanent red shapes (value perturbed in a scratch copy → flagged as manifest mismatch; rendering removed from prose while declared → flagged as not printed); check lives in `tests/testthat/`, enumerates from the declaration + manifest, compares at printed precision, asserts checked ≥ 14; skip path exercised for real by `devtools::check()`, whose tarball run lacks `cairn/`/`benchmarks/` and passed. Committed manifest untouched (`git diff` clean on it). ✓
- AC3 (2026-08-01): the note's current-gap statements audited — the gap is explained as `gap_bytes` (838,574 B), data-dominated per the manifest's frame cross-check oracle, with `worker_closure_bytes` (524 B) near-negligible; every quantity in those statements is a manifest figure or oracle. The historical subsection's quantities are marked `[historical]` and support no current claim, per AC1's exemption. ✓
- AC4 (2026-08-01): adoption-delta section present with all three deltas — the mixed-frame per-fold send (`R/parallel.R:150-155`), the retained by-value branch, the host-side `share()` cost — each recorded as unmeasured, no figures cited. ✓
- AC5 (2026-08-01): `git ls-files benchmarks/` shows the draft gone; the reference grep returns 0 hits outside this milestone's own file. ✓
- AC6 (2026-08-01): `devtools::test()` fresh: 1622 pass, 0 fail, 0 warn, 0 skip, drift check among them. ✓
- Consistency gate (2026-08-01): `cairn_validate` exit 0, all 16 checks pass (staleness advisory: the pre-existing shelf-wide 18 pages, unchanged by this milestone; the mori note no longer among the undated). No principle change → `cairn_impact` skipped. Toolchain slot: `document()` no diff; no README.Rmd; `pkgdown::check_pkgdown()` no problems; no NEWS entry — no user-visible package change (docs + a repo-only test); no new top-level files; `devtools::check()` 0 errors / 0 warnings / 0 notes.
- Fan-out (2026-08-01): [O] diff-bug 15 findings (two confirmed by execution); [S] blame-history 0 (verified none of M26's five killed claims resurrected); [S] prior-review 0 (archives read; PR-comment probe returned none — no thread walk). [S] scorer over all 15.
- Actioned (≥80), all fixed on the branch: F1 (82) + F2 (80) substring presence let a drifted duplicate hide behind another occurrence (executed demos in ROADMAP and the note) → declarations now carry per-rendering occurrence counts (`@N`), exact-count enforced, both demos kept as permanent red tests; F3 (90) `~451 B` — a non-manifest figure supporting a current installed-state claim from inside `[historical]`, the gate's own falsifier → figure and arithmetic removed, bullet now states the two totals measure different conventions and compare no further; F4 (88) that bullet's "dissolves" arithmetic contradicted by the note's own numbers (~215 kB/fold residual) → same rewrite, no direction asserted; F14 (90) the ROADMAP declaration comment split the Candidates list mid-render (confirmed via commonmark) → moved below the last row.
- Logged sub-threshold (10): F5 (78) six premise rows undated — fixed in passing (P2/P5/P8/P10 dated; P3/P4 inferential); F6 (76) "each carrying asserted oracles" false for the two derived figures — fixed in passing; F7 (55) P10 called the ~20 B band "the bound a drift check should use" — fixed in passing (band scoped to re-measurement); F8 (30) ±0.5 B pins fragile against a legitimate probe re-run — accepted, AC1's rule; F9 (58) no word boundaries on substring match; F10 (32) positional JSON pairing; F11 (32) stopifnot instead of labeled failure on a malformed declaration; F12 (45) red tests coupled to exact prose renderings — accepted, they fail loudly not silently; F13 (18) aggregate assertion floor — scorer showed 14 is the exact two-document total; F15 (55) shared-reference figures' different fixture undisclosed — pre-existing omission, unchanged.
- Post-fix evidence refresh (2026-08-01): AC1 dating now 22 `— observed` claims including P2/P5/P8/P10 (the earlier evidence line's "including the premise-table rows" overstated coverage until this fix); AC2 check upgraded to exact occurrence counts with 13 assertions green including four red shapes; full suite fresh 1628 pass / 0 fail / 0 warn / 0 skip; `cairn_validate` exit 0, weight caps pass.
