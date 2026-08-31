# M32: The community files and site template the tidymodels organization shares

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m032-tidymodels-org-conventions` — https://github.com/tidymodels/nestedtune/pull/40

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

- [x] `.github/CODE_OF_CONDUCT.md` hashes to git blob
      `3ac34c82d671818e069f8dbc88a0b2913a952699`, the single text carried by
      all nine repositories the survey reaches (`gh api
      repos/tidymodels/<repo>/contents/.github/CODE_OF_CONDUCT.md --jq .sha`
      over rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom,
      hardhat). Evidence: `git hash-object` on the committed file, and the
      survey re-run on the implementation date with its nine shas recorded.
- [x] `.github/CONTRIBUTING.md` hashes to git blob
      `23b135bd64f3f4877de79f21e61350a4609ba183`, the modal text of that same
      nine-repository survey (3 of 9 on 2026-08-30; runner-up `34272f04`, 2 of
      9, differing in one line about branch creation). Evidence: as above. If
      the re-run moves the mode, the milestone takes the new mode and records
      the shift.
- [x] Both files publish and no repo-internal page joins them: after a local
      `pkgdown::build_site()`, `docs/CONTRIBUTING.html` and
      `docs/CODE_OF_CONDUCT.html` exist, and `.github/workflows/pkgdown.yaml`'s
      absent-page assertion — the loop over `docs/CLAUDE.html` and
      `docs/ci-usage-baseline.html` — run against that same build exits zero.
- [x] `_pkgdown.yml` declares `template: package: tidytemplate` with
      `bootstrap: 5` and `bslib` `primary`/`danger` at `#CA225E`, and
      `DESCRIPTION`'s `Config/Needs/website` names `tidyverse/tidytemplate`
      beside `pkgdown`. Evidence: `pkgdown::build_site()` completes — pkgdown
      raises when `template: package:` names a package it cannot load, so
      completion is what shows the template resolved — and
      `pkgdown::check_pkgdown()` reports no problems.
- [x] The new builder dependency stays legible from `DESCRIPTION` alone:
      `.github/workflows/pkgdown.yaml`'s `setup-r-dependencies` step names
      `local::.` and no `any::` package, so a wrong or absent
      `Config/Needs/website` field fails the deploy rather than being papered
      over. Evidence: `grep -n -A3 'extra-packages' .github/workflows/pkgdown.yaml`.
- [x] `README.md`'s `<!-- badges: start -->` block gains a lifecycle badge
      reading `experimental` and linking
      `https://lifecycle.r-lib.org/articles/stages.html`, and gains no CRAN or
      downloads badge. Evidence: the badge block quoted whole in the review
      section, which is the domain the claim quantifies over.
- [x] The profile's `verify` slot is clean and the fuller pre-review check
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
- [x] T2: Switch `_pkgdown.yml`'s `template:` block to
      `package: tidytemplate` with `bootstrap: 5` and the `bslib` colours,
      leaving `.github/workflows/pkgdown.yaml` untouched.
- [x] T3: Add `tidyverse/tidytemplate` to `Config/Needs/website` in
      `DESCRIPTION`; install it locally the way the workflow's
      `setup-r-dependencies` step will (`pak::pak("tidyverse/tidytemplate")`).
- [x] T4: Build the site locally, confirm the two new pages exist, and run the
      pkgdown workflow's absent-page loop and `pkgdown::check_pkgdown()`
      against that build.
- [x] T5: Add the lifecycle badge to `README.md`.
- [x] T6: Append the D-entry extending D-022 with `tidyverse/tidytemplate` and
      recording the template switch; add the `NEWS.md` bullet for the site's
      changed appearance.
