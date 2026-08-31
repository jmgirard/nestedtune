# M33: The organization's shared CI workflows, and `air` as this repo's formatter

- **Status:** review
- **Priority:** normal
- **Depends on:** M32
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m033-org-ci-workflows` / https://github.com/tidymodels/nestedtune/pull/41

## Goal

The three CI workflows every tidymodels package runs and nestedtune does not —
thread locking, PR commands, and format suggestions — run here too, with `air`
adopted as the formatter they assume.

## Scope

**Surface tier: user-facing.** The workflows alone would be internal dev
tooling, but adopting `air` rewrites every shipped file in `R/`, so the
deliverable spans both and takes the stricter reading.

**In:** vendor `lock.yaml`, `pr-commands.yaml` and `format-suggest.yaml` at the
modal blobs of the same nine-repository survey M32 states. Adopt `air`: a root
`air.toml`, one reformatting pass over the repository, and the DESIGN.md
Conventions line and D-entry that a first code-style convention needs — DESIGN
records none today. Keep `.github/ci-usage.py` running: it exits non-zero when
any `push`/`pull_request` trigger carries no `paths-ignore` block, and this
milestone adds three workflows.

**Out:** `R-CMD-check-hard.yaml` → a candidate row. It carries both filtered
triggers, so it needs the shared `paths-ignore` block, and this package's
Suggests hold mirai, ranger, recipes and yardstick — most of what the suite
needs — so what a Suggests-free check would actually exercise here is
unestablished. Refreshing `.github/ci-usage-baseline.md` and `PROFILE.md`'s
workflow count beyond what this milestone's own additions require → the
standing "Bring the CI records up to three workflows" candidate row, which this
milestone makes staler and does not close. Every M11/M12/M14/M31 divergence in
the four existing workflows — the `concurrency` block, the `paths-ignore`
filter, the split hang caps — is untouched; each has a measured rationale and
none is up for revision here.

## Acceptance criteria

- [x] `.github/workflows/lock.yaml`, `pr-commands.yaml` and
      `format-suggest.yaml` each hash to the modal git blob of a nine-repository
      survey re-run on the implementation date (`gh api
      repos/tidymodels/<repo>/contents/.github/workflows/<file> --jq .sha` over
      rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom,
      hardhat). On 2026-08-30 those modes were `d55e238e` (7 of 9), `2edd93f2`
      (9 of 9) and `8c4f117d` (6 of the 7 that carry the file). Evidence:
      `git hash-object` per file, and the survey output with its counts.
- [x] `.github/ci-usage.py` still runs: with the three workflows added it exits
      zero over a stated window, and the `paths_ignore.source` it reports names
      the same workflow files it named before this milestone. Evidence: the
      script's own output from before and after the additions, both quoted.
- [x] That exit-zero is informative rather than vacuous: with a scratch
      workflow file added carrying a bare `push:` trigger and no
      `paths-ignore` block, `.github/ci-usage.py` exits non-zero naming that
      trigger; the scratch file is removed and is not committed. Evidence: the
      failing invocation's output quoted.
- [x] `air format .` leaves the working tree unchanged over the whole
      repository. Evidence: the command run on a clean tree, followed by
      `git status --porcelain` printing nothing.
- [x] The reformatting is separable from everything else in the branch: one
      commit performs it, and re-running `air format .` over that commit's
      parent tree reproduces the commit's tree byte for byte apart from two
      named files — `tests/testthat/helper-time-budget.R`, whose `file:line`
      ledger rows the reformatting may move and which is re-pointed by hand in
      the same commit with `test-suite-hygiene.R` passing on it, and this
      milestone's own tracking file. `git show --stat` on that commit lists
      only files under `R/`, `tests/` and `benchmarks/` plus that tracking
      file; `devtools::test()` reports the same PASS and FAIL counts and the
      same set of failing test names on the parent commit and on it; and every
      file the commit touches under `benchmarks/` still `parse()`s. Evidence:
      the reproduction diff, both test summaries, the `--stat` output, and the
      `parse()` results.
- [x] The profile's `verify` slot is clean and the fuller pre-review check
      passes: `devtools::test()` clean, `devtools::document()` no diff,
      `devtools::check()` clean (0 errors, 0 warnings; NOTEs justified).

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T2
- AC4 → T3, T4
- AC5 → T4
- AC6 → T6

## Tasks

- [x] T1: Re-run the nine-repository survey for the three workflow files,
      record the shas and counts in the work log, and vendor the modal texts.
- [x] T2: Run `.github/ci-usage.py` before and after the additions; then add a
      scratch workflow with an unfiltered `push:` trigger, confirm the script
      refuses, and delete it.
- [x] T3: Write `air.toml` (start from the siblings' shape — a `[format]`
      table with `skip` entries — dropping rsample's package-specific
      `exclude`), and install `air` locally by the route
      `posit-dev/setup-air@v1` uses in CI.
- [x] T4: Run `devtools::test()` and record its counts; make the reformatting
      pass its own commit; run `devtools::test()` again and compare.
- [x] T5: Add the DESIGN.md Conventions line naming `air` as the formatter and
      the `cairn/DECISIONS.md` entry adopting it; extend `PROFILE.md`'s
      `test-doctrine` slot to name the three added workflows, without
      attempting the wider records refresh the standing candidate row owns.
- [x] T6: Run `devtools::document()`, `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-08-30: created by /milestone-plan.
- 2026-08-30: plan-gate criteria audit ran in **full** mode (declared surface tier user-facing), in-session rather than by a fresh-context [O] reader, under the harness instruction restricting subagent spawns. Three findings, all fixed before the criteria above were written. (1) A draft criterion promised the reformat "changed no package behavior" — a universal over behaviour whose only named procedure is the test suite, which does not enumerate it (bounded-promise rule); narrowed to the counts and the diff scope the suite and `git show --stat` do settle. (2) Draft criteria requiring a DESIGN.md Conventions line, a D-entry and a PROFILE.md slot edit are recording acts, instrument properties rather than properties of the deliverable (D-118, D-120); moved to T5. (3) A draft AC2 asked only that `ci-usage.py` exit zero, which a broken script also satisfies; AC3 was added as its positive control.
- 2026-08-30: plan gate chose adopting `air` with a one-commit reformat over taking `format-suggest.yaml` without a formatter, because the workflow runs `air format .` and posts every difference as a PR suggestion — on an unformatted tree that is a review comment on nearly every line of every PR, which is worse than not running it; falsified by evidence that `reviewdog/action-suggester` bounds its output, or that the tree is already `air`-clean.
- 2026-08-30: plan gate chose leaving the four existing workflows' M11/M12/M14/ M31 divergences untouched over converging them on the organization's stock files, because each divergence has a measured rationale in its milestone — the split hang caps, the `paths-ignore` filter and the non-default-branch `concurrency` block among them — and none of that evidence has been contradicted; falsified by a stock sibling workflow shown to handle the two recorded hangs and the cold-devel cache deadlock.
- 2026-08-30: checkpoint, tasks not yet ticked. Branch cut; survey re-run and the three workflows vendored at the modal blobs `d55e238e` / `2edd93f2` / `8c4f117d` (`git hash-object` matches all three); `ci-usage.py` run before and after the additions, exit 0 both times naming the same three source workflows; `air.toml` and its `.Rbuildignore` entry written. `devtools::test()` and the fresh-context read of the amended AC5 wording were still running at the checkpoint, so T1-T3 stay unticked.
- 2026-08-30: T1 done. Survey re-run over the nine siblings on 2026-08-30: `lock.yaml` `d55e238e` 7 of 9 (recipes `3f63a3a8`, broom `1fab65a8`), `pr-commands.yaml` `2edd93f2` 9 of 9, `format-suggest.yaml` `8c4f117d` 6 of 7 carrying it (parsnip `24e4fc16`; yardstick and broom carry none) — the same modes the plan states. All three vendored from rsample; `git hash-object` returns the modal sha for each. `devtools::test()` after the additions: FAIL 0 | WARN 0 | SKIP 0 | PASS 1628.
- 2026-08-30: T2 done. `.github/ci-usage.py --since 2026-08-01T00:00:00Z --until 2026-08-31T00:00:00Z` exits 0 before and after the three additions and its output is byte-identical across the pair, `Path filter read from R-CMD-check.yaml, pkgdown.yaml, test-coverage.yaml` both times — none of the three carries a `push` or `pull_request` trigger (`schedule`, `issue_comment`, `pull_request_target`). Positive control: a scratch `zz-scratch-probe.yaml` carrying a bare `push:` and no `paths-ignore` made the same invocation exit 1 with `these triggers carry no paths-ignore while others do ... zz-scratch-probe.yaml:push`; the scratch file was deleted and is not committed.
- 2026-08-30: T3 done. `air.toml` is the siblings' shape, `[format]` with `skip = ["tribble"]` (rsample and dials, minus rsample's package-specific `exclude`); this repo calls `tribble()` nowhere, and the question gate chose the organization's shape over a config carrying only what applies here. `air` 0.11.0 is installed locally and equals `posit-dev/setup-air@v1`'s default, the latest `posit-dev/air` release on 2026-08-30. `.Rbuildignore` gains `^[\.]?air\.toml$`, the entry rsample carries.
- 2026-08-30: question gate chose vendoring the three files at the organization's blobs over pinning the write-token actions (`r-lib/actions/pr-push@v2` under `contents: write`, `posit-dev/setup-air@v1` and `reviewdog/action-suggester@v1` under `pull-requests: write` on `pull_request_target`) to commit shas, because a pin would put each file off its modal blob and AC1 unsatisfiable; M17 review F10 pinned the pkgdown deploy action on the same write-token reasoning, so the divergence is recorded as a candidate row rather than settled here.
- 2026-08-30: AC5 amended at a mini gate, user-selected. `air format .` reaches 60 files — 10 under `R/`, 39 under `tests/`, 11 under `benchmarks/` — so the planned `R/`-and-`tests/` path list was unsatisfiable; the commit must also carry this file under tracking-travels-with-code; and `tests/testthat/helper-time-budget.R`'s 71 `file:line` ledger rows point into six files the formatter moves, which `test-suite-hygiene.R` fails on, so they are re-pointed by hand in the same commit. Two fresh-context [O] readers audited the wording in full mode before it was written, neither having authored it. The first returned four findings (the separability claim enumerated by no named procedure; the ledger edit admitted silently; reformatted `benchmarks/` files exercised by nothing; an instrument-property flag on the path-scope clause, raised and deliberately kept) and corrected the file split, which this session had recorded as 10/40/10. The second, reading the repair, found the exception list incomplete — the tracking file cannot be reproduced by the formatter — and that equal PASS/FAIL counts admit a compensating pair of flips; both are fixed in the text above. AC5 is the only criterion amended.
- 2026-08-30: T4 done in one commit. `devtools::test()` on the parent `1d351cc`: FAIL 0 | WARN 0 | SKIP 0 | PASS 1628, no failing tests; on the reformat commit: the same, so both the counts and the (empty) failing-test set match. `air format .` (air 0.11.0) rewrote 60 files — 10 under `R/`, 39 under `tests/`, 11 under `benchmarks/`. `tests/testthat/helper-time-budget.R`'s 71 ledger rows were then re-pointed: 68 by matching each file's `SYMBOL_FUNCTION_CALL` sequence from `utils::getParseData()` before and after, which was element-wise identical in call order so only line numbers moved, and the 3 rows naming no budgeted call (`test-parallel-detection.R` 183→184 and 188→189, `test-parallel-interrupt.R` 92→98) by a `difflib` line map over the file's own before/after text. A second `air format .` left the re-pointed helper unchanged and `air format --check .` is silent. All 11 reformatted files under `benchmarks/` `parse()` without error.
- 2026-08-30: T5 done. `cairn/DESIGN.md` gains an `air` Conventions bullet, the first code-style convention it records, naming the ledger re-point a reformatting pass forces. `D-028` records adopting `air` and vendoring the three workflows unmodified, with the two gate rejections (taking `format-suggest.yaml` without a formatter; pinning the vendored files' actions). `PROFILE.md`'s `test-doctrine` slot names the three added workflows and that none carries a filtered trigger; the slot's divergences bullet was re-wrapped at 98 columns with no wording change, reclaiming two lines to keep the file under its 120-line cap (119). The write-token action-pin question was absorbed into the standing pkgdown-pin candidate row rather than opened as a new one. The wider CI-records refresh the standing candidate row owns is untouched.
- 2026-08-30: T6 done, milestone to review. `devtools::document()` produced no diff; `devtools::test()` on the branch tip: FAIL 0 | WARN 0 | SKIP 0 | PASS 1628; `devtools::check()` `Status: OK`, 0 errors / 0 warnings / 0 notes in 3m 20.9s, so `air.toml`'s `.Rbuildignore` entry holds. `air format --check .` prints nothing on the committed tree. Reproduction check for AC5: `git archive HEAD~1` into a scratch tree, `air format .` there, `diff -r` against `git archive HEAD` — the only two differing paths are `tests/testthat/helper-time-budget.R` and this file, the two the criterion names; within the helper the difference is 56 `NNNL,` ledger lines and nothing else.
- 2026-08-30: review — every criterion re-executed with fresh evidence, all six met; PR #41 opened as a draft; `cairn_validate` all 16 PASS; three fresh-context reviewers returned five findings, none meeting the return floor.

## Decisions

## Review

### Acceptance criteria

- AC1 — **met.** Nine-repository survey re-run 2026-08-30 via `gh api repos/tidymodels/<repo>/contents/.github/workflows/<file> --jq .sha`: `lock.yaml` `d55e238e` in 7 of 9 (recipes `3f63a3a8`, broom `1fab65a8`); `pr-commands.yaml` `2edd93f2` in 9 of 9; `format-suggest.yaml` `8c4f117d` in 6 of the 7 that carry it (parsnip `24e4fc16`; yardstick and broom return 404). `git hash-object` on the three vendored files returns `d55e238e`, `2edd93f2` and `8c4f117d` — each at its survey's modal blob.
- AC2 — **met.** `.github/ci-usage.py --since 2026-08-01T00:00:00Z --until 2026-08-31T00:00:00Z` run twice: on a scratch clone checked out at `main` (`9b0c177`, four workflows) and on the branch tip (seven). Exit 0 both times, and the two outputs are byte-identical under `diff`; both report `Path filter read from R-CMD-check.yaml, pkgdown.yaml, test-coverage.yaml`, the same three source workflows as before the milestone.
- AC3 — **met.** With a scratch `.github/workflows/zz-scratch-probe.yaml` carrying a bare `push:` trigger and no `paths-ignore`, the same invocation exits 1 with `these triggers carry no `paths-ignore` while others do, so their runs are not filtered and crediting them to the filter would overstate it: zz-scratch-probe.yaml:push`. The scratch file was deleted; `git status --porcelain` shows it gone and it is not committed.
- AC4 — **met.** `air format .` (air 0.11.0) run on a clean tree at the branch tip: exit 0, and `git status --porcelain` printed nothing afterwards.
- AC5 — **met**, on four separate checks of the reformat commit `d03442b`. *Reproduction:* `git archive d03442b^` and `git archive d03442b` into two scratch trees, `air format .` over the first, `diff -r` between them — exactly two paths differ, `tests/testthat/helper-time-budget.R` and this milestone file, the two the criterion names; within the helper all 112 changed diff lines are `NNNL,` ledger numbers (56 rows) and nothing else. *Scope:* `git show --stat d03442b` lists 61 files — 10 under `R/`, 39 under `tests/`, 11 under `benchmarks/`, plus this file, nothing else. *Tests:* `devtools::test()` in clean archives of the parent and of the commit: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1628` on each, with an empty failing-test set on both. *Parse:* all 11 reformatted `benchmarks/` files `parse()` without error.
- AC6 — **met.** On the branch tip: `devtools::document()` produced no diff (`git status --porcelain` empty after it); `devtools::test()` reported `FAIL 0 | WARN 0 | SKIP 0 | PASS 1628`; `devtools::check()` reported `Status: OK` — 0 errors, 0 warnings, 0 notes — in 3m 45.4s.

### Consistency gate

- `cairn_validate.py` exits 0; all 16 checks PASS, `coverage complete` among them. 18 advisory `references staleness` warnings, unchanged from the last hygiene stamp and not a gate failure.
- No `DESIGN.md` IP/GP principle changed in this branch (the DESIGN edit is a Conventions bullet), so `cairn_impact.py` is skipped.
- Profile `consistency-gate` slot (r-package): `document()` no diff; generated files regenerate (the no-diff `document()` covers it); no `README.Rmd` exists — the README is hand-written, which the standing candidate row owns; `pkgdown::check_pkgdown()` reports "No problems found"; `NEWS.md` gains no entry, the milestone changing no user-visible behaviour (developer workflows under `.github/`, plus a formatting pass that leaves the suite's counts and failing-test set identical); `air.toml` carries its `.Rbuildignore` entry and `check()` reports 0 NOTEs; `devtools::check()` clean.

### Independent review

Three fresh-context reviewers, distinct evidence bases, none having seen the implementation: [O] diff-bug over `git diff main..HEAD`, [S] blame-history over `git log`/`git blame` on the modified lines, [S] prior-review record over `cairn/milestones/archive/` plus a probe of GitHub PR threads.

The prior-review lens found no regression: it confirmed the write-token pin divergence from M17 review F10 is disclosed in D-028 and carried as a candidate row rather than silently repeated, and that its GitHub probe returned two real inline comments, both by topepo on the open PR #30, on files this diff does not touch.

**F1 — 125 `file:line` citations across the repo now point at the wrong line, broken by the reformat.** Reported by [O] (ranked 1 and 2) and independently re-measured at review with a script that resolves each citation's pre-reformat line content in the post-reformat file: `cairn/references/code-inventory.md` 82, `cairn/references/outer-loop-object-requirements.md` 29, `cairn/references/mori-backend-assessment.md` 5, `benchmarks/upstream-asks.md` 3, `cairn/ROADMAP.md` 2, and 4 in-code comments (`R/parallel.R` 1, `benchmarks/probe-mori-dispatch.R` 2, `benchmarks/rsample-283-reprex.R` 1). Verified by hand on two: `cairn/references/code-inventory.md:160` records `check_column_class()` at `R/checks.R:185`, which was its `function` line on `main` and is now a comment (the definition moved to 191); `benchmarks/upstream-asks.md:213` cites `bind_notes()` at `R/nested-tune-grid.R:567`, now 572. 108 of the 125 relocate to exactly one new line by content match; the other 17 need the symbol name because the cited line was itself re-wrapped. AC5 promises reproducibility and scope, not citation integrity, so this is outside the criteria — a records defect the diff introduced.
**F2 — `tests/testthat/helper-time-budget.R:44` and `:332` still cite `classify:693` and `:699`.** Reported by [S] (ranked 1) and [O] (ranked 4); verified at review: `test-parallel-classify.R:693` and `:699` are now a closing brace and a blank, and the option-set and option-spend calls the prose names are at 745 and 751. The milestone's re-point procedure matched `tb_row()` call sequences, which by construction never reaches free prose, so this class of citation was never in its scope. Same shape as F1, inside the one file the milestone re-pointed by hand.
**F3 — the vendored `pr-commands.yaml` `/style` job runs `styler::style_pkg()`, a different formatter than the `air` D-028 just adopted.** Reported by [O] (ranked 3) and [S] (ranked 2). A maintainer typing `/style` on a PR commits a styler-formatted tree back to the branch, and `format-suggest.yaml` then posts `air` suggestions over what it just wrote. Not fixable in the file — AC1 holds it at the organization's blob — and D-028 records neither this collision nor a rule against using `/style` here.
**F4 — `cairn/PROFILE.md:46` says "Four divergences from that stock shape (M11 x2, M12 rev. M31, M14)" and the bullet now carries five.** Reported by [O] (ranked 6). The diff appended the three organization workflows as a fifth bolded divergence without bumping the count or the milestone list.
**F5 — the three vendored workflows' action pins and permissions.** Reported by [O] (ranked 7, 8, 9): `format-suggest.yaml`'s `pull_request_target` checks out the PR head into a job holding `pull-requests: write` with `posit-dev/setup-air@v1` and `reviewdog/action-suggester@v1` on moving tags; `lock.yaml` declares no `permissions:` block, so `dessant/lock-threads@v2` runs on the repository's default workflow token and would 403 nightly if that default is read-only; `format-suggest.yaml`'s `permissions:` block zeroes `contents`, which works because the repository is public. None is editable without putting the file off its modal blob, which AC1 forbids. The default-permission setting could not be read at review: `gh api repos/tidymodels/nestedtune/actions/permissions/workflow` returns 403 for this token. The pin half is already carried by the pkgdown-pin candidate row, which the milestone extended.

No finding demonstrates an acceptance criterion failing, and none is a defect in what the package does for its users, so none meets the return floor; dispositions are the maintainer's at the merge gate.

