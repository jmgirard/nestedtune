# M28: What we keep, what is only glue, and what belongs to rsample

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** m028-code-inventory · https://github.com/tidymodels/nestedtune/pull/38

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
code of conduct → the ROADMAP candidate row this plan adds, which D-026 records
as already unblocked, the transfer having landed. Any release or submission work → release timing is
user-declared and nothing here proposes one.

## Acceptance criteria

- [x] AC1: A committed synthesis note at `cairn/references/code-inventory.md`,
      authored from `templates/synthesis-note.md`, carrying a Provenance block
      whose extraction status names a date. The note states its extraction
      procedure verbatim — `grep -nE '^[A-Za-z._][A-Za-z0-9._]* <- function'
      R/*.R` — and every definition that procedure emits appears in the note
      exactly once, with `file:line`, export status, approximate line count, and
      exactly one bucket drawn from core / glue / resampling-layer / furniture /
      ambiguous.
- [x] AC2: Every entry the note buckets `glue` names the fact about being inside
      `tune` that would make the code unnecessary, cited to tune's own source
      (file and function name at a stated tune version), to a comment in this
      repo, or to a behaviour the note records having observed.
- [x] AC3: Every entry the note buckets `resampling-layer` names what
      `rsample`'s own surface would have to accept for the code to live there,
      cited the same three ways AC2 allows.
- [x] AC4: Every entry the note buckets `ambiguous` states the reason it resists
      a single bucket, rather than being forced into one.
- [x] AC5: The note reconciles against `NAMESPACE`: every `export()` and
      `S3method()` line in the file is accounted for, and every `export()` line
      naming a symbol the extraction procedure's output does not define is
      listed as a re-export and excluded from the function inventory.
- [x] AC6: An unposted draft under `benchmarks/` accounts for every `glue` and
      `resampling-layer` entry in the note exactly once, each entry either
      placed under the upstream ask that would retire it or recorded as
      retired by no upstream ask together with what would retire it instead.
      The draft carries a framing sentence placed ahead of the ask list
      stating that this package continues.

## Coverage

- AC1 → T1, T2, T6, T10
- AC2 → T3, T6, T9, T10
- AC3 → T4, T6, T10
- AC4 → T5, T6, T10
- AC5 → T1, T6
- AC6 → T7, T11

## Tasks

- [x] T1: Run the stated extraction procedure over `R/*.R` and list `NAMESPACE`'s
      exports and S3 methods; record the counts the note must reconcile against.
- [x] T2: Classify each definition into core / glue / resampling-layer /
      furniture / ambiguous.
- [x] T3: For each `glue` entry, find and cite the tune-internal fact that
      removes it — e.g. `checks.R:228-233` (tune raises exactly this, but per
      fold), `nested-tune-grid.R:421-424` (a `tune_results` carries no expanded
      grid), `nested-results.R:117-118` (`new_tbl()` exists only to avoid
      tibble).
- [x] T4: For each `resampling-layer` entry, name what rsample would have to
      accept — the memory-lean constructor and the payload trio
      (`R/parallel.R:118-179`) are the expected members.
- [x] T5: Record the `ambiguous` cases with reasons — at minimum
      `[.nested_results` (`R/nested-results.R:69`, furniture by shape, IP4
      invariant by content) and `outer_scheme_label()`
      (`R/nested-results.R:48`, assembly-time work for a print method).
- [x] T6: Author the synthesis note; date every claim it makes about this repo's
      own current state; add its `INDEX.md` bullet.
- [x] T7: Draft the upstream-asks list under `benchmarks/`, unposted.
- [x] T8: Run the profile's `verify` slot.
- [x] T9: Re-read every tune symbol the note cites against the pinned clone and
      record its export status and the doc block it is documented under, so each
      `glue` citation rests on a checked fact rather than an assumed one.
- [x] T10: Rework the note on that evidence — re-bucket the entries whose tune
      equivalent is exported, re-cite the ones that stay `glue`, and correct the
      stale and mis-aimed claims the return listed (F4, F7, F8, F10, F12, F14,
      F15).
- [x] T11: Rework the draft to match — the asks that rested on "unexported", the
      overstated retirements (F6, F9, F11), and the ask D-024 clause (2) records
      as live but the draft omits (F13).
- [x] T12: Re-run the profile's `verify` slot and the ledger and draft
      cross-check scripts.
- [x] T13: Sweep tune's and rsample's whole export surface against every
      `glue`, `resampling-layer` and `ambiguous` entry — the instrument neither
      prior pass had — and record the sweep as a dated evidence section in the
      note, so a later pass re-runs a stated procedure instead of re-hunting.
- [x] T14: Rework the note on the sweep's evidence and the return's findings —
      the three newly found exported counterparts (G1/S1/S2) re-cited on the
      corrected fact, and G5, G6, G7, G9, G10.
- [x] T15: Rework the draft to match — F061's placement (G1), T-A2's and T-A1's
      re-framing (S1, S2), the overstated retirements (G3, G4), the kept-function
      count (G2), and the D-025 misstatement (G8).
- [x] T16: Re-run the profile's `verify` slot and the ledger and draft
      cross-check scripts.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned three findings here — AC1 and AC3 contradicted outright (every function must carry a bucket, yet ambiguous ones must not be forced into one); "every function defined in `R/*.R`" had no fixed referent (173 `function(` occurrences against 106 top-level definitions) so AC1's reconciliation had no target; and AC4's three re-exported generics define no function, so exactly the symbols needing a pass/fail state had none. All three fixed directly: `ambiguous` became a bucket, the extraction rule was stated, re-exports were excluded.
- 2026-07-31: the audit also found the Scope Out misread D-024 — it barred naming any separate home, where D-024 bars only the split-maintenance shape and explicitly permits proposing pieces to rsample or tune separately. Sent to the gate.
- 2026-07-31: plan gate chose descriptive-plus-separate-home-notes over purely descriptive, because withholding where a leftover plainly belongs is the least useful thing to hand a maintainer and D-024 permits saying it; falsified by the draft reading as a bid to keep this package alive.
- 2026-08-28: re-cut by /milestone-plan after D-025 killed D-024's clause (1). The port has no recipient, so the deliverable is no longer a handover document: the two-bucket loop/glue split becomes five buckets, the maintainer-facing split proposal (old AC5) becomes an upstream-asks draft, and the old Scope Out clauses about retirement and split maintenance are replaced. The extraction machinery and the 106-definition target are unchanged and were re-verified today.
- 2026-08-28: criteria audit ([O], fresh context, reduced mode — internal tier, no tripwire tags) returned four findings, all fixed directly. AC1's "every claim about this repo's own state carries an observation date" quantified over which sentences are state claims, which no procedure partitions — narrowed to the Provenance block's dated extraction status, the general habit moved to T6. AC5 carved out three re-exported generics by name, an exemption registry a fourth re-export would silently defeat — replaced with the rule that generates it. AC6's "so no ask reads as a handover" quantified over readers' construals — replaced with a framing sentence the draft contains. AC7 ("the `verify` slot runs clean") bound an instrument, not the deliverable: the deliverable is markdown, so a green suite is true before the milestone starts — dropped as a criterion, kept as T8.
- 2026-08-28: plan gate chose the upstream-asks framing over a purely descriptive internal-maintenance inventory, because organization membership is what makes the asks worth writing and a description alone discards the part the settlement changed; falsified by tune or rsample declining the asks on grounds the inventory could have anticipated.
- 2026-08-28: AC7's alternative repair — a criterion that the new paths carry `.Rbuildignore` coverage so `R CMD check` sees no new NOTE — was weighed and rejected: `^cairn$` and `^benchmarks$` are both already ignored (verified today), so the criterion could not fail.

- 2026-08-30: T1 — the extraction procedure emits 106 definitions across 12 files in `R/`, no duplicate names. `NAMESPACE` carries 8 `export()` lines and 10 `S3method()` lines; 5 exports and 9 S3 methods match a definition the procedure emits. The 3 unmatched exports are `autoplot`, `collect_metrics`, `extract_workflow` (re-exports, excluded per AC5). The 1 unmatched S3 method is `[.nested_results`, whose definition line begins with a backtick and so falls outside the procedure's pattern.
- 2026-08-30: implementation gate — inventory laid out as one flat table with permanent row IDs (user delegated the choice); every `glue` entry cited to tune's own source rather than to repo comments where the source covers it (user delegated); upstream asks grouped by theme, user's selection. tune v2.1.0 (`4c74638`) and rsample v1.3.2 (`658545c`) cloned read-only outside the repo for the citations.
- 2026-08-28: the push committing this plan was answered by GitHub's moved-repository redirect, so the organization transfer was already complete; D-026 records the correction and the Scope Out clause about the housekeeping row unblocking later was amended to match. Nothing about this milestone's own scope changed.

- 2026-08-30: T2 — the 106 definitions classify as 32 `core`, 38 `furniture`, 19 `glue`, 12 `resampling-layer`, 5 `ambiguous`. The bucket map is held as a name→bucket list and merged against the extraction output by a script that fails unless the two name sets are equal, so no definition can be dropped or double-bucketed on the way into the note's table.

- 2026-08-30: T3-T6 - `cairn/references/code-inventory.md` committed, authored from `templates/synthesis-note.md`. All 19 `glue` entries cite tune's own source at v2.1.0 (`4c74638`): `check_workflow()` R/checks.R:314, `.has_preprocessor()` R/grid_helpers.R:116, `check_installs()` R/checks.R:234, `.check_grid()` R/checks.R:67 with the expansion at :145 and the result bound at R/tune_grid.R:375, `check_extra_tune_parameters()` R/checks.R:361, `check_metrics()` R/checks.R:397, `new_note()`/`append_log_notes()` R/logging.R:320/:282, `tibble (>= 3.1.0)` in DESCRIPTION:37, and `mirai_installed()`/`get_mirai_workers()`/`choose_framework()` R/parallel.R:51/:87/:117.
- 2026-08-30: T4 - all 12 `resampling-layer` entries cite rsample v1.3.2 (`658545c`): `nested_cv()` R/nested_cv.R:50 and `inside_resample()` :98-101 (the per-fold `as.data.frame(src)` copy), the two `warn(boot_msg)` sites :71/:77 that warn where this package refuses, the unchecked `map()` at :88, the stored `inside` call at :93 with nothing exposed to re-run it, `analysis()`/`assessment()`/`complement()` as the only split accessors with no frame accessor, and `labels.rset()` R/labels.R:14-17, which aborts outright for a `nested_cv`.
- 2026-08-30: T5 - 5 `ambiguous` entries recorded with reasons: F051-F053 (the candidate-set comparison, furniture by position and glue by cause), F059 `outer_scheme_label()`, F106 `fold_task()`, plus the addendum `[.nested_results`. The extraction procedure does not emit `[.nested_results` - its definition line starts with a backtick - so it is carried as an addendum with a bucket and a reason rather than added to the table, keeping the table exactly what the stated procedure emits.
- 2026-08-30: `cairn_validate` clean; the 18 `references staleness` advisories are pre-existing and unchanged in count, so the new page's extraction status parses as a dated verification.