- [x] T7: Run `devtools::document()`, `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-08-30: created by /milestone-plan.
- 2026-08-30: plan-gate criteria audit ran in **full** mode (declared surface tier user-facing), in-session rather than by a fresh-context [O] reader, under the harness instruction restricting subagent spawns. Three findings, all fixed before the criteria above were written. (1) A draft AC4 cited "the built `docs/index.html` links the tidytemplate stylesheet" as evidence — an asset filename not established by anything read at plan time; narrowed to the build completing, which already proves resolution. (2) A draft AC3 promised "no repo-internal page joins them", a universal whose only named procedure is a hardcoded two-name assertion that cannot enumerate that domain (bounded-promise rule); narrowed to what the assertion actually sweeps. (3) A draft criterion required a D-entry in `cairn/DECISIONS.md` — a recording act, an instrument property rather than a property of the deliverable (D-118, D-120); moved to T6.
- 2026-08-30: plan gate chose vendoring the community files at a surveyed modal blob sha over copying one named sibling, because the files are not uniform across the organization — CONTRIBUTING has five distinct texts across nine repositories while CODE_OF_CONDUCT has one — so naming a sibling would pick a minority text by accident; falsified by a survey re-run in which no text holds a plurality, which would mean there is no shared convention to adopt.
- 2026-08-30: plan gate chose declaring `tidytemplate` in `Config/Needs/website` over naming it in the pkgdown workflow's `extra-packages`, because D-022 rejected that route for `pkgdown` itself and the M17 lesson records why — the action installs it either way, so the DESCRIPTION field becomes decorative and a criterion asserting the declaration cannot fail; falsified by evidence that `setup-r-dependencies` does not resolve a GitHub-style `owner/repo` entry from that field.

- 2026-08-30: T1 — survey re-run over the nine repositories. CODE_OF_CONDUCT `3ac34c82` on all nine (rsample, tune, workflows, yardstick, parsnip, recipes, dials, broom, hardhat). CONTRIBUTING mode `23b135bd` at 3 of 9 (rsample, parsnip, recipes), runner-up `34272f04` at 2 of 9 (workflows, hardhat), then `a8bc0ffd` (tune), `a92ca611` (yardstick), `665fb3cf` (dials), `525e9d0d` (broom); mode unmoved. Both texts vendored from their blobs and `git hash-object` returns the two target shas.

- 2026-08-30: T2 — `_pkgdown.yml`'s `template:` block now names `package: tidytemplate` alongside `bootstrap: 5` and `bslib` `primary`/`danger` at `#CA225E`, the block rsample and tune carry (parsnip, recipes and yardstick carry the same without `danger`). `.github/workflows/pkgdown.yaml` untouched.

- 2026-08-30: T3 — `Config/Needs/website` reads `pkgdown, tidyverse/tidytemplate`, the route chosen at the question gate. Installed locally the way the workflow's `setup-r-dependencies` step resolves it: `pak::pak("tidyverse/tidytemplate")` fetched and built tidytemplate 1.0.0 at GitHub `f7bdedf`.

- 2026-08-30: T4 — local `pkgdown::build_site(new_process = FALSE, install = FALSE)` completed after installing the package and tidytemplate, mirroring the workflow by moving `CLAUDE.md` and `.github/ci-usage-baseline.md` aside for the build and back afterwards. `docs/CODE_OF_CONDUCT.html` and `docs/CONTRIBUTING.html` both written; the workflow's absent-page loop over `docs/CLAUDE.html` and `docs/ci-usage-baseline.html` exits 0 against that build, and `docs/index.html` and `docs/articles/nested-cv.html` are present. `pkgdown::check_pkgdown()` reports no problems.

- 2026-08-30: T5 — README's badge block gains the lifecycle badge first, in tune's exact markup (shields.io `lifecycle-experimental-orange`, linking `https://lifecycle.r-lib.org/articles/stages.html` with no fragment). No CRAN or downloads badge added.

- 2026-08-30: T6 — D-027 records the template switch and the `tidyverse/tidytemplate` declaration, extending D-022; NEWS gains one bullet for the site's new look, its two community pages and the README's experimental badge.

