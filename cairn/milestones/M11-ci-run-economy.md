# M11: Every CI run is one somebody is waiting for

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m11-ci-run-economy`

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

- [ ] AC1. Both workflow files carry a top-level `concurrency` block whose
      `group` distinguishes workflow and ref, and whose `cancel-in-progress`
      expression evaluates to `false` for a run on the repository's default
      branch and `true` for every other ref these workflows trigger on.
- [ ] AC2. Two pushes to this milestone's own branch, the second made while the
      first run is still in progress, leave the first run of each workflow with
      conclusion `cancelled` and the second reaching `success` or `failure`;
      the `gh run list` output showing both is recorded in the Review section.
- [ ] AC3. Both workflows carry `paths-ignore` on both their `push` and
      `pull_request` triggers, listing exactly `cairn/**`, `CLAUDE.md`, and
      `.claude/**`, and no packaged path (`R/`, `tests/`, `man/`, `vignettes/`,
      `DESCRIPTION`, `NAMESPACE`, `.github/workflows/`) matches any of them.
- [ ] AC4. The committed script reads the `paths-ignore` list out of the
      workflow file itself, replays every default-branch commit in the window
      through it, and classifies each as skipped or run. Over the window
      `[2026-07-26T00:00Z, 2026-07-27T07:00Z)` it reports 15 of 24
      default-branch commits skipped, and every one of the remaining 9 changes
      at least one packaged path. Its classification is committed as evidence.
- [ ] AC5. The same script, over the same window and counting only runs whose
      `status` is `completed`, reports the baseline recorded in this file:
      108 runs, 324 jobs, 2,276 raw machine-minutes (summed per job as
      `completed_at - started_at`); 30 runs / 628 min on skipped commits; 32
      runs / 823 min superseded, where superseded means a later run on the same
      branch and workflow was created before this run's `updated_at`, of which 9
      runs / 248 min are off the default branch. The two categories overlap and
      are reported separately, not as a partition.
- [ ] AC6. `cairn/PROFILE.md`'s `test-doctrine` CI bullet names both
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
- [ ] T2. Add the `concurrency` block to both workflows
      (`.github/workflows/R-CMD-check.yaml:2`, `test-coverage.yaml:2`), keyed on
      workflow + ref, cancelling on every ref but the default branch.
- [ ] T3. Add `paths-ignore` to the `push` and `pull_request` triggers of both
      workflows. Note `pull_request` filters on the whole PR diff, so it fires
      only for a wholly-tracking PR — the `push` trigger is where the saving is.
- [ ] T4. Extend the script to parse `paths-ignore` out of the workflow file and
      replay default-branch history through it; commit the classification.
- [ ] T5. Rewrite the `cairn/PROFILE.md:45` CI bullet for AC6, including the
      pending-check reconciliation.
- [ ] T6. Push twice in quick succession to capture the AC2 cancellation
      evidence, then run `devtools::check()` for AC7.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: started; branch `m11-ci-run-economy` cut from `main` at c248bcd.
- 2026-07-27: T1 — `.github/ci-usage.py` reproduces the AC5 baseline exactly (108 runs / 324 jobs / 2276 min; 30/628 skipped; 32/823 superseded, 9/248 off-branch) and the AC4 classification (15 of 24 commits skipped, all 9 others touching a packaged path).
- 2026-07-27: minor reorder — T1 also delivered T4's workflow-file parsing, since the script needs one ignore-list source, not two; T4 now only regenerates the committed baseline once T3 gives the workflows a real list to read.

## Decisions

## Review