- 2026-08-30: T7 - `benchmarks/upstream-asks.md` drafted, unposted, grouped by theme: four asks to tune (T-A1 pre-fit checks, T-A2 record the expanded grid, T-A3 note and metric constructors, T-A4 the parallel-backend decision) and five to rsample (R-A1 index-remapping nested design, R-A2 validate what `nested_cv()` builds, R-A3 re-run the stored inner spec, R-A4 the frame an rset indexes, R-A5 `labels()` for a nested design). A script checks each of the 31 `glue` and `resampling-layer` entries against the draft text: all 31 appear, each under exactly one ask.
- 2026-08-30: F061 `new_tbl()` is the one `glue` entry no upstream ask retires - it goes when this package adds `tibble` to Imports, a local dependency decision needing its own gate. The draft states that under its own heading rather than padding it into an ask that would not do it, so every `glue` entry is still accounted for. T-A2 and T-A3 would remove most of its call sites; three would remain.
- 2026-08-30: T8 - `devtools::test()` clean: FAIL 0, WARN 0, SKIP 0, PASS 1628. No `R/` file changed on this branch, so `devtools::document()` was not required.
- 2026-08-30: amendment return: AC6 — "names, for every `glue` and `resampling-layer` entry in the note, the upstream ask that would retire it". F061 `new_tbl()` is a `glue` entry no upstream ask retires; the draft records that honestly under its own heading, so the clause as written is unmeetable without inventing an ask. AC1-AC5 verified with fresh evidence and the consistency gate is clean; the amendment is the only work convened.
- 2026-08-30: amendment return: AC6 — "An unposted draft under `benchmarks/` accounts for every `glue` and `resampling-layer` entry in the note exactly once, each entry either placed under the upstream ask that would retire it or recorded as retired by no upstream ask together with what would retire it instead. The draft carries a framing sentence placed ahead of the ask list stating that this package continues." Narrowing repair chosen at the mini gate over a widening that would have bound the local dependency fix and a follow-up row; the criteria set is the same size and no criterion was added. The draft is unchanged — it already accounted for F061 under its own heading.
- 2026-08-30: criteria audit of the amended AC6 ([O], fresh context, reduced mode — internal tier, no tripwire tags) returned no findings: the quantified domain is the note's 19 `glue` and 12 `resampling-layer` ledger rows, which AC1's extraction procedure enumerates; the no-ask clause is a general rule, not a registry naming F061; and both clauses state properties of the draft rather than of a checker.

- 2026-08-30: defect return: AC2 and AC6 fail. The fresh-context [O] reviewer found that nine of the tune symbols the note cites as the fact removing a `glue` entry are **exported** at tune v2.1.0 — `check_workflow` (NAMESPACE:191), `.has_preprocessor` (:157), `.has_spec` (:161), `.check_grid` (:136), `check_metrics` (:186), `check_metrics_arg` (:187), `mirai_installed` (:265), `get_mirai_workers` (:237), `choose_framework` (:193) — re-verified here against the pinned clone at `4c74638`. So for F001, F002, F006, F007, F011, F083, F084 and F085 the note names no fact *about being inside tune*: the code is callable today as `tune::<name>()` and those entries are not `glue` in the note's own sense. AC2 fails inside its own domain. AC6 fails with it: F083-F085 sit under T-A4 and F002 under T-A1, asks that would not retire them, and they are not recorded as retired by no upstream ask. `check_installs`, `check_extra_tune_parameters`, `is_installed` and the four logging helpers are genuinely unexported and unaffected. First defect return on this milestone; the two prior returns were AC6 amendments and stay off this count.

- 2026-08-30: T9 — re-read every tune symbol the note cites against a fresh pinned clone of `tidymodels/tune` at `v2.1.0` (`4c74638`). Nine are exported, confirming the return: `check_workflow` NAMESPACE:191, `.has_preprocessor` :157, `.has_spec` :161, `.check_grid` :136, `check_metrics` :186, `check_metrics_arg` :187, `choose_framework` :193, `get_mirai_workers` :237, `mirai_installed` :265. Seven are genuinely absent from `NAMESPACE` and unaffected: `check_installs`, `is_installed`, `check_extra_tune_parameters`, `new_note`, `append_log_notes`, `remove_log_notes`, `has_log_notes`. The fact the return did not have: all nine exported ones carry `#' @keywords internal` in three developer-facing doc blocks — `empty_ellipses` (`R/checks.R:311`, `:65`; `R/grid_helpers.R:114`), `internal-parallel` (`R/parallel.R:49`, `:85`, `:114`), and `choose_metric` (`R/metric-selection.R:34`, whose text reads "These are developer-facing functions"). `check_metrics()` also opens with `lifecycle::deprecate_warn("2.1.0", …, "check_metrics_arg()")`. So the citable fact is not that tune hides these but that tune exports them with no stability promise.
- 2026-08-30: implementation gate on the return — re-cite rather than re-bucket wholesale, the user's selection. The five entries whose nestedtune version is a like-for-like duplicate of an exported-unpromised tune helper stay `glue` on the corrected fact (F002, F011, F083, F084, F085); the three whose content tune's version does not cover move to `ambiguous` with the residue named (F001, F006, F007). Rejected at the gate: treating any export as disqualifying, which empties T-A4 and puts an eighth of the ledger in the bucket for entries that resist a single home; and a sixth bucket for unpromised-export duplicates, which would widen the criteria set on a returned milestone and so is non-recommended by D-118. Buckets become 32 core, 38 furniture, 16 glue, 12 resampling-layer, 8 ambiguous.

