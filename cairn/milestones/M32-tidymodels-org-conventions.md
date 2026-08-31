# M32: The community files and site template the tidymodels organization shares

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m032-tidymodels-org-conventions`

## Goal

A contributor arriving at `tidymodels/nestedtune` finds the same contributing
guide, code of conduct and documentation site the organization's other packages
carry.

## Scope

**Surface tier: user-facing.** The two community files publish as pages on
`nestedtune.tidymodels.org` and are what an outside contributor reads before
filing anything; the template is what every site visitor sees.

**In:** vendor `.github/CONTRIBUTING.md` and `.github/CODE_OF_CONDUCT.md` from
the organization's shared texts, identified by a stated nine-repository survey
rather than by picking one sibling. Switch `_pkgdown.yml` to
`template: package: tidytemplate` with the siblings' bootstrap and `bslib`
colours, declaring the new builder dependency in `DESCRIPTION`'s
`Config/Needs/website` and nowhere else (D-022; the M17 lesson on
`extra-packages` making that field decorative). Add a lifecycle badge to the
README, which is the badge that carries information here — D-003 waives the
deprecation cycle pre-1.0 and nothing on the front page says so.

**Out:** every change to `Authors@R` or `LICENSE` → a candidate row, pending an
answer from the tidymodels maintainers (the user's gate answer: ask Posit
first). The siblings' `supported-by-posit` `in_header` badge script → the same
row, being Posit branding on the same unsettled question. `README.Rmd`
conversion, and CRAN/downloads badges → a candidate row; there is no release,
so those badges would state something untrue. `.github/CODEOWNERS` → the same
row, needing organization understudies this repo has not been assigned. Every
CI workflow change → M33.

## Acceptance criteria

- [ ] `.github/CODE_OF_CONDUCT.md` hashes to git blob
      `3ac34c82d671818e069f8dbc88a0b2913a952699`, the single text carried by
      all nine repositories the survey reaches (`gh api
      repos/tidymodels/<repo>/contents/.github/CODE_OF_CONDUCT.md --jq .sha`
      over rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom,
      hardhat). Evidence: `git hash-object` on the committed file, and the
      survey re-run on the implementation date with its nine shas recorded.
- [ ] `.github/CONTRIBUTING.md` hashes to git blob
      `23b135bd64f3f4877de79f21e61350a4609ba183`, the modal text of that same
      nine-repository survey (3 of 9 on 2026-08-30; runner-up `34272f04`, 2 of
      9, differing in one line about branch creation). Evidence: as above. If
      the re-run moves the mode, the milestone takes the new mode and records
      the shift.
- [ ] Both files publish and no repo-internal page joins them: after a local
      `pkgdown::build_site()`, `docs/CONTRIBUTING.html` and
      `docs/CODE_OF_CONDUCT.html` exist, and `.github/workflows/pkgdown.yaml`'s
      absent-page assertion — the loop over `docs/CLAUDE.html` and
      `docs/ci-usage-baseline.html` — run against that same build exits zero.
- [ ] `_pkgdown.yml` declares `template: package: tidytemplate` with
      `bootstrap: 5` and `bslib` `primary`/`danger` at `#CA225E`, and
      `DESCRIPTION`'s `Config/Needs/website` names `tidyverse/tidytemplate`
      beside `pkgdown`. Evidence: `pkgdown::build_site()` completes — pkgdown
      raises when `template: package:` names a package it cannot load, so
      completion is what shows the template resolved — and
      `pkgdown::check_pkgdown()` reports no problems.
- [ ] The new builder dependency stays legible from `DESCRIPTION` alone:
      `.github/workflows/pkgdown.yaml`'s `setup-r-dependencies` step names
      `local::.` and no `any::` package, so a wrong or absent
      `Config/Needs/website` field fails the deploy rather than being papered
      over. Evidence: `grep -n -A3 'extra-packages' .github/workflows/pkgdown.yaml`.
