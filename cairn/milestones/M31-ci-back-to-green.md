# M31: Both red CI jobs go green, so a merge is possible again

- **Status:** planned
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** —

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

- [ ] AC1 One `R-CMD-check.yaml` workflow run on this milestone's branch
      reports `conclusion: success` for every job named by `matrix.config` in
      `.github/workflows/R-CMD-check.yaml` — verified against that file's
      matrix list beside the full `gh run view <id> --json jobs --jq '.jobs[] |
      [.name, .conclusion]'` output for that run.
- [ ] AC2 In that run's `macos-latest (release)` job, `nestedtune` installs:
      `gh run view <id> --job <macos-job-id> --log` contains no line matching
      `symbol not found in flat namespace` and no line matching
      `ERROR: package installation failed`.
- [ ] AC3 In a `ubuntu-latest (devel)` job whose `setup-r-dependencies` step
      logged `Cache not found for input keys`, the `check-r-package` step
      reports conclusion `success` — verified from that cache-miss line and the
      full step list returned by `gh api
      repos/tidymodels/nestedtune/actions/jobs/<job-id> --jq '.steps[] |
      [.number, .name, .conclusion]'`.
- [ ] AC4 A test-suite hang still fails its job within 20 minutes of the check
      starting: in `.github/workflows/R-CMD-check.yaml`, the step running
      `r-lib/actions/check-r-package@v2` declares `timeout-minutes` of at most
      20.
- [ ] AC5 The fix is confined to CI configuration and tracking: every path
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

- [ ] T1 Make the `macos-latest` leg alone obtain `gower` from source, so the
      OpenMP-linked RSPM arm64 binary is never dlopened. Scope the change to
      that leg — the other four legs' resolution path is unchanged. Verify by a
      pushed run reaching `check-r-package`. If a source install does not take,
      price the two alternatives named at the plan gate (a Homebrew libomp
      install; switching the macOS leg's repository off RSPM binaries
      wholesale) and record each attempt's run id and outcome in the work log
      before choosing.
- [ ] T2 In `.github/workflows/R-CMD-check.yaml`, raise the job-level
      `timeout-minutes` enough for a cold source build of the devel dependency
      set, and declare `timeout-minutes: 20` on the `check-r-package` step so
      M12's hang bound stays on the step the two 52- and 40-minute hangs
      occurred in. Rewrite the cap comment above `timeout-minutes` to state
      both numbers and why they differ, since it currently justifies a single
      20-minute job cap against the 394-job record.
- [ ] T3 Capture the devel cold-start evidence on the FIRST run after T2, which
      is the only one that will log `Cache not found for input keys` — once it
      completes, `R package cache save` writes the cache and later runs hit it.
      Record the completed wall-clock and the cache-save step's conclusion.
- [ ] T4 Update `cairn/PROFILE.md`'s test-doctrine slot, whose fourth
      divergence still reads as one `timeout-minutes: 20` scoped to "both
      gating workflows" — false once T2 lands. State the job cap and the step
      cap separately, and anchor the description so the M16 drift lesson
      applies: a bound copied from a call site into a record needs something
      that re-reads the call site.
- [ ] T5 Run the gates and record the evidence: `devtools::test()` and
      `devtools::check()` locally, then one full `R-CMD-check.yaml` run with all
      five legs green, plus the AC2 log greps and the AC5 diff listing.

## Work log

- 2026-08-30: created by /milestone-plan. Promoted from the ROADMAP candidate row "Get the two red CI jobs back to green", added 2026-08-30 at M28's merge gate; that row is removed and its lineage lives here.
- 2026-08-30: criteria audit ran in REDUCED mode (declared surface tier internal; no criterion or task carries an RB-tripwire tag), fresh-context [O] reader. Returned three findings, all fixed before the criteria were written: AC1 and AC4 each bound a recording instrument ("identified by run id in the Review section", "quoted in the Review section") rather than a property of the deliverable — both clauses struck; AC5 settled "confined to CI configuration" against a five-item author-recalled exclusion list (`R/`, `man/`, `tests/`, `NAMESPACE`, `DESCRIPTION`), a proxy for the domain it quantified over — inverted to an allow-list the command's own output settles.
- 2026-08-30: plan gate chose a gower-only source install on the macOS leg over switching that leg off RSPM binaries wholesale and over a Homebrew libomp install, because the maintainer's own `gower.so` links neither libomp nor anything but libR and libSystem (M30 lesson), so a source build is known to produce a loadable object, while a wider promise would be an exemption registry the internal-tier criteria standard refuses; falsified by a macOS source build of gower that still fails to dlopen, or by a second RSPM macOS binary breaking the same leg.
- 2026-08-30: plan gate chose raising the devel job cap with a 20-minute bound moved onto the `check-r-package` step over raising the job cap alone and over dropping the devel leg, because both observed hangs were inside `test_check()` and a step-level bound keeps M12's guarantee exactly where it was earned while letting the dependency install run long; falsified by a hang observed outside the check step, or by evidence that a step-level `timeout-minutes` does not fail the job on expiry.
- 2026-08-30: plan gate chose accepting the 7-day cache expiry over adding a scheduled warm-up workflow, because the cap fix alone makes a cold build complete and save, and a fifth workflow is a recurring cost and a new red surface for a case that costs one slow run after a quiet week; falsified by evidence that devel cold builds recur often enough to dominate the leg's wall-clock.

## Decisions

## Review
