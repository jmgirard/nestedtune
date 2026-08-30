# M31: Both red CI jobs go green, so a merge is possible again

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m031-ci-back-to-green` / https://github.com/tidymodels/nestedtune/pull/39

## Goal

`R-CMD-check.yaml` completes with every matrix leg green, so the never-merge-red
rule stops blocking every merge in the repo, M28 included.

## Scope

Surface tier: **internal** — the deliverable is `.github/workflows/` CI
configuration plus the `cairn/` records describing it, and no external consumer
of the R package relies on either.

**In:** Two failures, both reproducing on every run of every branch and neither
reachable by package code. (1) `macos-latest (release)` dies in `R CMD build`'s
install step because the RSPM macOS arm64 binary of `gower` — a transitive
Suggests dependency, via `recipes` — references the OpenMP symbol
`___kmpc_barrier` with no libomp on the runner. The remedy is narrow: make the
macOS leg alone obtain `gower` from source, leaving the other four legs'
resolution path untouched. (2) `ubuntu-latest (devel)` is killed by M12's
`timeout-minutes: 20` inside `setup-r-dependencies`, 108 of 129 packages in at
19m13s, mid-`Building vdiffr`; R-devel has no Linux binaries so every dependency
builds from source. It is a deadlock, not a permanent condition — the cap kills
the job before `R package cache save` runs, so the cache that would make the
next run fast (9m28s, measured 2026-08-01) can never be written. The remedy
raises the job-level cap while moving a 20-minute bound onto the
`check-r-package` step, keeping M12's hang guarantee where the hangs occurred.
Bring `cairn/PROFILE.md`'s test-doctrine slot into line with the shipped caps.

**Out:** Keeping the devel cache warm against GitHub's 7-day idle expiry, so a
quiet week stops costing a cold source build → the corrected Actions-cache
ROADMAP candidate row, which this milestone re-points at the idle-expiry
mechanism and away from its falsified 10 GB-limit premise. Refreshing
`.github/ci-usage-baseline.md`'s stale path-filter line and M11's
pre-fourth-workflow baseline numbers → stays on the "CI records" candidate row,
whose trigger is the next CI-economy audit. Reporting the `gower` binary to
Posit → the user's call, not this milestone's. Dropping or trimming any matrix
leg → M11's dropped matrix-cut candidate row.

## Acceptance criteria

- [x] AC1 One `R-CMD-check.yaml` workflow run on this milestone's branch
      reports `conclusion: success` for every job named by `matrix.config` in
      `.github/workflows/R-CMD-check.yaml` — verified against that file's
      matrix list beside the full `gh run view <id> --json jobs --jq '.jobs[] |
      [.name, .conclusion]'` output for that run.
- [x] AC2 In that run's `macos-latest (release)` job, `nestedtune` installs:
      `gh run view <id> --job <macos-job-id> --log` contains no line matching
      `symbol not found in flat namespace` and no line matching
      `ERROR: package installation failed`.
- [x] AC3 In a `ubuntu-latest (devel)` job whose `setup-r-dependencies` step
      logged `Cache not found for input keys`, the `check-r-package` step
      reports conclusion `success` — verified from that cache-miss line and the
      full step list returned by `gh api
      repos/tidymodels/nestedtune/actions/jobs/<job-id> --jq '.steps[] |
      [.number, .name, .conclusion]'`.
- [x] AC4 A test-suite hang still fails its job within 20 minutes of the check
      starting: in `.github/workflows/R-CMD-check.yaml`, the step running
      `r-lib/actions/check-r-package@v2` declares `timeout-minutes` of at most
      20.
- [x] AC5 The fix is confined to CI configuration and tracking: every path
      listed by `git diff --name-only main...HEAD` is under `.github/` or
      `cairn/`.
- [ ] AC6 `Rscript -e 'devtools::test()'` is clean (the `cairn/PROFILE.md`
      verify slot) and `Rscript -e 'devtools::check()'` reports 0 errors and 0
      warnings.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T1, T5
- AC3 → T2, T3, T5
- AC4 → T2
- AC5 → T5
- AC6 → T4, T5

## Tasks

- [x] T1 Make the `macos-latest` leg alone obtain `gower` from source, so the
      OpenMP-linked RSPM arm64 binary is never dlopened. Scope the change to
      that leg — the other four legs' resolution path is unchanged. Verify by a
      pushed run reaching `check-r-package`. If a source install does not take,
      price the two alternatives named at the plan gate (a Homebrew libomp
      install; switching the macOS leg's repository off RSPM binaries
      wholesale) and record each attempt's run id and outcome in the work log
      before choosing.