- 2026-08-30: T7 — `devtools::document()` leaves no diff; `devtools::test()` reports FAIL 0 | WARN 0 | SKIP 0 | PASS 1628; `devtools::check()` returns `Status: OK` (0 errors, 0 warnings, 0 notes).

- 2026-08-30: all seven tasks done, profile verify and the fuller check clean; status → review.

- 2026-08-30: review — all seven criteria verified with fresh evidence; consistency gate clean (cairn_validate exit 0, no DESIGN principle changed, `document()` no diff, `check()` Status: OK, `check_pkgdown()` clean). Three-lens fan-out returned five findings: one actioned as a follow-up into the standing conventions candidate row, one fixed at the gate at the maintainer's direction (the NEWS bullet's forward-looking and appearance claims), three rejected with reasons; no return-floor trigger.

## Decisions

## Review

Fresh evidence, 2026-08-30, on branch `m032-tidymodels-org-conventions` at PR #40.

- **AC1 — pass.** `git hash-object .github/CODE_OF_CONDUCT.md` returns
  `3ac34c82d671818e069f8dbc88a0b2913a952699`. Survey re-run the same day over
  the nine repositories returns that same sha for all nine: rsample, tune,
  workflows, yardstick, parsnip, recipes, dials, broom, hardhat.
- **AC2 — pass.** `git hash-object .github/CONTRIBUTING.md` returns
  `23b135bd64f3f4877de79f21e61350a4609ba183`. The same survey re-run puts that
  text at 3 of 9 (rsample, parsnip, recipes), runner-up `34272f04` at 2 of 9
  (workflows, hardhat), then `a8bc0ffd` (tune), `a92ca611` (yardstick),
  `665fb3cf` (dials), `525e9d0d` (broom). The mode has not moved, so no shift
  to record.
- **AC3 — pass.** A fresh local `pkgdown::build_site(new_process = FALSE,
  install = FALSE)`, run with `CLAUDE.md` and `.github/ci-usage-baseline.md`
  moved aside as the workflow's drop step does, wrote `docs/CONTRIBUTING.html`
  and `docs/CODE_OF_CONDUCT.html`. The workflow's absent-page loop over
  `docs/CLAUDE.html` and `docs/ci-usage-baseline.html`, run verbatim against
  that build, exits 0.
