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
- [x] AC4. The committed script reads the `paths-ignore` list out of the
      workflow file itself, replays every default-branch commit in the window
      through it, and classifies each as skipped or run. Over the window
      `[2026-07-26T00:00Z, 2026-07-27T07:00Z)` it reports 15 of 24
      default-branch commits skipped, and every one of the remaining 9 changes
      at least one packaged path. Its classification is committed as evidence.
- [x] AC5. The same script, over the same window and counting only runs whose
      `status` is `completed`, reports the baseline recorded in this file:
      108 runs, 324 jobs, 2,276 raw machine-minutes (summed per job as
      `completed_at - started_at`); 30 runs / 628 min on skipped commits; 32
      runs / 823 min superseded, where superseded means a later run on the same
      branch and workflow was created before this run's `updated_at`, of which 9
      runs / 248 min are off the default branch. The two categories overlap and
      are reported separately, not as a partition.
- [x] AC6. `cairn/PROFILE.md`'s `test-doctrine` CI bullet names both
      divergences from the stock `usethis::use_github_action("check-standard")`
      shape and why each is there, and contains no clause the path filter
      falsifies — in particular its "never merges red or pending CI" clause is
      reconciled with a filtered event leaving a check pending.
- [ ] AC7. `Rscript -e 'devtools::check()'` clean (0 errors, 0 warnings, no new
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
- **AC4 ✓** The script parses the list out of the workflow files (reported
  source: `R-CMD-check.yaml, test-coverage.yaml`, not its fallback) and
  classifies 15 of 24 default-branch commits as skipped. The 9 classified as
  run each show packaged paths in the committed table — `R/`, `NAMESPACE`,
  `DESCRIPTION`, `NEWS.md`, and for M01 the workflow files themselves.
- **AC5 ✓** Re-run at review time and `diff`ed against
  `.github/ci-usage-baseline.md`: byte-identical. 108 runs, 324 jobs, 2276
  machine-minutes; 30 runs / 628 min on skipped commits; 32 runs / 823 min
  superseded, 9 / 248 off the default branch. The two categories are printed
  separately with an explicit note that they overlap and are never summed.
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