- [x] T2 In `.github/workflows/R-CMD-check.yaml`, raise the job-level
      `timeout-minutes` enough for a cold source build of the devel dependency
      set, and declare `timeout-minutes: 20` on the `check-r-package` step so
      M12's hang bound stays on the step the two 52- and 40-minute hangs
      occurred in. Rewrite the cap comment above `timeout-minutes` to state
      both numbers and why they differ, since it currently justifies a single
      20-minute job cap against the 394-job record. Discovered sub-task: two
      other workflows cross-reference that single cap in comments
      (`test-coverage.yaml`, `stress-daemon-tests.yaml`); both are corrected
      here.
- [x] T3 Capture the devel cold-start evidence on the FIRST run after T2, which
      is the only one that will log `Cache not found for input keys` — once it
      completes, `R package cache save` writes the cache and later runs hit it.
      Record the completed wall-clock and the cache-save step's conclusion.
- [x] T4 Update `cairn/PROFILE.md`'s test-doctrine slot, whose fourth
      divergence still reads as one `timeout-minutes: 20` scoped to "both
      gating workflows" — false once T2 lands. State the job cap and the step
      cap separately, and anchor the description so the M16 drift lesson
      applies: a bound copied from a call site into a record needs something
      that re-reads the call site.
- [x] T5 Run the gates and record the evidence: `devtools::test()` and
      `devtools::check()` locally, then one full `R-CMD-check.yaml` run with all
      five legs green, plus the AC2 log greps and the AC5 diff listing.

## Work log

- 2026-08-30: created by /milestone-plan. Promoted from the ROADMAP candidate row "Get the two red CI jobs back to green", added 2026-08-30 at M28's merge gate; that row is removed and its lineage lives here.
- 2026-08-30: criteria audit ran in REDUCED mode (declared surface tier internal; no criterion or task carries an RB-tripwire tag), fresh-context [O] reader. Returned three findings, all fixed before the criteria were written: AC1 and AC4 each bound a recording instrument ("identified by run id in the Review section", "quoted in the Review section") rather than a property of the deliverable — both clauses struck; AC5 settled "confined to CI configuration" against a five-item author-recalled exclusion list (`R/`, `man/`, `tests/`, `NAMESPACE`, `DESCRIPTION`), a proxy for the domain it quantified over — inverted to an allow-list the command's own output settles.
- 2026-08-30: plan gate chose a gower-only source install on the macOS leg over switching that leg off RSPM binaries wholesale and over a Homebrew libomp install, because the maintainer's own `gower.so` links neither libomp nor anything but libR and libSystem (M30 lesson), so a source build is known to produce a loadable object, while a wider promise would be an exemption registry the internal-tier criteria standard refuses; falsified by a macOS source build of gower that still fails to dlopen, or by a second RSPM macOS binary breaking the same leg.
- 2026-08-30: plan gate chose raising the devel job cap with a 20-minute bound moved onto the `check-r-package` step over raising the job cap alone and over dropping the devel leg, because both observed hangs were inside `test_check()` and a step-level bound keeps M12's guarantee exactly where it was earned while letting the dependency install run long; falsified by a hang observed outside the check step, or by evidence that a step-level `timeout-minutes` does not fail the job on expiry.
- 2026-08-30: plan gate chose accepting the 7-day cache expiry over adding a scheduled warm-up workflow, because the cap fix alone makes a cold build complete and save, and a fifth workflow is a recurring cost and a new red surface for a case that costs one slow run after a quiet week; falsified by evidence that devel cold builds recur often enough to dominate the leg's wall-clock.
- 2026-08-30: T1 edit landed — the macOS leg alone resolves `gower` through pak's `?source` parameter, so the RSPM arm64 binary is never fetched. Failure identity re-derived first-hand from job 99324307884 of run 33336519275: `dlopen` of `gower/libs/gower.so` reports `symbol not found in flat namespace '___kmpc_barrier'`, followed by `ERROR: package installation failed`, inside `check-r-package`. Question gate chose the per-package flag over whole-job source builds and over a separate pre-install step. Tick pends a pushed run.
- 2026-08-30: T2 edit landed — job cap 20 → 60, and `timeout-minutes: 20` declared on the `check-r-package` step so the hang bound stays on the step both hangs occurred in; the cap comment now states both numbers and why they differ. Cold-devel evidence re-derived from job 99321348438 of run 33335421506: `Cache not found for input keys`, `Will install 129 packages`, killed mid-`Building vdiffr` with 114 builds started, 20m05s job wall-clock, before `R package cache save` ran. Question gate chose 60 minutes over 45 and 90. Tick pends a pushed run.
- 2026-08-30: minor amendment — T2 gained a discovered sub-task. `test-coverage.yaml` said "Same cap as R-CMD-check, and for the same reason" and `stress-daemon-tests.yaml` said "far above R-CMD-check's 20"; both were true only of the single job cap T2 replaced, so both comments are rewritten to name the step cap.
- 2026-08-30: T4 done — the test-doctrine slot's fourth divergence now states the job cap and the step cap separately, for both gating workflows, and directs the reader to re-read the call sites with `grep -n timeout-minutes .github/workflows/*.yaml` before trusting the numbers, which is what the M16 drift lesson asks of a bound copied into a record. The rewrite pushed `cairn/PROFILE.md` to 121 lines against the 120 cap, so the heaviest compressible slot (greenfield-openers) was compressed in one pass; the file is 116 lines, 7,559 bytes.
- 2026-08-30: PR #39 opened as a draft. `R-CMD-check.yaml`'s `push` trigger is restricted to `main`/`master`, so `pull_request` is the only event that produces a run on a milestone branch; the draft exists to get one and review converts it.
- 2026-08-30: T1 done — run 33340129444, macOS job 99334128983 logs `Got gower 1.0.2 (source)`, `Building gower 1.0.2`, `Installed gower 1.0.2`, and the leg passed in 7m51s. Zero lines match `symbol not found in flat namespace` and zero match `ERROR: package installation failed`. The source install took, so neither alternative named at the plan gate (Homebrew libomp; switching the leg off RSPM binaries wholesale) was priced.
- 2026-08-30: T2 done — same run's devel job 99334129149 passed in 23m34s, 3m34s past the cap it used to die at. The other four legs ran 7m51s to 9m19s, under both caps.
- 2026-08-30: T3 done — devel job 99334129149 logged `Cache not found for input keys` at 22:49:37, ran 22:48:30 to 23:12:04, and its `Post Run r-lib/actions/setup-r-dependencies@v2` step reports success with `Cache saved with key: Ubuntu 24.04.4 LTS-R version 4.7.0 ...`. The deadlock is broken: the run that pays the cold build now survives to write the cache the next run reads.
- 2026-08-30: T5 done — `devtools::test()` reports `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1628 ]`; `devtools::check()` reports 0 errors, 0 warnings, 0 notes in 2m51.6s. Run 33340129444 reports `success` for all five jobs named by `matrix.config`. `git diff --name-only main...HEAD` lists six paths, all under `.github/` or `cairn/`. Status set to review.
- 2026-08-30: review checkpoint — AC1-AC5 verified with fresh evidence and ticked; consistency gate green (cairn_validate exit 0, document() no diff, check_pkgdown() clean). AC6 pending on the local suite and check(); three-lens fan-out spawned, two lenses returned.