- 2026-08-30: T10 — the note reworked on T9's evidence. F001, F006 and F007 move from `glue` to `ambiguous`, each stating the residue tune's exported counterpart does not cover (F001's already-fitted refusal at `R/checks.R:20-29` and its caller-naming aborts, which tune's `check_workflow()` has no branch for; F006/F007's front-loading once per design against tune's per-fold raise, which M03's record-fold-failures rule makes unavailable as a check). Buckets are now 32 core, 38 furniture, 16 glue, 12 resampling-layer, 8 ambiguous — 106 total, re-verified by the merge script. The 16 that stay `glue` are re-cited on the corrected fact, stated once in a preamble to the section: nine tune symbols are exported but carry `#' @keywords internal` in the `empty_ellipses`, `internal-parallel` and `choose_metric` blocks, so the fact about being inside tune is the absent promise, not absent visibility. Also fixed from the return: F002's reason now cites its own comment at `R/checks.R:73-81` rather than `check_workflow()`'s at `:30-36` (F4); the `function(` count is 153, not 173 (F7); `labels.vfold_cv()` (rsample `R/labels.R:31-36`) already pastes `id` and `id2`, so F067's ask is the nested method alone and not a combining rule (F8); F070–F073's reconstruction is no longer described as closable only by tune, since exported `.check_grid()` would let this package expand the grid itself (F9); the `>= 2` threshold is tune `R/parallel.R:146-147`, not `:117` (F14); Disposition no longer calls the payload trio an `ambiguous` entry (F12); and the duplicated word in the Provenance block is gone (F15). F16 is rejected on its own terms: `[.nested_results` is `R/nested-results.R:69-105`, 37 lines, so the note's `~37` is exact and the reviewer's 36 was the off-by-one.

- 2026-08-30: T11 — `benchmarks/upstream-asks.md` reworked to match. T-A1 becomes "promise the pre-fit checks, and export the one that is missing": `.has_preprocessor()` and `check_metrics_arg()` are exported under `@keywords internal`, so the ask there is a stability commitment, while `check_installs()`/`is_installed()` are genuinely unexported and keep the export ask; it now retires F002, F003, F011 (~31 lines) and states that F001, F006 and F007 are not claimed. T-A4 becomes "promise the parallel-backend decision" — all three tune functions are exported, so nothing needs writing but one line of documentation. T-A2 no longer calls the reconstruction closable only by tune: exported `.check_grid()` would let this package expand the grid itself, at the price of the same unpromised surface, so the ask is stated in preference order (F9). T-A5 is new and carries the one ask D-024 clause (2) records as live and D-025 preserved — keep `check_rset()`'s top-level `nested_cv` refusal (tune `R/checks.R:19-21`, called at `R/tune_grid.R:360` and `R/tune_bayes.R:322`) where it is (F13). R-A2's retirement is narrowed: three of `check_nested()`'s refusals survive the ask, including the `^id` check that exists for this package's own results object (F11). R-A5 drops the combining-rule half, `labels.vfold_cv()` already pasting `id` and `id2` (F8). The framing paragraph no longer claims the same public surface — R-A1 retires the exported `nested_resamples()`, and the kept-function count is 79 of 106, not 76 (F6). The `ambiguous` section moved out from under the rsample heading, since F001/F006/F007 are tune-side. A script checks all 28 `glue` and `resampling-layer` entries against the draft: each appears under exactly one section (T-A1 3, T-A2 4, T-A3 5, T-A4 3, no-ask 1, R-A1 3, R-A2 3, R-A3 1, R-A4 4, R-A5 1), and the framing sentence is at line 13, ahead of the first ask at line 51.

- 2026-08-30: T12 — `cairn_validate.py` exits 0, all checks pass; 18 `references staleness` advisories, unchanged in count and none naming the new page. One new advisory: M28 now carries 12 tasks against the 10-task split tripwire, the four rework tasks the defect return convened. `devtools::test()` is FAIL 0, WARN 0, SKIP 0, PASS 1628. `git diff origin/main...HEAD -- R/ NAMESPACE man/` is empty, so `devtools::document()` is not required and no code path changed; the branch diff is five markdown files. AC2 and AC6 re-ticked.

- 2026-08-30: defect return: AC6 fails. The fresh-context [O] reviewer found that F061 `new_tbl()` is recorded in the draft as retired by no upstream ask, when tune exports `new_bare_tibble()` (`NAMESPACE:267`, `R/utils.R:82-85`, `#' @keywords internal` under `@rdname empty_ellipses` at `:79-81`, re-verified here against `4c74638`) — a direct counterpart sitting in the very doc block T-A1 already asks tune to promise, so T-A1's promise would retire it and the draft's "what would retire it instead" (this package adding `tibble` to Imports) is not the answer. F061 is one of the 28 ledger rows AC6 quantifies over, so AC6 fails inside its own domain. G3 (T-A4 does not retire F083: `is_mirai_installed()` has a second call site at `R/parallel.R:47` inside `pool_is_cancellable()`) and G4 (T-A3 asks only to *document* the metrics zero-row shape, which retires nothing, so F079 stands) are weaker instances of the same overstated-retirement problem. AC1-AC5 verified with fresh evidence and the consistency gate is clean; eight lesser defects (G2, G5-G10) ride the same rework and three (G11-G13) are rejected. Second defect return on this milestone; the two prior returns were AC6 amendments and stay off this count. Thrash trigger (b) fires — AC6 has failed twice by defect, both times on a tune export fact taken from recall rather than from a sweep of tune's `NAMESPACE`.
- 2026-08-30: CI on PR #38 has one red job unrelated to this diff: `macos-latest (release)` fails in `R CMD build`'s install step on a broken RSPM macOS arm64 `gower` binary (`symbol not found in flat namespace '___kmpc_barrier'`), deterministic across a re-run and failing identically on `origin/main`. Not an M28 defect, but a merge blocker needing its own disposition before any milestone merges.

- 2026-08-30: T13-T16 added (minor amendment) after the user chose to spend the sweep rather than a third round of hand-checked citations. No acceptance criterion changes; AC6 as written is meetable and the sweep is how the rework meets it.

- 2026-08-30: T13-T14 — the sweep run and the note reworked on it. `grep -oE '^export\\(([^)]+)\\)' NAMESPACE` emits 152 names for tune at `4c74638` and 62 for rsample at `658545c`; both lists were read (not name-matched) against the 36 `glue`/`resampling-layer`/`ambiguous` entries. Three counterparts the page had missed, all exported and all in the `empty_ellipses` block: `.config_key_from_metrics` (`R/collect.R:618`, `NAMESPACE:138`) does F070-F073's reconstruction; `load_pkgs` (`R/load_ns.R:11`, `NAMESPACE:247`) over `.load_namespace` (`:41`) does F003's engine-package refusal; `new_bare_tibble` (`R/utils.R:82`, `NAMESPACE:267`) does F061's construction. A name match would have missed two of the three. The rsample side came back clean — `make_splits()` and `new_rset()` are declined for a stated reason at `R/nested-resamples.R:160-164` and `populate()` works in the wrong index space — so R-A1 to R-A5 stand. Per the gate, all three stay `glue` re-cited on the exported-but-unpromised fact; buckets unchanged at 32/38/16/12/8, re-verified by the merge script. The sweep is recorded as its own dated section so a later pass re-runs it. Also fixed: F011's doc block (G5), the file count (G6), the Provenance duplication that `48dcdda` only re-wrapped (G7), the short `empty_ellipses` location list (G9), the `labels.rset` off-by-one (G10), and the addendum's stale "other four".

- 2026-08-30: T15-T16 — the draft reworked to match. T-A1 becomes "promise the developer-facing helpers nestedtune duplicates" and absorbs F061 (`new_bare_tibble`) and the F003 correction (`load_pkgs` is exported, so its "not exported at all" paragraph is gone); it now retires 4 functions / ~38 lines. T-A2 is re-framed: `.config_key_from_metrics()` already does the reconstruction, so the ask is recording the grid or letting T-A1's promise cover the recovery, never an export. The "Not retired by any ask to tune" section is deleted, F061 having an ask. T-A3 splits into three parts and no longer claims to retire F079/F076 unconditionally (G4). T-A4 states that promising `choose_framework()` leaves F083's second caller at `R/parallel.R:47` standing and needs `mirai_installed()` too (G3). T-A5 quotes D-025's actual wording — clause (2) superseded in form, its substance live (G8). The kept-function count is restated with its arithmetic: 28 entries reached, 27 retired whole, `check_nested()` surviving in part, so 79 of 106 (G2). Cross-check: all 28 `glue` and `resampling-layer` entries appear under exactly one section, none in the preamble, all nine `Retires:` sums correct, framing sentence at line 13 ahead of the first ask at 57. `devtools::test()` FAIL 0 PASS 1628; `cairn_validate` exits 0; no `R/`, `NAMESPACE` or `man/` file differs from `origin/main`.

- 2026-08-30: blocked → in-progress. The blocker is resolved: M31 shipped both CI fixes and merged to `main` at `06fc2b1` — `macos-latest (release)` now resolves `gower` from source on that leg alone, and `ubuntu-latest (devel)`'s job cap goes 20 → 60 minutes with the hang bound moved onto the `check-r-package` step. `main` merged into this branch; `cairn/ROADMAP.md` was the only file touched on both sides and auto-merged. The ROADMAP candidate row capturing the blocker is removed, M31's archive summary being its record.

- 2026-08-30: post-merge re-verification. `git diff main...HEAD -- R/ NAMESPACE man/ DESCRIPTION` is empty, so `89d8418` — the commit the note's Provenance names — still describes `R/` and no deliverable claim moved under the merge; the branch diff is the same five markdown files. `devtools::test()` is FAIL 0, WARN 0, SKIP 0, PASS 1628; `cairn_validate.py` exits 0 with the same two advisory classes (18 `references staleness`, one sizing tripwire at 16 tasks). `devtools::document()` not required — no roxygen changed on this branch.

- 2026-08-30: CI on PR #38 is green at `8b70ae1` — the state the blocker denied. All seven checks pass: `macos-latest (release)` 6m37s and `ubuntu-latest (devel)` 30m40s, the two jobs that were red on every prior run of this branch, plus `ubuntu-latest (release)` 8m40s, `ubuntu-latest (oldrel-1)` 8m37s, `windows-latest (release)` 10m19s, `test-coverage` 6m14s and pkgdown `build` 2m37s (`deploy` skipped, not the default branch). The devel leg ran cold at 30m40s, inside M31's 60-minute job cap and outside the 20 a bare cap would have allowed. Status in-progress → review.

## Decisions

## Review

**Evidence gathered 2026-08-30 on branch `m028-code-inventory` at `e04a9ee`,
against `origin/main` (branch 0 behind, 4 ahead).** PR
https://github.com/tidymodels/nestedtune/pull/38 (draft).

**AC1 — verified.** `cairn/references/code-inventory.md` is committed and carries
the template's sections (Provenance, Scope, Evidence snapshot, "What the
inventory is", ledger, Disposition, Open questions), with the Provenance
`Extraction:` status on one physical line reading "read directly from `R/*.R` at
`89d8418` … — observed 2026-08-30" (a verification verb plus a date; the
`cairn_validate` `references staleness` advisory does not list the page). The
note states the extraction procedure verbatim as AC1 spells it. Re-running that
procedure now emits 106 definitions; a script parsed the note's ledger and found
106 rows, no duplicate names, the extracted name set equal to the ledger name
set, every `file:line` identical to the extraction output, and every bucket one
of the five. Line counts spot-checked at 8 definitions (`R/checks.R:7`, `:82`,
`:108`; `R/parallel.R:543`, `:823`, `:118`; `R/nested-results.R:8`, `:119`) —
each matched the ledger figure exactly.

**AC2 — verified.** All 19 `glue` row IDs appear in the `glue` section, each
naming a fact about being inside tune. The citations were re-checked against a
fresh shallow clone of `tidymodels/tune` at tag `v2.1.0`, whose HEAD is
`4c74638` — the commit the note states. All 17 cited file:line sites resolve to
the named function or expression: `check_workflow` R/checks.R:314,
`.has_preprocessor` R/grid_helpers.R:116, `check_installs` R/checks.R:234,
`is_installed` :229, `.check_grid` :67, the `dials::grid_space_filling()` call
:145, the `.check_grid()` binding R/tune_grid.R:375,
`check_extra_tune_parameters` R/checks.R:361, `check_metrics` :397,
`check_metrics_arg` R/metric-selection.R:307, `new_note` R/logging.R:320,
`append_log_notes` :282, `remove_log_notes` :414, `has_log_notes` :274,
`mirai_installed` R/parallel.R:51, `get_mirai_workers` :87, `choose_framework`
:117, and `tibble (>= 3.1.0)` at DESCRIPTION:37.

**AC3 — verified.** All 12 `resampling-layer` row IDs appear in that section,
each naming what rsample's surface would have to accept. Re-checked against a
fresh clone of `tidymodels/rsample` at tag `v1.3.2`, HEAD `658545c` — the stated
commit. Every cited site resolves: `nested_cv` R/nested_cv.R:50, the two
`warn(boot_msg)` lines :71 and :77, the unchecked `map(outside$splits,
inside_resample, …)` :88, `attr(out, "inside") <- cl$inside` :93, the
`as.data.frame(src)` copy inside `inside_resample()` :98-101, `analysis`
R/rsplit.R:113, `assessment` :133, `complement` R/complement.R:22, the
`nested_cv` abort in `labels.rset()` R/labels.R:14-17, and `pretty.nested_cv`
R/printing.R:112.

**AC4 — verified.** All 5 `ambiguous` row IDs (F051, F052, F053, F059, F106)
appear in the `ambiguous` section, each stating what pulls it toward two buckets
rather than being forced into one; `[.nested_results` is carried in the addendum
with the same treatment.

**AC5 — verified.** `NAMESPACE` at this commit carries 8 `export()` and 10
`S3method()` lines. The note accounts for all 18: 5 exports name ledger entries
(`nested_resamples` F025, `nested_tune_grid` F068, `nested_final_fit` F021,
`extract_tune_results` F012, `extract_scored_candidates` F015); the 3 the
extraction output does not define (`autoplot`, `collect_metrics`,
`extract_workflow`) are listed as re-exports and excluded, and `R/reexports.R`
confirms each as a bare `pkg::generic` statement; 9 S3 methods name ledger
entries and the tenth, `S3method("[",nested_results)`, is reconciled against the
addendum. The exclusion is stated as a subtraction rule, not a name registry.

**AC6 — fails as written.** The draft exists at `benchmarks/upstream-asks.md`,
unposted, and its framing sentence "nestedtune continues as a package" sits at
line 13, ahead of the first ask heading at line 31. A script confirms all 31
`glue` and `resampling-layer` row IDs appear in the draft, each under exactly one
heading. But AC6 requires the draft to name, *for every* such entry, "the
upstream ask that would retire it", and for F061 `new_tbl()` no upstream ask
exists: the draft says so under its own heading, "Not retired by any ask to
tune", recording that F061 is retired only by this package adding `tibble` to its
own `Imports`. That is the true answer, and the criterion as written cannot be
met without inventing an ask that would not do the job. The criterion is wrong,
not the work — routed to the gated criterion-amendment protocol rather than read
charitably.

**Consistency gate — clean, and recorded although the amendment return stops the
phase before the reviewer fan-out.** `cairn_validate.py` exits 0, all checks
pass; 18 `references staleness` advisories, unchanged in count and none naming
the new page. No `DESIGN.md` principle changed, so `cairn_impact.py` is skipped.
Toolchain slot (`r-package`): `devtools::document()` leaves no diff;
`R CMD check` via `devtools::check()` is 0 errors, 0 warnings, 0 notes in
2m 44s; `pkgdown::check_pkgdown()` finds no problems; no `README.Rmd` exists, so
that check is not applicable; `benchmarks/` already carries an `.Rbuildignore`
entry (`^benchmarks$`); the milestone has no user-visible change, so `NEWS.md`
is owed no entry. No file under `R/`, `man/`, or `NAMESPACE` differs from
`origin/main`.

---

**Re-review after the AC6 amendment — evidence gathered 2026-08-30 on branch
`m028-code-inventory` at `8bc7e6c`, against `origin/main` (0 behind, 6 ahead;
`main` has no unpushed commits).** PR
https://github.com/tidymodels/nestedtune/pull/38 (draft). The amendment commit
touched only `cairn/ROADMAP.md` and this file — `git diff 89d8418..HEAD -- R/
NAMESPACE man/` is empty and neither deliverable changed — so every criterion
below was re-executed against the same artifacts rather than assumed from the
first pass.

**AC1 — verified.** `cairn/references/code-inventory.md` is committed, authored
from `templates/synthesis-note.md` (Provenance, Scope, Evidence snapshot, "What
the inventory is", ledger, Disposition, Open questions all present). The
Provenance `Extraction:` line reads "read directly from `R/*.R` at `89d8418` …
— observed 2026-08-30" — a verification verb and a date; `cairn_validate`'s
`references staleness` advisory does not name the page. The note states the
extraction procedure verbatim as AC1 spells it. Re-running that procedure now
emits 106 definitions across 12 files; a script parsed the ledger and found 106
rows, no duplicate names, ledger name set equal to the extracted name set, every
`file:line` identical to the extraction output, and every bucket one of the five
(32 core, 38 furniture, 19 glue, 12 resampling-layer, 5 ambiguous).

**AC2 — verified.** All 19 `glue` row IDs appear in the `glue` section. Every
upstream citation was re-resolved against a fresh shallow clone of
`tidymodels/tune` at tag `v2.1.0`, whose HEAD is `4c74638` — the commit the note
states. All 17 tune sites resolve to the named function or expression
(`check_workflow` R/checks.R:314, `.has_preprocessor` R/grid_helpers.R:116,
`check_installs` :234, `is_installed` :229, `.check_grid` :67, the abort at :132,
the integer coercion :139, `dials::grid_space_filling()` :145, the
`.check_grid()` binding R/tune_grid.R:375, `check_extra_tune_parameters` :361,
`check_metrics` :397, `check_metrics_arg` R/metric-selection.R:307, `new_note`
R/logging.R:320, `append_log_notes` :282, `has_log_notes` :274,
`remove_log_notes` :414, `mirai_installed` R/parallel.R:51, `get_mirai_workers`
:87, `choose_framework` :117), as does `tibble (>= 3.1.0)` at DESCRIPTION:37.
The four citations to this repo's own comments — which AC2 also allows — resolve
too (`R/checks.R:33`, `:228`, `R/nested-tune-grid.R:418`,
`R/nested-results.R:116`).

**AC3 — verified.** All 12 `resampling-layer` row IDs appear in that section.
Re-resolved against a fresh clone of `tidymodels/rsample` at tag `v1.3.2`, HEAD
`658545c` — the stated commit. Every cited site resolves: `nested_cv`
R/nested_cv.R:50, the two `warn(boot_msg)` lines :71 and :77, the unchecked
`map(outside$splits, inside_resample, …)` :88, `attr(out, "inside") <-
cl$inside` :93, `inside_resample()` :98-101, `analysis` R/rsplit.R:113,
`assessment` :133, `complement` R/complement.R:22, `labels.rset` R/labels.R:14-17
with its `nested_cv` abort, and `pretty.nested_cv` R/printing.R:112. The two
citations to this repo's own comments (`R/nested-resamples.R:216`,
`R/parallel.R:78`) resolve as well.

**AC4 — verified.** All 5 `ambiguous` row IDs (F051, F052, F053, F059, F106)
appear in the `ambiguous` section, each stating what pulls it toward two buckets
rather than being forced into one; `[.nested_results` gets the same treatment in
the addendum.

**AC5 — verified.** `NAMESPACE` at this commit carries 8 `export()` and 10
`S3method()` lines; the note accounts for all 18. The 5 exports it maps to ledger
entries check out by ID and name (F025 `nested_resamples`, F068
`nested_tune_grid`, F021 `nested_final_fit`, F012 `extract_tune_results`, F015
`extract_scored_candidates`), each carrying export status `exported`. The 3 the
extraction output does not define (`autoplot`, `collect_metrics`,
`extract_workflow`) are listed as re-exports and excluded, and `R/reexports.R`
confirms each as a bare `pkg::generic` statement. The 9 mapped S3 methods check
out by ID and name; the tenth, `S3method("[",nested_results)`, is reconciled
against the addendum, whose definition line at `R/nested-results.R:69` does begin
with a backtick and so falls outside the stated pattern. The exclusion is written
as a subtraction rule over the procedure's output, not a name registry.

**AC6 (as amended) — verified.** The draft exists at
`benchmarks/upstream-asks.md`, unposted (its own line 3 says so, and nothing has
been opened upstream). Its framing sentence "nestedtune continues as a package"
is at line 13, ahead of the first ask heading (`# Asks to tune`, line 31). A
script cross-checked all 31 `glue` and `resampling-layer` row IDs against the
draft's level-2 sections: every one appears, and each under exactly one section —
T-A1 6, T-A2 4, T-A3 5, T-A4 3, R-A1 3, R-A2 3, R-A3 1, R-A4 4, R-A5 1, and F061
under "Not retired by any ask to tune", which names what retires it instead
(nestedtune adding `tibble` to its own `Imports`, a local dependency decision
needing its own gate) and records that T-A2 and T-A3 would remove most of its
call sites with three remaining. F002's second mention sits inside T-A1's own
body, so no entry is placed under two asks.

**Consistency gate — clean.** `cairn_validate.py` exits 0; all 16 PASS checks
pass, including `scaffold present`, `coverage complete`, `binding criteria`, and
`references index<->disk`. 18 `references staleness` advisories, unchanged in
count and none naming the new page; `release window` OK. No `DESIGN.md`
principle changed, so `cairn_impact.py` is skipped. Toolchain slot
(`r-package`): `devtools::document()` leaves no diff under `man/`, `NAMESPACE`,
or `R/`; `devtools::check()` is 0 errors, 0 warnings, 0 notes in 2m 15.8s;
`devtools::test()` is FAIL 0, WARN 0, SKIP 0, PASS 1628; `pkgdown::check_pkgdown()`
finds no problems; no `README.Rmd` exists, so that check is not applicable; both
new paths are already `.Rbuildignore`d (`^cairn$`, `^benchmarks$`); the milestone
has no user-visible change, so `NEWS.md` is owed no entry.

**Review routing.** Declared surface tier is internal and
`git diff origin/main...HEAD --name-only` is markdown-only (`benchmarks/upstream-asks.md`,
`cairn/ROADMAP.md`, this file, `cairn/references/INDEX.md`,
`cairn/references/code-inventory.md`) with no script, hook, or other executable
surface — so single-reviewer mode: one fresh-context [O] diff-bug lens, the other
two skipped.

### Independent review — single [O] diff-bug lens, 16 findings

Every reported finding and its disposition, ranked as the reviewer ranked them.
The reviewer's own mechanical pass agreed with the gate's: 106/106 ledger rows
correct for name, `file:line`, line count and export status; the `NAMESPACE`
reconciliation correct; every cited upstream site resolving; every
"Retires: … N functions, ~M lines" sum arithmetically right.

**F1 (AC-failing). `benchmarks/upstream-asks.md:104-124` — T-A4 asks tune to
export what tune already exports.** `choose_framework` (tune NAMESPACE:193),
`mirai_installed` (:265) and `get_mirai_workers` (:237) are exported at v2.1.0.
Re-verified at the gate. F083-F085 could be deleted today with no upstream
change, so their `glue` rationale is wrong. → **returns the milestone.**

**F2 (AC-failing). `benchmarks/upstream-asks.md:44-51` — "all unexported" is
false for three of five.** tune exports `check_workflow` (:191), `.check_grid`
(:136) and `check_metrics` (:186); `.check_grid(grid, workflow, pset)` already
validates the triple and returns the expanded grid. Re-verified. → **returns.**

**F3 (AC-failing). `cairn/references/code-inventory.md:216-220` — "Inside tune
the unexported helper is in hand" is false for F002.** `.has_preprocessor` is
exported at tune NAMESPACE:157, `.has_spec` at :161. Re-verified. → **returns.**

**F4. `benchmarks/upstream-asks.md:52-58` — F002's stated reason is the wrong
function's comment.** The draft draws on `R/checks.R:30-36`, which sits inside
`check_workflow()` and explains the model-spec check; F002 has its own comment at
`R/checks.R:73-81` giving a different, export-proof reason (`add_case_weights()`
also files under `pre`, so the counting form is a different question). → fix in
the return; it is part of the same F002 rework.

**F5. `benchmarks/upstream-asks.md:45` — asks for the export of a function
soft-deprecated at the read version.** `check_metrics()` opens with
`lifecycle::deprecate_warn("2.1.0", …, "check_metrics_arg()")` (tune
R/checks.R:397-398). Re-verified. → fix in the return.

**F6. `benchmarks/upstream-asks.md:20-21` vs `:147-149`, `:300-302` — internal
contradiction about the public surface.** Line 21 claims granting everything
leaves "the same public surface", but R-A1 retires F025 `nested_resamples()`,
which the ledger marks `exported` and the draft itself calls the constructor the
package exists to offer. → fix in the return.

**F7. `cairn/references/code-inventory.md:47` — "173 occurrences of `function(`"
is stale.** The count at `89d8418` is 153; 173 came from the July plan's work
log and is presented under an "observed 2026-08-30" provenance. Re-verified at
the gate (`grep -o 'function(' R/*.R | wc -l` → 153). → fix in the return.

**F8. `benchmarks/upstream-asks.md:273-275`, `code-inventory.md:337-341` —
rsample already has the id-combining rule.** `labels.vfold_cv()` (rsample
R/labels.R:27-41) pastes `id` and `id2` when `repeats > 1`, and a repeated design
dispatches there, not to `labels.rset`. Re-verified. → fix in the return.

**F9. `benchmarks/upstream-asks.md:78-82` — "only tune can close" is
overstated.** With `.check_grid()` exported, nestedtune could expand per fold
itself and pass the frame to `tune_grid()`, retiring F070-F073 without upstream.
→ fix in the return; same premise as F2.

**F10. `cairn/references/code-inventory.md:211-213` — "raising for the same
shapes" is not true of F001.** nestedtune's `check_workflow()` refuses an
already-fitted workflow (`R/checks.R:20-28`); tune's has no such branch and does
not name the caller's call. The "~65 lines" retirement figure is unreachable.
→ fix in the return.

**F11. `benchmarks/upstream-asks.md:178-179, 193-195` — R-A2's retirement claim
is overstated.** `check_nested()` also refuses a non-data-frame, a zero-fold
design, and a design with no `^id` column, the last existing for this package's
own results object; none survives being pushed upstream. → fix in the return.

**F12. `cairn/references/code-inventory.md:455-457` — Disposition names a
non-existent ambiguous entry.** It cites "the resampling-layer half of the
payload discussion"; F090-F092 are bucketed `resampling-layer`, not `ambiguous`.
→ fix in the return.

**F13. `benchmarks/upstream-asks.md` — omits the one ask DECISIONS records as
live.** D-024 clause (2), explicitly preserved by D-025, asks tune to keep the
`nested_cv` refusal top-level with each `inner_resamples` element still accepted
as an ordinary `rset`. Confirmed at the gate against `cairn/DECISIONS.md:675`
and `:722`. The draft's exclusions section does not mention it. → fix in the
return; a draft presenting itself as the ask list must carry it.

**F14. `cairn/references/code-inventory.md:265-274` — the cited threshold line is
off.** `:117` is `choose_framework()`'s opening line; the `>= 2` threshold is at
tune R/parallel.R:146-147. → fix in the return.

**F15. `cairn/references/code-inventory.md:4-5` — "read / read-only" duplicated
word.** Editorial. → fix in the return.

**F16. `cairn/references/code-inventory.md:192` — addendum line count.**
`[.nested_results` spans :69-104, 36 lines, recorded as ~37; within the "~"
convention and the one figure the verifying script does not reach. → reject:
inside the stated approximation convention, and no reader is misled.

**Outcome: defect return.** F1, F2 and F3 each demonstrate AC2 failing inside its
own domain — the note names, for eight `glue` entries, a fact that is not about
being inside tune, because the tune symbol is already exported. AC6 fails with
them, those entries sitting under asks that would not retire them and not being
recorded as retired by no upstream ask. Status back to `in-progress`; AC2 and AC6
unticked. AC1, AC3, AC4 and AC5 keep their verified evidence above and are not
re-opened. F4-F15 ride the same rework rather than being filed separately.

---

**Re-review after the AC2/AC6 defect return — evidence gathered 2026-08-30 on
branch `m028-code-inventory` at `a24d5b7`, against `origin/main` (0 behind, 12
ahead; `main` has no unpushed commits and did not move since the branch was
cut).** PR https://github.com/tidymodels/nestedtune/pull/38 (draft). Every
criterion below was re-executed against the artifacts at this commit; nothing is
carried forward from the two earlier passes.

**AC1 — verified.** `cairn/references/code-inventory.md` is committed and
authored from `templates/synthesis-note.md` (Provenance, Scope, Evidence
snapshot, "What the inventory is", ledger, Disposition, Open questions all
present). The Provenance `Extraction:` line reads "read directly from `R/*.R` at
`89d8418` … — observed 2026-08-30" — a verification verb and a date; the
`cairn_validate` `references staleness` advisory does not name the page. The note
states the extraction procedure verbatim as AC1 spells it. `git diff
89d8418..HEAD -- R/ NAMESPACE` is empty, so the commit the note names still
describes the tree. Re-running the procedure emits 106 definitions; a script
parsed the ledger and found 106 rows, no duplicate IDs or names, ledger name set
equal to the extracted name set, every `file:line` identical to the extraction
output, and every bucket one of the five (32 core, 38 furniture, 16 glue, 12
resampling-layer, 8 ambiguous). Line counts were checked mechanically, not
sampled: a script walked each of the 106 definitions from its stated line to the
next closing brace at column one and compared the span to the ledger figure —
**106 of 106 matched exactly**, including the addendum's `[.nested_results`
at 37.

**AC2 — verified.** All 16 `glue` row IDs appear in the `glue` section. The
section's premise — the one the defect return sent back — is now stated in a
preamble and is correct as re-checked against a fresh shallow clone of
`tidymodels/tune` at tag `v2.1.0`, HEAD `4c74638`, the commit the note names:
nine cited tune symbols are exported (`check_workflow` `NAMESPACE:191`,
`.has_preprocessor` `:157`, `.has_spec` `:161`, `.check_grid` `:136`,
`check_metrics` `:186`, `check_metrics_arg` `:187`, `choose_framework` `:193`,
`get_mirai_workers` `:237`, `mirai_installed` `:265` — all nine confirmed present
in `NAMESPACE`), and each is documented under one of three `@keywords internal`
doc blocks (`empty_ellipses`, `internal-parallel`, `choose_metric`), confirmed by
walking each symbol's own roxygen block. The fact each `glue` entry now names is
the absent stability promise rather than absent visibility, which is a fact about
being inside tune inside AC2's domain. The seven symbols the note treats as
genuinely unexported are genuinely absent from `NAMESPACE`: `check_installs`,
`is_installed`, `check_extra_tune_parameters`, `new_note`, `append_log_notes`,
`remove_log_notes`, `has_log_notes`. All 38 cited upstream sites resolve to the
named function or expression, including `check_metrics`'s
`lifecycle::deprecate_warn("2.1.0", …)` at `R/checks.R:398`, the `>= 2` threshold
at `R/parallel.R:146`, and `tibble (>= 3.1.0)` at `DESCRIPTION:37`. The four
citations to this repo's own comments — which AC2 also allows — resolve as well
(`R/checks.R:73-81`, `R/nested-tune-grid.R:418-427`, `R/nested-results.R:116-118`,
`R/parallel.R:4-7`).

**AC3 — verified.** All 12 `resampling-layer` row IDs appear in that section,
each naming what rsample's surface would have to accept. Re-resolved against a
fresh clone of `tidymodels/rsample` at tag `v1.3.2`, HEAD `658545c` — the stated
commit. Every cited site resolves: `nested_cv` `R/nested_cv.R:50`, the two
`warn(boot_msg)` lines `:71` and `:77`, the unchecked `map(outside$splits,
inside_resample, …)` `:88`, `attr(out, "inside") <- cl$inside` `:93`, the
`as.data.frame(src)` copy in `inside_resample()` `:98-101`, `analysis`
`R/rsplit.R:113`, `assessment` `:133`, `complement` `R/complement.R:22`, both
`nested_cv` aborts in `R/labels.R:14-17` and `:28-30`, and the repeated-design
paste at `R/labels.R:31-36` — the fact the return's F8 asked for. The two
citations to this repo's own comments (`R/nested-resamples.R:216-217`,
`R/parallel.R:78-84`) resolve too.

**AC4 — verified.** All 8 `ambiguous` row IDs (F001, F006, F007, F051, F052,
F053, F059, F106) appear in the `ambiguous` section, each stating what pulls it
toward two buckets rather than being forced into one; `[.nested_results` gets the
same treatment in the addendum. The three the defect return moved here (F001,
F006, F007) each name the residue tune's exported counterpart does not cover —
the already-fitted refusal at `R/checks.R:20-29` (confirmed absent from tune's
own `check_workflow()` at `R/checks.R:314`) and the once-per-design timing the
comment at `R/checks.R:228-233` records.

**AC5 — verified.** `NAMESPACE` at this commit carries 8 `export()` and 10
`S3method()` lines; the note accounts for all 18. The 5 exports mapped to ledger
entries check out by ID and name (F025 `nested_resamples`, F068
`nested_tune_grid`, F021 `nested_final_fit`, F012 `extract_tune_results`, F015
`extract_scored_candidates`), each carrying export status `exported`, and those
are the only 5 rows in the ledger with that status. The 3 the extraction output
does not define (`autoplot`, `collect_metrics`, `extract_workflow`) are listed as
re-exports and excluded; `R/reexports.R` holds exactly three bare `pkg::generic`
statements. The 9 mapped S3 methods check out by ID and name; the tenth,
`S3method("[",nested_results)`, is reconciled against the addendum. The exclusion
is written as a subtraction rule over the procedure's output, not a name
registry.

**AC6 — verified.** The draft exists at `benchmarks/upstream-asks.md`, unposted
(line 3 says so, and nothing has been opened upstream). Its framing sentence
"nestedtune continues as a package" is at line 13, ahead of the first ask heading
(`## T-A1 …`, line 51). A script cross-checked all 28 `glue` and
`resampling-layer` row IDs against the draft's level-2 sections: every one appears
under **exactly one** section — T-A1 3, T-A2 4, T-A3 5, T-A4 3, R-A1 3, R-A2 3,
R-A3 1, R-A4 4, R-A5 1, and F061 under "Not retired by any ask to tune", which
names what retires it instead (nestedtune adding `tibble` to its own `Imports`, a
local dependency decision needing its own gate) and records that T-A2 and T-A3
would remove most of its call sites with three remaining. No target ID appears in
the preamble or in two sections. Every "Retires: … N functions, ~M lines" figure
was recomputed from the ledger's own line counts: **all 9 correct**, both the
function count and the line total. The three asks the defect return said would
not retire what they claimed are fixed — T-A4 now asks for a promise rather than
an export and says all three tune functions are already exported; T-A1 splits
"exported but not promised" from "not exported at all" and explicitly does not
claim F001/F006/F007; and T-A5 carries the D-024 clause (2) ask, confirmed live
at `cairn/DECISIONS.md:675` and preserved by D-025 at `:722`, with its four
`check_rset` citations resolving in the tune clone.

**Consistency gate — clean.** `cairn_validate.py` exits 0; all 16 PASS checks
pass, including `scaffold present`, `coverage complete`, `binding criteria` and
`references index<->disk`. Advisories: 18 `references staleness`, unchanged in
count and none naming the new page, plus one `sizing` tripwire (M28 carries 12
tasks against the 10-task threshold — the four rework tasks the first defect
return convened). No `DESIGN.md` principle changed, so `cairn_impact.py` is
skipped. Toolchain slot (`r-package`): `devtools::document()` leaves no diff
under `R/`, `man/` or `NAMESPACE`; `devtools::check()` is 0 errors, 0 warnings,
0 notes in 2m 39.1s; `devtools::test()` is FAIL 0, WARN 0, SKIP 0, PASS 1628;
`pkgdown::check_pkgdown()` finds no problems; no `README.Rmd` exists; both new
paths are already `.Rbuildignore`d (`^cairn$` line 1, `^benchmarks$` line 11);
the milestone has no user-visible change, so `NEWS.md` is owed no entry.

**CI — one red job, pre-existing and not this diff's.** On PR #38,
`macos-latest (release)` fails in ~1m20s during `R CMD build`'s install step:
`unable to load shared object '…/gower/libs/gower.so': symbol not found in flat
namespace '___kmpc_barrier'` — the RSPM macOS arm64 binary of `gower`, a
transitive dependency, built against an OpenMP runtime the runner image does not
carry. Re-run once; it failed identically, so it is deterministic rather than
transient. The same job fails the same way on `origin/main` (the M30 merge run),
so it predates this branch, and this branch changes five markdown files and no R
code. windows-latest, ubuntu release, ubuntu oldrel-1, test-coverage and pkgdown
all pass. It is a merge blocker under the never-merge-red rule and needs its own
disposition, but it is not an M28 defect.

**Review routing.** Declared surface tier is internal and
`git diff origin/main...HEAD --name-only` is markdown-only
(`benchmarks/upstream-asks.md`, `cairn/ROADMAP.md`, this file,
`cairn/references/INDEX.md`, `cairn/references/code-inventory.md`) with no
script, hook or other executable surface — so single-reviewer mode: one
fresh-context [O] diff-bug lens, the other two skipped.

### Independent review — single [O] diff-bug lens, 13 findings

Every reported finding and its disposition, ranked as the reviewer ranked them.
The reviewer's own mechanical pass agreed with the gate's on every count: 106/106
ledger rows correct for name, `file:line`, line count and export status; all nine
`Retires:` sums arithmetically right; all 28 draft placements correct; the
`NAMESPACE` reconciliation complete. It also swept for top-level definitions the
extraction pattern could miss (`=` assignment, split-line assignment, `assign()`,
backtick names) and found `` `[.nested_results` `` to be the only one, which
independently confirms the addendum's claim.

**G1 (AC-failing). `benchmarks/upstream-asks.md:201-214` and
`cairn/references/code-inventory.md:285-290` — F061 `new_tbl()` is recorded as
retired by no upstream ask, but tune exports a direct counterpart the note never
looked for.** `new_bare_tibble()` is exported at tune `NAMESPACE:267` and defined
at `R/utils.R:82-85` as `vctrs::new_data_frame()` followed by
`tibble::new_tibble()`, carrying `#' @export`, `#' @keywords internal` and
`#' @rdname empty_ellipses` at `R/utils.R:79-81` — verified here against the
pinned clone at `4c74638`. It is callable today as `tune::new_bare_tibble(cols)`,
does what `new_tbl()` does, needs no `tibble` in this package's Imports, and sits
in the *same doc block* T-A1 already asks tune to attach a stability promise to.
T9 re-read every tune symbol the note *cites*; `new_bare_tibble` was never cited,
so it escaped the sweep. AC6's disjunct "recorded as retired by no upstream ask
together with what would retire it instead" is therefore false of F061 inside
AC6's own domain: T-A1's promise would retire it, and the note names a local
dependency decision instead. → **returns the milestone.**

**G2. `benchmarks/upstream-asks.md:20` contradicts `:253-256`.** The framing says
granting every ask "would leave nestedtune with 79 of its 106 top-level
functions" — 106 minus 27, counting F004 `check_nested()` as retired whole —
while R-A2's own header and body say three of F004's refusals survive and
"roughly 30 [lines] stay behind", so `check_nested()` remains a function and the
figure is 80. Confirmed by reading both passages. Same overstated-retirement
class as the last return's F6, in the paragraph F6 fixed. → fix in the return.

**G3. `benchmarks/upstream-asks.md:177-180` — T-A4's "one line of documentation
retires three of our functions" is not true of F083.** `is_mirai_installed()` has
a second call site at `R/parallel.R:47`, inside `pool_is_cancellable()` (F086,
bucketed `core`), asking "is mirai installed at all" — a question
`choose_framework()`'s return value cannot answer. Confirmed by reading
`R/parallel.R:46-51`. Promising `choose_framework()` alone leaves F083 standing.
→ fix in the return; part of the same AC6 honesty rework.

**G4. `benchmarks/upstream-asks.md:134-150` — T-A3's ask does not retire the five
functions its header claims.** The heading says "Export the note and metric
tibble constructors", but the body asks only to export the note constructor and
the append helper and to *document* the zero-row shape of a metrics tibble.
Documenting a shape retires nothing, so F079 `empty_metrics()` would still have
to be written; and F076 `tune_notes()` re-tags `tune::collect_notes()` rows with
a stage string, which `append_log_notes()` does not cover. Confirmed by reading
both. → fix in the return; same rework.

**G5. `cairn/references/code-inventory.md:252` — wrong doc block for
`check_metrics`.** The note says of `check_metrics()` and `check_metrics_arg()`
"Both are exported under `@keywords internal` in the `choose_metric` block". Only
`check_metrics_arg` is `@rdname choose_metric` (tune `R/metric-selection.R:305`);
`check_metrics` is `@rdname empty_ellipses` (`R/checks.R:392`), verified here by
walking each symbol's own roxygen block. AC2 does **not** fail on it — F011's
citations (`R/checks.R:397`, `R/metric-selection.R:307`) resolve and the
load-bearing fact (exported, `@keywords internal`, unpromised) is intact — but
the sentence is wrong. → fix in the return.

**G6. `cairn/references/code-inventory.md:23` — "106 definitions across 12 files"
is false.** The extraction output spans 10 files; `R/` holds 12 `.R` files, of
which `R/nestedtune-package.R` and `R/reexports.R` define nothing the procedure
emits. Confirmed independently at the gate
(`grep -lE '^[A-Za-z._][A-Za-z0-9._]* <- function' R/*.R | wc -l` → 10). The same
wording is in the T1 work-log line and both prior Review sections. It is a
summary statement about the note's own evidence, which AC1 puts in scope, though
it does not falsify any of AC1's enumerated requirements. → fix in the return.

**G7. `cairn/references/code-inventory.md:4-5` — the last return's F15 was not
actually fixed.** The Provenance block still reads "two upstream source trees /
read read-only outside this repo"; commit `48dcdda` moved the line break so the
duplication now sits on one line. The T10 work-log line claims "the duplicated
word in the Provenance block is gone (F15)", which is untrue of the commit
claiming it. Editorial in the artifact, but a false work-log claim. → fix in the
return, and correct the work-log claim rather than repeating it.

**G8. `benchmarks/upstream-asks.md:185-186` misstates D-025.** The draft says
T-A5 is "D-024 clause (2), explicitly preserved by D-025". `cairn/DECISIONS.md:741`
says the opposite in form: "Clause (2) is superseded rather than confirmed: it
framed the alternative to retirement as staying an outside companion, and
organization membership is a third shape it did not anticipate", going on to say
"What clause (2) asked of tune still holds". The substance of the ask is live;
the clause is not "preserved". The AC evidence written earlier in this Review
section repeated the same error and is corrected here. → fix in the return.

**G9. `cairn/references/code-inventory.md:214-217` — the `empty_ellipses`
location list is short by two.** Three sites are given (`R/checks.R:311`, `:65`,
`R/grid_helpers.R:114`) for a claim quantified over nine symbols; `.has_spec` is
documented at tune `R/grid_helpers.R:151-153` and `check_metrics` at
`R/checks.R:390-392`, neither located in the note. The universal claim is true —
all nine were verified here — so this is incompleteness, not error. → fix in the
return, alongside G5 which is the same passage.

**G10. `benchmarks/upstream-asks.md:348` and `cairn/references/code-inventory.md:372`
— off-by-one in the shared-refusal citation.** rsample `R/labels.R:14` is the
`labels.rset` signature; the three refusal lines are `:15-17`. The `:28-30` half
is right. Editorial. → fix in the return.

**G11. `benchmarks/upstream-asks.md:253-254` — R-A2's header noun counts a
partially-retired function whole.** "Retires: … 3 functions, ~104 lines" sums
F004+F005+F008 in full and subtracts in prose on the same line ("of which roughly
30 stay behind"). The arithmetic is right and the qualifier is adjacent. →
**reject**: the same line states the subtraction, so no reader is misled, and the
figure is the ledger sum the cross-check script verifies. G2 is the real defect
in this area and is actioned.

**G12. `cairn/references/code-inventory.md:296-297` — the threshold cite includes
one unrelated line.** The note cites `:146-147` for the `>= 2` threshold; `:146`
is `neither <- future_workers < 2 & mirai_workers < 2` and `:147` is the `both <-`
line. → **reject**: `:147` is the second half of the same two-line threshold
expression, and citing the pair is not an error.

**G13. `cairn/ROADMAP.md:10` — the hygiene line says "all 16 checks green;
advisory — 18 references…" while a second advisory (the 12-task sizing tripwire)
now also fires.** → **reject**: out of scope — the hygiene line is written by the
post-merge pass of the *previous* milestone and is not this diff's to maintain;
the next hygiene pass overwrites it.

**Outcome: defect return.** G1 demonstrates AC6 failing inside its own domain —
F061 is one of the 28 ledger rows AC6 quantifies over, and the disjunct the draft
takes for it ("retired by no upstream ask") is false, because tune's exported
`new_bare_tibble()` sits in the very doc block T-A1 asks tune to promise. G3 and
G4 are weaker instances of the same thing: entries placed under asks that do not
retire them whole. Status back to `in-progress`; **AC6 unticked**. AC1, AC2, AC3,
AC4 and AC5 keep the fresh evidence recorded above and are not re-opened — G5,
G6, G7, G9 and G10 are defects inside them that none of them falsifies, and they
ride the same rework. G11, G12 and G13 are rejected with reasons above.

**Thrash rule.** This is the **second defect return** on M28; the two AC6
amendment returns run on their own track and stay off this count, so trigger (a)
(the third return) has not fired. Trigger (b) **has**: AC6 has now failed twice by
defect, each by a new mechanism of the same shape — a fact about tune's export
surface taken from author recall rather than from a procedure over that surface.
The first return found nine cited symbols wrongly assumed unexported; this one
finds a tenth symbol that was never cited because nobody looked for it. Re-citing
entry by entry buys the next uncited symbol, not a fix. The remedy (b) prescribes
is to reconsider the alternative the plan gate recorded against, which the work
log holds in two places: the 2026-08-28 plan gate chose the upstream-asks framing
over a purely descriptive internal-maintenance inventory, and the 2026-08-30
implementation gate rejected both "treating any export as disqualifying" and a
sixth bucket for unpromised-export duplicates. The rework should decide, at its
gate, whether the durable fix is a mechanical sweep of tune's whole `NAMESPACE`
against every nestedtune helper — which is what neither prior pass had — rather
than a third round of hand-checked citations.

---

**Re-review after the T13-T16 sweep rework — evidence gathered 2026-08-30 on
branch `m028-code-inventory` at `dcdd9d5`, against `origin/main` (0 behind, 17
ahead; `main` has no unpushed commits and did not move since the branch was
cut).** PR https://github.com/tidymodels/nestedtune/pull/38 (draft). Every
criterion was re-executed against the artifacts at this commit; nothing is
carried forward from the three earlier passes. The pinned upstream trees were
re-cloned fresh: `tidymodels/tune` at tag `v2.1.0` (HEAD `4c74638`) and
`tidymodels/rsample` at tag `v1.3.2` (HEAD `658545c`), the commits the note
names.

**AC1 — verified.** `cairn/references/code-inventory.md` is committed and
authored from `templates/synthesis-note.md` (Provenance, Scope, Evidence
snapshot, "What the inventory is", ledger, Disposition, Open questions all
present). The Provenance `Extraction:` line reads "read directly from `R/*.R` at
`89d8418` … — observed 2026-08-30" — a verification verb and a date; the
`cairn_validate` `references staleness` advisory does not name the page. The note
states the extraction procedure verbatim as AC1 spells it. `git diff
origin/main...HEAD -- R/ NAMESPACE man/ DESCRIPTION` is empty, so the commit the
note names still describes the tree. Re-running the procedure emits 106
definitions across 10 of the 12 files in `R/`; a script parsed the ledger and
found 106 rows, no duplicate IDs or names, ledger name set equal to the extracted
name set, every `file:line` identical to the extraction output, and every bucket
one of the five (32 core, 38 furniture, 16 glue, 12 resampling-layer, 8
ambiguous). Line counts were checked mechanically rather than sampled: a script
walked each of the 106 definitions from its stated line to the next closing brace
at column one — **106 of 106 matched the ledger figure exactly**.

**AC2 — verified.** All 16 `glue` row IDs appear in the `glue` section, each
naming a fact about being inside tune. The section's premise is stated once in a
preamble and every claim in it re-checked against the fresh clone: all 12 named
tune symbols are exported at the `NAMESPACE` line the note gives — `check_workflow`
`:191`, `.has_preprocessor` `:157`, `.has_spec` `:161`, `.check_grid` `:136`,
`check_metrics` `:186`, `check_metrics_arg` `:187`, `choose_framework` `:193`,
`get_mirai_workers` `:237`, `mirai_installed` `:265`, `.config_key_from_metrics`
`:138`, `load_pkgs` `:247`, `new_bare_tibble` `:267` — **12 of 12 line numbers
exact**. Each carries `#' @keywords internal` at the line cited, and the three
doc-block groupings (`empty_ellipses`, `internal-parallel`, `choose_metric`, plus
`load_pkgs` on its own block) were confirmed by reading each symbol's `@rdname`.
The seven symbols the note treats as genuinely unexported are absent from
`NAMESPACE`: `check_installs`, `is_installed`, `check_extra_tune_parameters`,
`new_note`, `append_log_notes`, `remove_log_notes`, `has_log_notes`. Every cited
tune site resolves to the named function or expression, including
`check_metrics`'s `lifecycle::deprecate_warn("2.1.0", …)` at `R/checks.R:398`,
the `>= 2` threshold at `R/parallel.R:146-147`, and `tibble (>= 3.1.0)` at
`DESCRIPTION:37`. The citations to this repo's own comments — which AC2 also
allows — resolve too (`R/checks.R:73`, `R/nested-tune-grid.R:418`,
`R/nested-results.R:116`, `R/parallel.R:4-7`). The fact each entry names is the
absent stability promise rather than absent visibility, which is a fact about
being inside tune inside AC2's domain.

**AC3 — verified.** All 12 `resampling-layer` row IDs appear in that section,
each naming what rsample's surface would have to accept. Every cited rsample site
resolves against the fresh clone: `nested_cv` `R/nested_cv.R:50`, the two
`warn(boot_msg)` lines `:71` and `:77`, the unchecked `map(outside$splits,
inside_resample, …)` `:88`, `attr(out, "inside") <- cl$inside` `:93`, the
`as.data.frame(src)` copy in `inside_resample()` `:98-101`, `analysis`
`R/rsplit.R:113`, `assessment` `:133`, `complement` `R/complement.R:22`, both
`nested_cv` aborts (`R/labels.R:15-17` and `:28-30`) and the repeated-design paste
at `:31-36`, `pretty.nested_cv` `R/printing.R:112`, and the three constructors the
sweep declined — `make_splits()` `R/misc.R:18`, `new_rset()` `R/rset.R:14`,
`populate()` `R/complement.R:126`. The two citations to this repo's own comments
(`R/nested-resamples.R:216`, `R/parallel.R:78-84`) resolve as well.

**AC4 — verified.** All 8 `ambiguous` row IDs (F001, F006, F007, F051, F052,
F053, F059, F106) appear in the `ambiguous` section, each stating what pulls it
toward two buckets rather than being forced into one; `[.nested_results` gets the
same treatment in the addendum. The three the first defect return moved here name
the residue tune's exported counterpart does not cover — the already-fitted
refusal at `R/checks.R:20-29`, absent from tune's own `check_workflow()`, and the
once-per-design timing the comment at `R/checks.R:228` records.

**AC5 — verified.** `NAMESPACE` at this commit carries 8 `export()` and 10
`S3method()` lines; the note accounts for all 18. The 5 exports mapped to ledger
entries check out by ID and name (F025 `nested_resamples`, F068
`nested_tune_grid`, F021 `nested_final_fit`, F012 `extract_tune_results`, F015
`extract_scored_candidates`), and those are the only 5 rows in the ledger carrying
export status `exported`. The 3 the extraction output does not define
(`autoplot`, `collect_metrics`, `extract_workflow`) are listed as re-exports and
excluded; `R/reexports.R` holds exactly three bare `pkg::generic` statements. The
9 mapped S3 methods check out by ID and name; the tenth,
`S3method("[",nested_results)`, is reconciled against the addendum. The exclusion
is written as a subtraction rule over the procedure's output, not a name registry.

**AC6 — verified.** The draft exists at `benchmarks/upstream-asks.md`, unposted
(line 3 says so, and nothing has been opened upstream). Its framing sentence
"nestedtune continues as a package" is at line 13, ahead of the first ask heading
(`## T-A1 …`, line 57). A script cross-checked all 28 `glue` and
`resampling-layer` row IDs against the draft's level-2 sections: every one appears
under **exactly one** section, none in the preamble — T-A1 4, T-A2 4, T-A3 5,
T-A4 3, R-A1 3, R-A2 3, R-A3 1, R-A4 4, R-A5 1. F061 `new_tbl()`, the entry the
second defect return failed AC6 on, now sits under T-A1 alongside the other three
helpers `new_bare_tibble()`'s doc block covers, so no entry takes AC6's
no-upstream-ask disjunct. Every `Retires: … N functions, ~M lines` figure was
recomputed from the ledger's own line counts: **all 9 correct** for both the
function count and the line total. The three overstatements the last return named
are fixed and re-read here: T-A4 states that promising `choose_framework()` alone
leaves F083's second caller `pool_is_cancellable()` (`R/parallel.R:47`, confirmed)
standing and asks for `mirai_installed()` too; T-A3 splits into three parts and
marks F076 and F079 conditional; and the framing's arithmetic is restated — 28
entries reached, 27 retired whole, `check_nested()` surviving in part, so 79 of
106 with one of them thinner, which R-A2's own body agrees with. T-A5's D-025
quotations resolve verbatim at `cairn/DECISIONS.md:741-743` and `:743-747`, and
its four `check_rset` citations resolve in the tune clone (`R/checks.R:4`,
`:19-21`, `NAMESPACE:189`, `R/tune_grid.R:360`, `R/tune_bayes.R:322`).

**Consistency gate — clean.** `cairn_validate.py` exits 0; all 16 PASS checks
pass, including `scaffold present`, `coverage complete`, `binding criteria` and
`references index<->disk`. Advisories: 18 `references staleness`, unchanged in
count and none naming the new page, plus one `sizing` tripwire (M28 carries 16
tasks against the 10-task threshold — the eight rework tasks the two defect
returns convened). No `DESIGN.md` principle changed, so `cairn_impact.py` is
skipped. Toolchain slot (`r-package`): `devtools::document()` leaves no diff under
`R/`, `man/` or `NAMESPACE`; `devtools::check()` is 0 errors, 0 warnings, 0 notes
in 3m 0.1s; `devtools::test()` is FAIL 0, WARN 0, SKIP 0, PASS 1628;
`pkgdown::check_pkgdown()` finds no problems; no `README.Rmd` exists; both new
paths are already `.Rbuildignore`d (`^cairn$` line 1, `^benchmarks$` line 11); the
milestone has no user-visible change, so `NEWS.md` is owed no entry.

**Review routing.** Declared surface tier is internal and
`git diff origin/main...HEAD --name-only` is markdown-only
(`benchmarks/upstream-asks.md`, `cairn/ROADMAP.md`, this file,
`cairn/references/INDEX.md`, `cairn/references/code-inventory.md`) with no script,
hook or other executable surface — so single-reviewer mode: one fresh-context [O]
diff-bug lens, the other two skipped.

### Independent review — single [O] diff-bug lens, 9 findings

Every reported finding and its disposition, ranked as the reviewer ranked them.
Each was re-verified here against the implementation and the pinned clones, not
against the reviewer's account of it. The reviewer's own mechanical pass agreed
with the gate's on every count: 106/106 ledger rows correct for name, `file:line`,
line count, export status and bucket; counts 32/38/16/12/8; the `NAMESPACE`
reconciliation exact; all 28 draft placements correct; all nine `Retires:` sums
right; ~45 upstream citations resolving, including the 152/62 export counts and
the D-025 quotations.

**H1. `cairn/references/code-inventory.md:509-513` — the sweep missed a fourth
exported tune counterpart, and mis-describes the symbol cited in its place.**
The note says `check_extra_tune_parameters()` (tune `R/checks.R:361`, unexported)
"repeats the column-versus-parameter half" of F007. Re-read here: it takes only a
workflow and compares `generics::tune_args(mod)` against
`extract_parameter_set_dials(mod)` — it never receives a grid, so it cannot make
F007's check. The actual counterpart is `.get_config_key()`
(`R/loop_over_all_stages-helpers.R:412`), **exported at `NAMESPACE:144`** with
`#' @keywords internal` / `@rdname empty_ellipses` at `:410-411`, whose two aborts
are F007's two setdiffs line for line: `setdiff(info$id, names(grid))` at `:416`
against `R/checks.R:261`, and `setdiff(names(grid), info$id)` at `:425` against
`R/checks.R:248`. Both facts confirmed at the gate. No criterion fails — F007 is
`ambiguous`, AC2 does not quantify over it, and AC4 asks only for a stated reason,
which F007's timing reason supplies independently of which tune symbol duplicates
its content. But it is a fourth counterpart the sweep missed, in the section added
to close exactly that gap.

**H2. `cairn/references/code-inventory.md:112`, `:444-446`,
`benchmarks/upstream-asks.md:344-345` — the sweep's "found none on the rsample
side" is over-broad.** rsample exports `reshuffle_rset()`
(`R/reshuffle_rset.R:16`, fully documented, not `@keywords internal`) and
`.get_split_args()` (`R/misc.R:142`), which together recover an rset's creating
arguments and re-run them: `do.call(rset_type, c(list(data =
rset$splits[[1]]$data), split_arguments))` at `:45-48`. Confirmed at the gate.
AC3 does not fail, and the note's own narrower claim is true as written:
`reshuffle_rset()` re-runs an rset's *creating call* against its *own* frame,
where F009 re-runs a nested design's stored `inside` call against a *different,
whole* dataset — rsample still exposes nothing that does that. What is wrong is
the sweep's completeness claim, which should name this mechanism and say why it
does not reach F009.

**H3. `cairn/references/code-inventory.md:102-103` — self-contradiction about the
`load_pkgs` doc block.** The sweep section says its three hits are "all three
exported and all three in the `empty_ellipses` doc block"; the glue preamble at
`:279-280` says `load_pkgs` "carries `@keywords internal` on its own block
(`R/load_ns.R:9`) without joining any of the three", and its `empty_ellipses`
roster at `:268-271` correctly omits it. The preamble is right — confirmed in the
clone, `R/load_ns.R:9` carries a bare `@keywords internal` with no `@rdname`. The
sweep sentence is the wrong one.

**H4. `benchmarks/upstream-asks.md:21-23` — the headline arithmetic overstates
T-A3.** The framing says "Twenty-seven of those go entirely … 79 of its 106".
T-A3's own body says the opposite of two of them: "Documenting the shape does not
delete F079 `empty_metrics()`" (`:190-191`) and "If tune has no appetite … F076
stays here, and this ask retires four of the five" (`:199-201`), and its Retires
header calls both conditional (`:167-169`). Under the asks as written at most 25
go entirely, i.e. 81. AC6 still holds — each entry is placed under an ask that
would retire it, T-A3 stating its own conditions honestly — but this is the same
overstated-retirement shape as the last return's G2/G4, moved up into the preamble.

**H5. `benchmarks/upstream-asks.md:167` — F077's retirement is asserted, never
argued.** F077 `bind_notes()` is listed among those T-A3 retires "outright", and
appears nowhere else in the draft (one grep hit in the file). Part 1 attributes
only F075 and F078 to the `new_note()`/`append_log_notes()` export; part 2 is
F079, part 3 is F076. Confirmed at the gate.

**H6. `benchmarks/upstream-asks.md:105-110` — the wrong `workflows` predicate is
named for F002.** The paragraph opens "F002 is also a `workflows` question wearing
a tune coat: `workflows` has an unexported `has_spec()`". `has_spec()` is the
*model-spec* question — F001's branch — not F002's preprocessor question.
Half-refuted here: the reviewer added that `has_preprocessor` "does not exist in
workflows at all", which is true of that name but misses the trio that does exist
unexported and is exactly F002's question — `has_preprocessor_formula`,
`has_preprocessor_recipe`, `has_preprocessor_variables` (checked against installed
workflows 1.3.0). So the remedy sentence — that workflows export the predicates —
is sound; the predicate it names is not.

**H7. `benchmarks/upstream-asks.md:77-78, 88-89` — T-A1's stated remedy does not
reach `load_pkgs`.** The remedy is "a short … note in `empty_ellipses` and
`choose_metric`". F003 is one of T-A1's four claimed retirements and rests only on
`load_pkgs`, which is in neither block (its own block, `R/load_ns.R:1-10`); the
draft gestures at "the same promise as above" without widening the remedy to cover
it. Confirmed at the gate.

**H8 (minor). `cairn/references/code-inventory.md:257-258`,
`benchmarks/upstream-asks.md:37-39` — the sweep is credited with finding all
twelve exported symbols.** It found three (`:102-110`); the other nine came from
T9's per-symbol re-read after the first defect return, which the sweep then
confirmed. Imprecision about provenance, not a false fact about tune.

**H9 (minor). rsample's `get_rsplit()` goes unmentioned for F028.** rsample
exports `get_rsplit()` (`R/misc.R:209`, documented, not internal), an accessor
onto the split that `split_data()` reaches by hand as `x$splits[[1]]`. The note's
claim at `:451-455` — that nothing returns the *frame* — remains true, so this is
a half-counterpart the sweep does not name rather than a counterpart it missed.

**Return floor.** No finding demonstrates an acceptance criterion failing inside
its own domain, and each was checked against the criterion's text rather than its
gist: H1 and H2 fall outside AC2's and AC3's quantified domains and leave AC4's
stated-reason requirement intact; H3–H9 are statements no criterion quantifies
over. AC6's placement and arithmetic requirements survive H4. The remaining
question at the gate is the maintainer's half of the floor — whether H1, taken
with H3, H4 and H5, is a load-bearing defect in what the deliverables do for their
readers.

**Thrash rule.** This is the third review pass and the second defect return stands
on the record; a third defect return would fire trigger (a), whose recommended
disposition is descope-or-park rather than another retry. Trigger (b) is already
recorded as fired on AC6. H1 is a third instance of the class both prior returns
turned on — a claim about an upstream export surface that the instrument in hand
did not reach — though this time the instrument is a stated, re-runnable sweep
rather than author recall, and the miss is in an `ambiguous` entry no criterion
quantifies over.

**CI — one red job, pre-existing and not this diff's.** On PR #38,
`macos-latest (release)` fails in ~1m30s during `R CMD build`'s install step:
`unable to load shared object '…/gower/libs/gower.so': symbol not found in flat
namespace '___kmpc_barrier'` — the RSPM macOS arm64 binary of a transitive
dependency, built against an OpenMP runtime the runner image does not carry. The
same job fails identically on `origin/main` at `142aac3` (the M30 merge run), so
it predates this branch, and this branch changes five markdown files and no R
code. It is a merge blocker under the never-merge-red rule and needs its own
disposition.

**Triage at the gate — all nine actioned fix-now, none returning the milestone.**
The maintainer chose to fix all nine on the branch rather than return M28 or ship
the documents with the defects logged. No finding met the return floor: none
demonstrates an acceptance criterion failing inside its own domain, and the
maintainer did not judge any of them a load-bearing defect in what the two
documents do for their readers. The defect-return count stays at two and the
thrash rule's third-return threshold is not reached. What each fix did:

- **H1** — `.get_config_key()` (tune `R/loop_over_all_stages-helpers.R:412`,
  `NAMESPACE:144`, `@rdname empty_ellipses` at `:410-411`) is now named as F007's
  counterpart, with its two aborts matched to F007's two `setdiff()` calls
  (`:416` against `R/checks.R:261`, `:425` against `:248`, all four re-read here).
  The false claim about `check_extra_tune_parameters()` is replaced by a
  parenthetical saying what that function actually does and that an earlier draft
  got it wrong. F007 stays `ambiguous`: the correction strengthens the
  by-content-it-is-duplication half and leaves the timing residue that put it
  there untouched.
- **H2** — the sweep record now names `reshuffle_rset()` (`R/reshuffle_rset.R:16`)
  over `.get_split_args()` (`R/misc.R:142`) and says why it does not reach F009:
  it re-runs an rset's own creating arguments against that rset's own frame, where
  F009 re-runs a nested design's stored inner call against a different frame. The
  same is added to F009's entry and to R-A3, which now names it as the place an
  inner-specification counterpart would sit.
- **H3** — the sweep section no longer says all its hits are in `empty_ellipses`;
  it states which are, and that `load_pkgs` is on its own block, which is what the
  glue preamble already said.
- **H4** — the draft's headline arithmetic is replaced by the range with its
  working shown: 28 reached, `check_nested()` surviving in part leaves 27 that
  could go whole, three of those conditional on parts of T-A3 tune may decline, so
  24 on any reading — 82 of 106, or 79 if tune takes T-A3 whole. The three
  conditional entries are no longer named by ID in the preamble, so no entry
  appears in two sections.
- **H5** — F077's retirement moves from outright to conditional, in the ask's
  header and its body. Checked against the implementation rather than asserted:
  `bind_notes()` (`R/nested-tune-grid.R:567`) concatenates two note frames
  column-wise into a `new_tbl()`, while tune's `append_log_notes()`
  (`R/logging.R:282`) accumulates onto a single frame as results arrive — a
  different shape, so it retires F077 only if this package adopts that shape. The
  conditional line total is now ~29 across F076, F077 and F079.
- **H6** — the `workflows` paragraph names the right predicates. Checked against
  installed workflows 1.3.0: `has_preprocessor_formula()`,
  `has_preprocessor_recipe()` and `has_preprocessor_variables()` are F002's three
  questions and are unexported; `has_spec()` is F001's question, not F002's. The
  remedy — that workflows export its own predicates — is unchanged and stands.
- **H7** — T-A1's remedy is widened: the promise is asked for on
  `empty_ellipses`, `choose_metric`, **and** `load_pkgs`'s own block, with the
  note that a promise scoped to the first two would leave F003 uncovered.
- **H8** — both documents now say nine exported symbols came from the per-symbol
  re-read and the sweep confirmed them and added four; the sweep's completeness is
  stated as a claim about one reading of 214 names, re-runnable so a later pass
  can test it rather than inherit it.
- **H9** — F028's entry names `get_rsplit()` (`R/misc.R:209`) as covering the
  reach-the-split half of `split_data()` and stopping where the gap is, since it
  returns an `rsplit` and not a frame.

**Post-fix re-verification.** The ledger is unchanged and re-checked: 106 rows,
name set equal to the extraction output, every `file:line` exact, 106/106 line
counts exact, buckets still 32 core / 38 furniture / 16 glue / 12
resampling-layer / 8 ambiguous. AC6 re-cross-checked: all 28 `glue` and
`resampling-layer` IDs appear under exactly one draft section, none in the
preamble (T-A1 4, T-A2 4, T-A3 5, T-A4 3, R-A1 3, R-A2 3, R-A3 1, R-A4 4, R-A5 1,
28 total), and all nine `Retires:` figures recomputed from the ledger are correct
for both count and line total. Framing sentence at line 13, first ask at line 64.
Every citation added by the fixes resolves in the pinned clones:
`.get_config_key` `R/loop_over_all_stages-helpers.R:410-412` and `:416`/`:425`,
`reshuffle_rset` `R/reshuffle_rset.R:16` and `:45-48`, `.get_split_args`
`R/misc.R:142`, `get_rsplit` `R/misc.R:209`. Gate re-run over the corrected files:
`cairn_validate.py` exits 0, all 16 checks pass, same two advisories;
`devtools::document()` no diff; `devtools::check()` 0 errors, 0 warnings, 0 notes
in 2m 34.8s; `devtools::test()` FAIL 0, WARN 0, SKIP 0, PASS 1628. No `R/`,
`NAMESPACE` or `man/` file differs from `origin/main`.

**macOS CI failure accepted at the gate.** The maintainer authorized the merge with
`macos-latest (release)` red, on the recorded finding that it fails identically on
`origin/main` at `142aac3` on a broken RSPM macOS arm64 binary of `gower`, a
transitive dependency, and that this branch changes five markdown files and no R
code, so nothing in it can affect that job. Recorded as an accepted known-red
merge, not a green one.

**A second red job, found after the gate: `ubuntu-latest (devel)`.** It shows as
`pending` for 20 minutes before resolving, so every CI check earlier in this
review caught it unresolved and the macOS job was reported as the only failure.
It is not a second instance of the macOS problem and not the M14/M16 test-stall
phenomenon either. It is `cancelled` by the `timeout-minutes: 20` cap M12 added,
inside `r-lib/actions/setup-r-dependencies@v2` — the job never reaches
`check-r-package`, which is `skipped`. The cleanup log shows it killed mid-C++
compile (`make`, `g++`, `cc1plus` terminated as orphans): on R-devel there are no
Linux binaries, so every dependency builds from source and the install does not
finish inside 20 minutes. Signature confirmed at 2026-08-30T21:05:08Z→21:25:13Z
on this branch.

Pre-existing on the same evidence the macOS finding rests on: the job is
`cancelled` on all eight R-CMD-check runs on this branch **and on `origin/main` at
`142aac3`** (18:19:20Z→18:39:23Z, the same 20m03s), and this branch changes five
markdown files and no R code, so nothing in it can affect a dependency-install
step. The gate authorization named the macOS job alone, so the merge stops here
for a decision covering this one too.

- 2026-08-30: status review → blocked at the merge gate. Every acceptance criterion is verified with fresh evidence, the consistency gate is clean, and all nine reviewer findings were fixed on the branch and re-verified — nothing about M28's own work is outstanding. The blocker is external: two CI jobs, `macos-latest (release)` and `ubuntu-latest (devel)`, are red on every run of this branch and of `origin/main` at `142aac3`, for reasons no package code reaches, and the user chose to fix both before merging rather than accept them. Captured as a ROADMAP candidate row; PR #38 stays open and no approval marker was written.
