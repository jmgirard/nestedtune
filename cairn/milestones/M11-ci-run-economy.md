# M11: Every CI run is one somebody is waiting for

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m11-ci-run-economy` · https://github.com/jmgirard/nestedtune/pull/11

## Goal

Both GitHub Actions workflows stop running on commits that change no packaged
file, and stop finishing runs a later push has already made obsolete.

## Scope

**In:** A `concurrency` block on `.github/workflows/R-CMD-check.yaml` and
`.github/workflows/test-coverage.yaml` that cancels a superseded run on every
ref except the default branch; a `paths-ignore` filter on both triggers of both
workflows covering `cairn/**`, `CLAUDE.md`, and `.claude/**`; a committed
measurement script that classifies historical runs and reproduces the recorded
baseline; and `cairn/PROFILE.md`'s `test-doctrine` CI bullet brought in line with
what the repo runs.

**Out:** Reducing the OS/R matrix on pull requests → candidate row (measured to
save a median of 0.0 min wall-clock; drops pre-merge R-devel and oldrel-1
coverage). Cancelling superseded runs on the default branch → same candidate row
(17 runs / 372 min forgone, deliberately, to keep every default-branch commit
carrying a completed check). Actions cache pressure, 5.82 GB across 61 entries
against a 10 GB limit → its own candidate row. pkgdown deployment → the existing
candidate row. Dependency caching → already provided by
`r-lib/actions/setup-r-dependencies`.

## Acceptance criteria

- [x] AC1. Both workflow files carry a top-level `concurrency` block whose
      `group` distinguishes workflow and ref, and whose `cancel-in-progress`
      expression evaluates to `false` for a run on the repository's default
      branch and `true` for every other ref these workflows trigger on.
- [x] AC2. Two pushes to this milestone's own branch, the second made while the
      first run is still in progress, leave the first run of each workflow with
      conclusion `cancelled` and the second reaching `success` or `failure`;
      the `gh run list` output showing both is recorded in the Review section.
- [x] AC3. Both workflows carry `paths-ignore` on both their `push` and
      `pull_request` triggers, listing exactly `cairn/**`, `CLAUDE.md`, and
      `.claude/**`, and no packaged path (`R/`, `tests/`, `man/`, `vignettes/`,
      `DESCRIPTION`, `NAMESPACE`, `.github/workflows/`) matches any of them.
- [ ] AC4. The committed script reads the `paths-ignore` list out of the
      workflow files, enumerates every default-branch commit in the window
      from `git log` — never from the runs those commits fired, so the
      classification survives the filter going live — and classifies each as
      skipped or run. Over the window `[2026-07-26T00:00Z, 2026-07-27T07:00Z)`
      it reports 22 of 32 default-branch commits skipped, and every one of the
      remaining 10 changes at least one packaged path. Its classification is
      committed as evidence.
- [ ] AC5. The same script, over the same window and counting only runs whose
      `status` is `completed`, reports the baseline recorded in this file:
      108 runs, 324 jobs, 2,276 raw machine-minutes (summed per job as
      `completed_at - started_at`); 30 runs / 628 min on skipped commits; 32
      runs / 823 min superseded, where superseded means a later run on the same
      branch and workflow was created before this run's `updated_at`, of which 9
      runs / 248 min are off the default branch. The two categories overlap and
      are reported separately, not as a partition. It additionally reports the
      minutes cancellation actually reclaims — the tail of each superseded run
      after its successor was created, not the run's whole duration — as 442
      min across all 32 superseded runs and 162 min across the 9 off the
      default branch.
- [x] AC6. `cairn/PROFILE.md`'s `test-doctrine` CI bullet names both
      divergences from the stock `usethis::use_github_action("check-standard")`
      shape and why each is there, and contains no clause the path filter
      falsifies — in particular its "never merges red or pending CI" clause is
      reconciled with a filtered event leaving a check pending.
- [x] AC7. `Rscript -e 'devtools::check()'` clean (0 errors, 0 warnings, no new
      NOTE), confirming the added script needs no `.Rbuildignore` entry beyond
      the existing `^\.github$`.

## Coverage

- AC1 → T2
- AC2 → T2, T6
- AC3 → T3
- AC4 → T4, T5
- AC5 → T1, T4
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1. Write `.github/ci-usage.py`: fetch runs + jobs from the Actions REST
      API, bound a window on `created_at` and `status == completed`, and report
      run/job counts and per-job raw minutes. Record the AC5 baseline.
- [x] T2. Add the `concurrency` block to both workflows
      (`.github/workflows/R-CMD-check.yaml:2`, `test-coverage.yaml:2`), keyed on
      workflow + ref, cancelling on every ref but the default branch.
- [x] T3. Add `paths-ignore` to the `push` and `pull_request` triggers of both
      workflows. Note `pull_request` filters on the whole PR diff, so it fires
      only for a wholly-tracking PR — the `push` trigger is where the saving is.
- [x] T4. Extend the script to parse `paths-ignore` out of the workflow file and
      replay default-branch history through it; commit the classification.
- [x] T5. Rewrite the `cairn/PROFILE.md:45` CI bullet for AC6, including the
      pending-check reconciliation.
- [x] T6. Push twice in quick succession to capture the AC2 cancellation
      evidence, then run `devtools::check()` for AC7.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: started; branch `m11-ci-run-economy` cut from `main` at c248bcd.
- 2026-07-27: T1 — `.github/ci-usage.py` reproduces the AC5 baseline exactly (108 runs / 324 jobs / 2276 min; 30/628 skipped; 32/823 superseded, 9/248 off-branch) and the AC4 classification (15 of 24 commits skipped, all 9 others touching a packaged path).
- 2026-07-27: minor reorder — T1 also delivered T4's workflow-file parsing, since the script needs one ignore-list source, not two; T4 now only regenerates the committed baseline once T3 gives the workflows a real list to read.
- 2026-07-27: T2, T3 — both workflows gained the concurrency block and the path filter on both triggers; all four lists verified identical by parsing the YAML, and the script now reads them from the workflow files instead of its fallback.
- 2026-07-27: T4, T5 — baseline regenerated with the filter read from the workflows (identical to the fallback run, so the declared list matches what was measured) and committed at `.github/ci-usage-baseline.md`; PROFILE.md's CI bullet rewritten, and compressed in one pass after the first draft put the file 1 line over its 120-line cap.
- 2026-07-27: `devtools::test()` clean on the branch — FAIL 0, WARN 0, SKIP 0, PASS 1175.
- 2026-07-27: the filter list is spelled out under each of the four triggers rather than shared by a YAML anchor — GitHub Actions does not resolve anchors in workflow files, and an unresolved alias would have silently disabled the filter.
- 2026-07-27: T6 — PR #11 opened at the user's direction so AC2's cancellation could be observed here; a branch gets no runs without one, since the `push` trigger is limited to `main`/`master`. Review records the URL in the header slot as usual.
- 2026-07-27: AC2 evidence — pushes at 07:53:04Z and 07:53:43Z on PR #11. Superseded runs 30247760551 (R-CMD-check) and 30247760779 (test-coverage) both ended `cancelled` within 46s; replacements 30247801003 and 30247800950 both ended `success`.
- 2026-07-27: AC3 second clause checked mechanically against the workflows' own list — no packaged path (`R/`, `tests/`, `man/`, `vignettes/`, `DESCRIPTION`, `NAMESPACE`, `.github/`, `_pkgdown.yml`) matches any glob, and every tracking path does.
- 2026-07-27: AC7 — `devtools::check()` Status OK, 0 errors / 0 warnings / 0 notes in 5m23s; the two new `.github/` files need no `.Rbuildignore` entry beyond `^\.github$`.
- 2026-07-27: removed a `.github/__pycache__/` bytecode file swept into the T6 commit by the AC3 import check, and gitignored the pattern; `.Rbuildignore`'s `^\.github$` kept it out of the build, so AC7's clean check is unaffected.
- 2026-07-27: all tasks done, status → review.
- 2026-07-27: review returned M11 to in-progress (return 1). AC4 fails: the script derives its commit set from runs, so it replays 24 of the 32 commits git counts in the window, and once the filter is live a skipped commit fires no run and vanishes from the set entirely. Three more findings actioned (F4 false comment about drift detection, F5 silent glob corruption, F1 superseded minutes overstated); 9 logged below threshold. AC1, AC2, AC3, AC5, AC6, AC7 verified; consistency gate green.
- 2026-07-27: AC4 amended at a gate — the commit list now comes from `git log`, not from the runs commits fired, and the counts are corrected to 22 of 32 skipped / 10 run. AC5 extended at the same gate to pin the reclaimed-tail figures (442 min all superseded, 162 min off the default branch), so F1's correction is checkable rather than trusted. AC5's existing figures are unchanged and its tick is cleared pending re-verification.
- 2026-07-27: F2 fixed — the commit set now comes from `git log`, so the classification survives the filter going live; 22 of 32 skipped, 10 run, each with a packaged path.
- 2026-07-27: F5 fixed — the glob parser strips quotes and trailing comments correctly and exits non-zero on inline flow style, an unterminated quote, a negation pattern, or any character it does not understand, instead of returning a corrupt glob that matches nothing.
- 2026-07-27: F4 fixed — every `paths-ignore` block is compared separately, so drift between two triggers of the same file now fails loudly; the workflow comments claiming this are true as of this commit.
- 2026-07-27: F1 fixed — the table separates what runs cost from what removing them reclaims; cancelling off-branch superseded runs reclaims 162 min of the 248 those runs lasted, so the honest total removed is 790 min, not 877.
- 2026-07-27: F11 (logged below threshold) surfaced for real while verifying AC4 — `git diff-tree` reports no files for a root commit without `--root`, and this repo's first commit is one, so `a7ef98f` was classified "run" on zero evidence. Fixed with `--root`, and an empty file list is now an error rather than a classification. F13, F8, F10 and the pagination half of F7 fell out of the same rewrite.
- 2026-07-27: PROFILE.md's measurability claim corrected for F13 and the bullet block compressed twice — the first rewrite went 2 over the 120-line cap, the second landed at 119.
- 2026-07-27: `devtools::test()` clean after the fixes — FAIL 0, WARN 0, SKIP 0, PASS 1175. All four actioned findings fixed; back to review.

## Decisions

## Review

_Reviewed 2026-07-27 on `m11-ci-run-economy` at PR #11; evidence gathered fresh
by command, never recalled._

### Acceptance criteria

- **AC1 ✓** Both workflows carry an identical top-level `concurrency` block:
  `group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress:
  ${{ github.ref_name != github.event.repository.default_branch }}`. On a
  default-branch push `ref_name` equals `default_branch`, so the expression is
  `false`; on a pull request `ref_name` is `<n>/merge` and on a `master` push it
  is `master`, so both are `true` — every ref these workflows trigger on is
  covered.
- **AC2 ✓** Observed twice, not once. Pushes at 07:53:04Z/07:53:43Z and
  08:07:18Z/08:07:39Z each left both superseded runs `cancelled` (30247760551,
  30247760779, 30248652805, 30248651870) and both replacements `success`
  (30247801003, 30247800950, 30248674159, 30248674036). Cancellation landed
  within 46s of the superseding push in every case.
- **AC3 ✓** All four triggers (both workflows × `push`/`pull_request`) carry the
  identical list `cairn/**`, `CLAUDE.md`, `.claude/**`. Second clause checked
  mechanically against the workflows' own parsed list: of 13 packaged paths
  (`R/`, `tests/`, `man/`, `vignettes/`, `DESCRIPTION`, `NAMESPACE`, `NEWS.md`,
  `README.md`, `_pkgdown.yml`, `.Rbuildignore`, `.github/`) none matches any
  glob, and all 6 tracking paths tested do.
- **AC4 ✗ FAILS.** The script parses the list out of the workflow files
  (reported source: `R-CMD-check.yaml, test-coverage.yaml`, not its fallback),
  but it does not "replay every default-branch commit in the window": its
  commit set is derived from runs, so it sees only commits that fired one.
  `git log main --since --until` over the same window counts **32** commits;
  the script reports 24. The criterion's two clauses cannot both hold. Ticked
  in error earlier in this review — the tick rested on the script's own
  self-report rather than on an independent count, which is the exact failure
  AC fencing exists to catch.
- **AC5 ✓** Re-run at review time and `diff`ed against
  `.github/ci-usage-baseline.md`: byte-identical. 108 runs, 324 jobs, 2276
  machine-minutes; 30 runs / 628 min on skipped commits; 32 runs / 823 min
  superseded, 9 / 248 off the default branch. The two categories are printed
  separately with an explicit note that they overlap and are never summed.
- **AC7 ✓** `devtools::check()` Status OK — 0 errors, 0 warnings, 0 notes in
  6m56s, re-run fresh at review time. The two new `.github/` files need no
  `.Rbuildignore` entry beyond the existing `^\.github$`.
- **AC6 ✓** `cairn/PROFILE.md`'s `test-doctrine` slot names both divergences
  with a reason each, and the merge clause is now stated once and reconciled:
  a filtered event produces no run, so its check is absent rather than pending
  and merging past it is correct; the clause forbids merging past a check that
  ran and failed or is still running. The required-status-checks caveat is
  recorded against the day branch protection is added.

### Consistency gate

- `cairn_validate`: all checks passed (16 PASS, 7 advisory OK).
- `cairn_impact`: not run — `Principles touched: —`, no principle changed.
- Profile `consistency-gate` slot: `devtools::document()` no diff ·
  `pkgdown::check_pkgdown()` no problems · no `README.Rmd` in this repo, so the
  knit check does not apply · new files are `.github/`-resident, covered by the
  existing `^\.github$` · **no NEWS.md entry**, deliberately: M11 changes no
  packaged behavior, and the slot scopes the changelog to user-visible changes.

### Independent review — three lenses, then scoring

Three fresh-context reviewers with distinct evidence bases, then a separate
scorer that did not generate the findings.

- **[S] prior-PR-comments lens:** no prior-review evidence. No archived
  `## Review` section touches these files; it correctly ruled out M09's
  cancellation work as unrelated (mirai worker cancellation in R, not Actions
  run cancellation). Zero findings, as expected.
- **[S] blame-history lens:** no findings. Only two commits ever touched the
  workflow files (M01's `fafb31f` creation and this branch's `97ef2b3`), so
  there is no prior fix to undo; the PROFILE.md rewrite elaborates the merge
  clause rather than dropping it; the `.gitignore` entry follows the file's
  existing convention of explaining what motivated each rule.
- **[O] diff-bug lens:** 13 findings, scored below.

**Actioned (score ≥ 80) — all four return to implement:**

- **F2 (95)** `ci-usage.py:214-227` — the commit denominator is derived from
  runs, not from git, so the script cannot measure its own change. Verified by
  execution: git 32, script 24. Forward-looking half is worse — once the filter
  is live a skipped commit fires no run, so it never enters the commit set, and
  a post-M11 window reports "0 of N skipped", indistinguishable from "nothing
  to skip". **This is the AC4 failure.**
- **F4 (93)** `R-CMD-check.yaml:10-11`, `test-coverage.yaml:3-4` — the comment
  claims the script "fails loudly if the two copies ever disagree"; it does
  not. `read_paths_ignore()` unions every block within a file before comparing
  across files, so within-file drift — the exact drift the duplicated list
  invites — is silently absorbed. Verified: two differing blocks in one file
  yield `['CLAUDE.md', 'cairn/**']` and no error.
- **F5 (90)** `ci-usage.py:106-113` — the regex parser silently produces wrong
  globs instead of failing. Verified: a trailing YAML comment yields the glob
  `` cairn/**'  # tracking only `` (matches nothing, so every `cairn/` commit
  reclassifies as "run"); inline flow style matches zero blocks and drops the
  file out of the agreement check, falling back to the hardcoded list.
- **F1 (82)** `ci-usage.py:251-253` — superseded runs are charged their entire
  duration, but cancellation only reclaims the tail after the superseding push.
  The 248 min and the bolded 877 total are upper bounds presented as
  measurements, unqualified in `render()` and in the committed baseline.

**Logged below threshold (score < 80), 9 findings — surfaced, not actioned:**

- F13 (72) PROFILE.md's "measurable with `ci-usage.py`" does not hold forward
  for the path filter; a consequence of F2 and fixable with it.
- F9 (65) `superseded()` misses a run superseded by one outside the window or
  still in flight — an undercount at the upper window edge.
- F8 (62) job fetch is unpaginated and takes the latest attempt only, so a
  re-run silently drops the first attempt's jobs and minutes.
- F10 (60) the `removed` union matches on `head_sha` alone, dropping the
  event/branch guard `skipped_runs` applies. Dormant (30 + 9 = 39 checks out).
- F7 (58) pagination has no lower bound and a 20-page cap, so a narrow old
  window on a busy repo prints zeros indistinguishable from an idle week.
- F3 (55) classification is per-commit but GitHub filters per-push, so a push
  mixing code and tracking with a tracking-only head sha is misclassified.
- F11 (52) a true merge commit yields no files from `git show`, classifying it
  "run" with zero evidence and vacuously satisfying AC4's second clause.
- F6 (48) `fnmatch`'s `*` crosses `/` where GitHub's does not, and `!` negation
  patterns are treated as literals. No committed glob exercises either path.
- F12 (42) if `github.event.repository` were ever absent the concurrency
  expression degrades to `true`, cancelling on the default branch — the one
  outcome the milestone forbids. Needs a trigger type neither workflow has.

### Gate outcome

**Returned to `in-progress` — return 1 of this milestone.** AC4 fails as
written, and the criterion is itself inconsistent: "replays every
default-branch commit in the window" and "15 of 24" cannot both hold when git
counts 32. Fixing this needs a gated AC4 amendment at
`/milestone-implement` step 6 alongside the code fix, then re-review.
Everything else verified: AC1, AC2, AC3, AC5, AC6, AC7 all hold on fresh
evidence, and the consistency gate is green.