- **AC4 — pass.** `_pkgdown.yml`'s `template:` block reads `package:
  tidytemplate`, `bootstrap: 5`, `bslib` `primary` and `danger` both
  `"#CA225E"`; `DESCRIPTION` line 40 reads `Config/Needs/website: pkgdown,
  tidyverse/tidytemplate`. The build above completed, which is what shows the
  template resolved, and `pkgdown::check_pkgdown()` reported `No problems
  found.`
- **AC5 — pass.** `grep -n -A3 'extra-packages' .github/workflows/pkgdown.yaml`
  returns one hit, line 88: `extra-packages: local::.` followed by `needs:
  website`. No `any::` package is named.
- **AC6 — pass.** The badge block, quoted whole:

  ```
  <!-- badges: start -->
  [![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html)
  [![R-CMD-check](https://github.com/tidymodels/nestedtune/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/tidymodels/nestedtune/actions/workflows/R-CMD-check.yaml)
  [![Codecov test coverage](https://codecov.io/gh/tidymodels/nestedtune/graph/badge.svg)](https://app.codecov.io/gh/tidymodels/nestedtune)
  <!-- badges: end -->
  ```

  The lifecycle badge reads `experimental` and links
  `https://lifecycle.r-lib.org/articles/stages.html`; no CRAN or downloads
  badge is present.
- **AC7 — pass.** `devtools::document()` exits 0 and leaves `NAMESPACE`, `man/`
  and `DESCRIPTION` unmodified in `git status`. `devtools::test()` reports
  `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1628 ]`. `devtools::check(document =
  TRUE)` ends `Status: OK` — 0 errors, 0 warnings, 0 notes, so no NOTE needs
  justifying.

### Consistency gate

- `cairn_validate.py` exits 0: all 16 checks PASS, 5 advisories OK, one WARN
  (18 references pages record no verification claim, unchanged from the last
  hygiene stamp). Not a gate failure.
- No `DESIGN.md` principle changed in this diff, so `cairn_impact.py --changed`
  does not apply.
- Toolchain checks, from the `r-package` profile's `consistency-gate` slot:
  `devtools::document()` produces no diff; `devtools::check()` `Status: OK`;
  `pkgdown::check_pkgdown()` clean;
  no `README.Rmd` exists, so the knit check does not apply; `NEWS.md` carries
  an entry for the site's new look, its two community pages and the README
  badge, naming no milestone number; the two new top-level-ish files live under
  `.github/`, already covered by the `^\.github$` `.Rbuildignore` entry.

### Findings

Three fresh-context reviewers, no shared evidence base: an [O] diff-bug lens on
`git diff origin/main..HEAD` against the criteria, DESIGN and DECISIONS; an [S]
blame-history lens on `git log`/`git blame` of the modified lines; an [S]
prior-review-record lens on the archived `## Review` sections touching these
files, plus a probe of the repo's GitHub review threads.

Blame-history reported no findings: the `_pkgdown.yml` and `DESCRIPTION` edits
are additive on top of what M17 put there, `pkgdown.yaml` is untouched, and
D-027 extends D-022 on D-022's own reasoning rather than contradicting it.

Ranked findings and disposition:

- **F1 (diff-bug, most severe).** `.github/CODE_OF_CONDUCT.md` line 121 carries
  a broken reference-style Markdown link — `[Mozilla's code of conduct
  enforcement ladder][https://github.com/mozilla/inclusion]` has a URL where a
  label belongs and no matching definition, so it renders as literal bracketed
  text on the published page. **Rejected.** The defect is inside the
  hash-pinned upstream blob AC1 exists to reproduce byte for byte; repairing it
  locally would falsify AC1 and fork the text the whole milestone set out to
  share. It is an upstream problem, not this diff's.
- **F2 (prior-review-record).** The `NEWS.md` bullet says the site "is now
  built with" the shared theme, the shape M17's review flagged when a NEWS
  claim outran what was true at merge. **Fixed at the gate,** at the
  maintainer's direction. The bullet had also carried "so it looks like the
  rest of the ecosystem's sites", an appearance claim about the published site
  that nothing here measures. It now reads "The documentation site now builds
  with the tidymodels organization's shared pkgdown theme, and the
  organization's contributing guide and code of conduct have joined the
  repository and build as pages of the site." — every clause a property of the
  build this review ran, true at merge rather than at deploy.
- **F3 (diff-bug).** All nine surveyed siblings also carry a Plausible
  analytics `in_header` block, which no criterion, scope line or D-entry in
  this milestone rules on. **Follow-up.** Absorbed into the standing "tidymodels
  conventions M32 and M33 deliberately leave behind" candidate row, which
  already holds the other `in_header` item; omitting analytics stays the
  conservative default until it is decided.
- **F4 (diff-bug).** The published CONTRIBUTING gives organization-generic
  advice (`usethis::pr_init()`, add a NEWS bullet) while this repo's actual
  process lives in `CLAUDE.md`, which the site build strips. **Rejected.** An
  intentional consequence of the vendor-verbatim route the plan chose, and the
  text is what AC2 pins.
- **F5 (diff-bug, least severe).** `_pkgdown.yml` orders `package` before
  `bootstrap` and `primary` before `danger`; rsample and tune use the reverse.
  **Rejected.** A pure style nitpick with no behavioural effect.

No finding demonstrates an acceptance criterion failing, and none is a
load-bearing defect in what the package does for its users, so the return floor
does not fire.
