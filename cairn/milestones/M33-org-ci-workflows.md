# M33: The organization's shared CI workflows, and `air` as this repo's formatter

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M32
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m033-org-ci-workflows`

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

- [ ] `.github/workflows/lock.yaml`, `pr-commands.yaml` and
      `format-suggest.yaml` each hash to the modal git blob of a nine-repository
      survey re-run on the implementation date (`gh api
      repos/tidymodels/<repo>/contents/.github/workflows/<file> --jq .sha` over
      rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom,
      hardhat). On 2026-08-30 those modes were `d55e238e` (7 of 9), `2edd93f2`
      (9 of 9) and `8c4f117d` (6 of the 7 that carry the file). Evidence:
      `git hash-object` per file, and the survey output with its counts.
- [ ] `.github/ci-usage.py` still runs: with the three workflows added it exits
      zero over a stated window, and the `paths_ignore.source` it reports names
      the same workflow files it named before this milestone. Evidence: the
      script's own output from before and after the additions, both quoted.
- [ ] That exit-zero is informative rather than vacuous: with a scratch
      workflow file added carrying a bare `push:` trigger and no
      `paths-ignore` block, `.github/ci-usage.py` exits non-zero naming that
      trigger; the scratch file is removed and is not committed. Evidence: the
      failing invocation's output quoted.
- [ ] `air format .` leaves the working tree unchanged over the whole
      repository. Evidence: the command run on a clean tree, followed by
      `git status --porcelain` printing nothing.
- [ ] The reformatting is separable from everything else in the branch: one
      commit performs it, `git show --stat` on that commit lists only files
      under `R/` and `tests/` plus `air.toml`, and `devtools::test()` reports
      the same PASS and FAIL counts on its parent commit and on it. Evidence:
      both test summaries and the `--stat` output.
- [ ] The profile's `verify` slot is clean and the fuller pre-review check
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
- [ ] T4: Run `devtools::test()` and record its counts; make the reformatting
      pass its own commit; run `devtools::test()` again and compare.
- [ ] T5: Add the DESIGN.md Conventions line naming `air` as the formatter and
      the `cairn/DECISIONS.md` entry adopting it; extend `PROFILE.md`'s
      `test-doctrine` slot to name the three added workflows, without
      attempting the wider records refresh the standing candidate row owns.
- [ ] T6: Run `devtools::document()`, `devtools::test()` and
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

## Decisions

## Review
