# M33: The organization's shared CI workflows, and `air` as this repo's formatter

**Status:** done (2026-08-30, PR #41 https://github.com/tidymodels/nestedtune/pull/41)

**Goal:** The three CI workflows every tidymodels package runs and nestedtune does not —
thread locking, PR commands, format suggestions — run here too, with `air` adopted as the
formatter they assume.

**Outcome:** `.github/workflows/lock.yaml`, `pr-commands.yaml` and `format-suggest.yaml`
are vendored unedited at the modal blobs of a nine-repository survey (`d55e238e` 7/9,
`2edd93f2` 9/9, `8c4f117d` 6 of 7). None declares a `push` or `pull_request` trigger, so
neither the `paths-ignore` filter nor `.github/ci-usage.py` sees them and the script's
output is byte-identical before and after. `air.toml` (`[format]`, `skip = ["tribble"]`)
and its `.Rbuildignore` entry adopt air 0.11.0; commit `d03442b` reformats 60 files under
`R/`, `tests/`, `benchmarks/` and re-points `helper-time-budget.R`'s 71-row `file:line`
ledger, the suite reporting `FAIL 0 | PASS 1628` on that commit and its parent alike.

**Decisions:** D-028 (air the formatter; the three workflows vendored unmodified); none local.

**Review:** three fresh-context reviewers, five findings. F1 (124 `file:line` citations
across `references/`, `ROADMAP.md`, `benchmarks/` and one source comment, broken by the
reformat), F2 (two stale prose references in the budget helper) and F4 (`PROFILE.md`'s
divergence count) were fixed on the branch and re-verified; F3 (the vendored `/style`
running `styler`) and F5 (moving action tags and permissions) are accepted in `DESIGN.md`
Known issues, neither editable without leaving the shared blob.