- [ ] `README.md`'s `<!-- badges: start -->` block gains a lifecycle badge
      reading `experimental` and linking
      `https://lifecycle.r-lib.org/articles/stages.html`, and gains no CRAN or
      downloads badge. Evidence: the badge block quoted whole in the review
      section, which is the domain the claim quantifies over.
- [ ] The profile's `verify` slot is clean and the fuller pre-review check
      passes: `devtools::test()` clean, `devtools::document()` no diff,
      `devtools::check()` clean (0 errors, 0 warnings; NOTEs justified).

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T1, T4
- AC4 → T2, T3, T4
- AC5 → T2, T4
- AC6 → T5
- AC7 → T7

## Tasks

- [x] T1: Re-run the nine-repository survey for both community files, record
      the shas and the date in the work log, and vendor the modal texts to
      `.github/CONTRIBUTING.md` and `.github/CODE_OF_CONDUCT.md`.
- [ ] T2: Switch `_pkgdown.yml`'s `template:` block to
      `package: tidytemplate` with `bootstrap: 5` and the `bslib` colours,
      leaving `.github/workflows/pkgdown.yaml` untouched.
- [ ] T3: Add `tidyverse/tidytemplate` to `Config/Needs/website` in
      `DESCRIPTION`; install it locally the way the workflow's
      `setup-r-dependencies` step will (`pak::pak("tidyverse/tidytemplate")`).
- [ ] T4: Build the site locally, confirm the two new pages exist, and run the
      pkgdown workflow's absent-page loop and `pkgdown::check_pkgdown()`
      against that build.
- [ ] T5: Add the lifecycle badge to `README.md`.
- [ ] T6: Append the D-entry extending D-022 with `tidyverse/tidytemplate` and
      recording the template switch; add the `NEWS.md` bullet for the site's
      changed appearance.
- [ ] T7: Run `devtools::document()`, `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-08-30: created by /milestone-plan.
- 2026-08-30: plan-gate criteria audit ran in **full** mode (declared surface tier user-facing), in-session rather than by a fresh-context [O] reader, under the harness instruction restricting subagent spawns. Three findings, all fixed before the criteria above were written. (1) A draft AC4 cited "the built `docs/index.html` links the tidytemplate stylesheet" as evidence — an asset filename not established by anything read at plan time; narrowed to the build completing, which already proves resolution. (2) A draft AC3 promised "no repo-internal page joins them", a universal whose only named procedure is a hardcoded two-name assertion that cannot enumerate that domain (bounded-promise rule); narrowed to what the assertion actually sweeps. (3) A draft criterion required a D-entry in `cairn/DECISIONS.md` — a recording act, an instrument property rather than a property of the deliverable (D-118, D-120); moved to T6.
- 2026-08-30: plan gate chose vendoring the community files at a surveyed modal blob sha over copying one named sibling, because the files are not uniform across the organization — CONTRIBUTING has five distinct texts across nine repositories while CODE_OF_CONDUCT has one — so naming a sibling would pick a minority text by accident; falsified by a survey re-run in which no text holds a plurality, which would mean there is no shared convention to adopt.
- 2026-08-30: plan gate chose declaring `tidytemplate` in `Config/Needs/website` over naming it in the pkgdown workflow's `extra-packages`, because D-022 rejected that route for `pkgdown` itself and the M17 lesson records why — the action installs it either way, so the DESCRIPTION field becomes decorative and a criterion asserting the declaration cannot fail; falsified by evidence that `setup-r-dependencies` does not resolve a GitHub-style `owner/repo` entry from that field.

- 2026-08-30: T1 — survey re-run over the nine repositories. CODE_OF_CONDUCT `3ac34c82` on all nine (rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom, hardhat). CONTRIBUTING mode `23b135bd` at 3 of 9 (rsample, parsnip, recipes), runner-up `34272f04` at 2 of 9 (workflows, hardhat), then `a8bc0ffd` (tune), `a92ca611` (yardstick), `665fb3cf` (dials), `525e9d0d` (broom); mode unmoved. Both texts vendored from their blobs and `git hash-object` returns the two target shas.

## Decisions

## Review