## Decisions

## Review

Reviewed 2026-08-30 against PR #39 (draft), branch `m031-ci-back-to-green`.
`main` had not moved since the branch was cut (`origin/main` at `354f397`), so
no merge-forward was needed. Evidence below is fresh, gathered this session.

### Acceptance-criteria evidence

- AC1 — `.github/workflows/R-CMD-check.yaml` `matrix.config` names five legs
  (macos-latest release, windows-latest release, ubuntu-latest devel,
  ubuntu-latest release, ubuntu-latest oldrel-1). Run 33340129444 on this
  branch: `gh run view 33340129444 --json jobs` returns exactly those five job
  names, each `success`. Verified.
- AC2 — macOS job 99334128983 log (17,025 lines) greps to zero matches for
  `symbol not found in flat namespace` and zero for
  `ERROR: package installation failed`. The same log shows the source route
  taken: `Got gower 1.0.2 (source)`, `Building gower 1.0.2`,
  `Installed gower 1.0.2`. Verified.
- AC3 — devel job 99334129149 logged `Cache not found for input keys` and
  `Will install 129 packages`; `gh api .../actions/jobs/99334129149` reports
  step 6, `Run r-lib/actions/check-r-package@v2`, conclusion `success`, and the
  post step logged `Cache saved with key: ... R version 4.7.0 ...`. The
  cold-build deadlock is broken. Verified.
- AC4 — `.github/workflows/R-CMD-check.yaml:107-108`: the step
  `uses: r-lib/actions/check-r-package@v2` declares `timeout-minutes: 20`.
  Verified.
- AC5 — `git diff --name-only main...HEAD` lists six paths: three under
  `.github/workflows/`, three under `cairn/`. Nothing outside those two trees.
  Verified.
- AC6 — pending.

### Consistency gate

- `cairn_validate.py` exit 0: all 16 checks PASS, 5 advisories OK, one WARN
  (`references staleness`, 18 pages) unchanged from the last hygiene stamp and
  untouched by this milestone. `release window` OK.
- `cairn_impact.py` skipped: `cairn/DESIGN.md` is not in the diff, so no
  principle changed.
- Toolchain slot (`cairn/PROFILE.md` consistency-gate): `devtools::document()`
  exits 0 with an empty `git status` (no diff); `pkgdown::check_pkgdown()`
  reports no problems; no `README.Rmd` exists, so the knit check is
  inapplicable; `NEWS.md` needs no entry (CI configuration and tracking only,
  nothing a package user can observe); no new top-level files, so no
  `.Rbuildignore` entry is due.

### Independent review

Routing: declared surface tier is internal, but the diff touches GitHub Actions
workflow YAML, which is executable surface — so the full three-lens fan-out ran
rather than the single-reviewer path.

