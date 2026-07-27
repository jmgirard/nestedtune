# M11: Every CI run is one somebody is waiting for

**Status:** done (2026-07-27, PR #11 https://github.com/jmgirard/nestedtune/pull/11)

**Goal:** Both GitHub Actions workflows stop running on commits that change no
packaged file, and stop finishing runs a later push has already made obsolete.

**Outcome:** Both workflows gained a `concurrency` block cancelling a superseded
run on every ref but the default branch, and a `paths-ignore` filter on both
triggers covering `cairn/**`, `CLAUDE.md`, `.claude/**` — removing 39 of 108
runs and 790 of 2,276 machine-minutes measured. `.github/ci-usage.py`
reproduces that from the Actions API, taking the filter from the workflow files
and commits from `git log` so it still measures once live;
`.github/ci-usage-baseline.md` is its output, and PROFILE.md records both.

**Decisions:** none cross-cutting. AC4/AC5 amended at a gate: the commit list
comes from `git log`, not runs (22 of 32 skipped), and AC5 pins the reclaimed
tail (442 min all superseded, 162 off-branch).

**Review:** two passes, 22 findings, 8 actioned. Pass 1 returned it — AC4 failed
because the commit set came from runs, so the tool could not measure the filter
once live; plus a false drift claim, silent glob corruption, and cancellation
credited with whole runs (877→790 min). Pass 2 fixed a deletion-blind agreement
check, `-m --first-parent`, a positional `zip` of two `git log` reads, a window claim.
