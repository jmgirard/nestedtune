# M30: Every address the package shows names its new home

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m030-address-rename`

## Goal

Every address the package shows the outside world names
`tidymodels/nestedtune` and the documentation site it actually publishes to, so
nothing a user, CRAN, or the check farm reads points at the old owner or
survives only on a GitHub redirect.

## Scope

Surface tier: **user-facing** — `DESCRIPTION`, `README.md`, the generated
`man/` page and the published pkgdown site are all read by people outside this
repo.

**In:** The stale-address half of the organization-housekeeping candidate row.
`DESCRIPTION`'s `URL:` and `BugReports:`; `_pkgdown.yml`'s `url:`; the README's
two badges, their link targets, the `pak::pak()` installation line and the guide
link; the unposted upstream draft `benchmarks/rsample-283-comment.md`; the title
line of `.github/ci-usage-baseline.md`; a `NEWS.md` entry for the move, plus a
reword of its one sentence naming the old site address. `man/` is regenerated
from `DESCRIPTION` by roxygen, never hand-edited. The documentation address is
`https://nestedtune.tidymodels.org/`, chosen at the plan gate; the milestone is
not done until that address and the badge targets actually resolve.

**Out:** The organization-convention half — a contributing guide, a code of
conduct, the shared pkgdown template, and whatever CI idiom the org expects →
stays on the candidate row, which this milestone does not graduate. Anything
about the `gh-pages` content already published under the old address, or
site hygiene beyond the `url:` field → its own milestone, planned from whatever
T8 finds. Any release or submission → release timing is user-declared and
nothing here proposes one. `cairn/` is not rewritten.

## Acceptance criteria

- [ ] AC1: `grep -rIn 'jmgirard' . --exclude-dir=.git --exclude-dir=cairn
      --exclude-dir=docs`, run from the repository root, returns no matches.
      `cairn/` is excluded because its decision entries, work logs and archives
      are history the tracking rulebook supersedes rather than edits, and its
      current-knowledge files name the old address only inside dated records of
      it; `docs/` is excluded as a gitignored local build artifact.
- [ ] AC2: `DESCRIPTION`'s `URL:` field names
      `https://github.com/tidymodels/nestedtune` and
      `https://nestedtune.tidymodels.org/`, its `BugReports:` field names
      `https://github.com/tidymodels/nestedtune/issues`, and
      `man/nestedtune-package.Rd` lists those same three addresses.
- [ ] AC3: `_pkgdown.yml`'s `url:` value is the URL token
      `https://nestedtune.tidymodels.org/`, byte-identical to the documentation
      entry in `DESCRIPTION`'s `URL:` field.
- [ ] AC4: `urlchecker::url_check()` over the package root reports no
      unreachable URL, and a fetch of `https://nestedtune.tidymodels.org/`, the
      R-CMD-check badge target and the codecov badge target each returns an HTTP
      status below 400.
- [ ] AC5: `NEWS.md` carries an entry stating that the package's home moved to
      the tidymodels organization and naming the new documentation address, and
      its existing sentence describing where `DESCRIPTION` and the README have
      pointed no longer names a specific address.

## Coverage

- AC1 → T2, T3, T4, T5, T6, T7, T9
- AC2 → T2, T7
- AC3 → T3
- AC4 → T1, T8, T9
- AC5 → T6

## Tasks

- [x] T1: Install the R dependencies this machine lacks — `tune`, `rsample`,
      `parsnip`, `workflows`, `mirai`, `ranger`, `recipes`, `yardstick`,
      `lobstr`, `mlbench`, `vdiffr`, `R6`, `knitr`, `rmarkdown`, `urlchecker` —
      so `devtools::document()`, `devtools::check()` and `url_check()` can run
      at all; record the versions installed.
- [x] T2: Update `DESCRIPTION`'s `URL:` and `BugReports:`.
- [x] T3: Update `_pkgdown.yml`'s `url:`.
- [x] T4: Update `README.md` — the R-CMD-check badge and its link, the codecov
      badge and its link, the `pak::pak()` installation line, and the guide link.
- [x] T5: Update `benchmarks/rsample-283-comment.md` and the title line of
      `.github/ci-usage-baseline.md`.
- [x] T6: Add the `NEWS.md` entry for the move, and reword the existing sentence
      so it refers to the site without naming an address.
- [x] T7: Run `devtools::document()` so `man/nestedtune-package.Rd` regenerates
      from the new `DESCRIPTION`; never hand-edit it.
- [x] T8: Get the site actually served at `https://nestedtune.tidymodels.org/`
      (a DNS record plus the repository's Pages custom-domain setting) and the
      codecov project re-linked under the new owner. Both need access this
      session does not have; if the user cannot obtain it, move the milestone to
      `blocked` and name which of the two is missing.
- [ ] T9: Re-run the AC1 sweep, `urlchecker::url_check()`, and the three
      address fetches; record every output.

## Work log

- 2026-08-28: created by /milestone-plan, absorbing the address half of the organization-housekeeping candidate row added earlier the same day; the row keeps its convention half and is not graduated here.
- 2026-08-28: criteria audit ([O], fresh context, full mode — user-facing tier) returned five findings. Three fixed directly: AC1 required its own grep be "stated verbatim in the milestone file", binding a record-keeping act rather than the deliverable (moved to the evidence line); AC1's coverage map reached 13 of the 14 sweep matches, missing `NEWS.md:143` entirely, so the criterion could not have been met by its tasks (folded into T6); AC2 promised the generated `man/` page had been produced *by* `document()` and that a second run was clean, the first binding provenance and the second duplicating the standing consistency gate (narrowed to the file's content).
- 2026-08-28: the audit also corrected two claims the plan had made — the sweep returns 14 matches, not 13, and IP4 in this repo is a statistical principle about the estimate describing the design executed, not a history rule, so the `cairn/` exclusion was re-justified against the tracking rulebook and against the fact that `ROADMAP.md` is current-knowledge and holds a stale address of its own.
- 2026-08-28: the audit's fourth finding was that AC4 as drafted was vacuous — "no check output naming a URL" is satisfied by a run in which the URL check never happened, since `R CMD check` fetches URLs only under `--as-cran` with a network and the CI action's `error-on: "new"` does not fail on NOTEs. Repaired to positive evidence via `urlchecker::url_check()` plus recorded fetches. This repo has already shipped the failure that finding describes: the advertised site 404'd with no `gh-pages` branch at all.
- 2026-08-28: plan gate settled three questions. The documentation address is `https://nestedtune.tidymodels.org/` over `https://tidymodels.github.io/nestedtune/`, because the org convention is what sibling packages use and the alternative would be replaced later at the cost of a second rename; falsified by the custom domain proving unobtainable, which sends the choice back. The changelog sentence is reworded to drop its address rather than having the new address substituted in, because substitution would make a user-facing sentence assert something that never happened; falsified by a reader needing the historical address to follow the entry. And the milestone must see the addresses resolve rather than stopping at the file edits, accepting that it may sit `blocked` on access this session does not have; falsified if the DNS and codecov setup turns out to belong to a different owner entirely, which would move T8 out of scope.
- 2026-08-28: implement gate asked one question, the rest of the plan's choices being settled. The coverage badge under the new owner renders `unknown` — `codecov.io/gh/tidymodels/nestedtune/graph/badge.svg` answers 200 with the word `unknown`, while the old slug still renders `98%`, so no report has been uploaded under the new name. User selected repointing the badge now and letting the first default-branch coverage run after merge fill the number in, over holding the milestone until the service is confirmed connected or dropping the badge. AC4 is unamended: it asks for an HTTP status below 400, which both the badge image and its link target already return.
- 2026-08-28: T1 needed no installation — every package the task lists is already present under R 4.6.1: tune 2.1.0, rsample 1.3.2, parsnip 1.6.0, workflows 1.3.0, mirai 2.7.2, ranger 0.18.0, recipes 1.4.0, yardstick 1.4.0, lobstr 1.2.1, mlbench 2.1.11, vdiffr 1.0.9, R6 2.6.1, knitr 1.51, rmarkdown 2.31, urlchecker 2.0.0. The ROADMAP hygiene stamp recording five of them as absent from this library is stale.

- 2026-08-28: T2 — `DESCRIPTION`'s `URL:` now lists `https://github.com/tidymodels/nestedtune` and `https://nestedtune.tidymodels.org/`, `BugReports:` `https://github.com/tidymodels/nestedtune/issues`. Field order kept as it was; the four sibling packages read for a convention split two-two on whether the site or the repository comes first, so there is none to follow.

- 2026-08-28: T3 — `_pkgdown.yml`'s `url:` is `https://nestedtune.tidymodels.org/`, the same token `DESCRIPTION` carries. The edit was made alongside T2's and so landed in T2's commit rather than its own.

- 2026-08-28: T4 — README's two badges, both link targets, the `pak::pak()` line and the `[guide]` link definition now name `tidymodels/nestedtune` and `https://nestedtune.tidymodels.org/`. There is no `README.Rmd` in this repo, so `README.md` is the source and no knit step applies.

- 2026-08-28: T5 — the unposted rsample#283 draft's one link and `.github/ci-usage-baseline.md`'s title line both name `tidymodels/nestedtune`. The baseline's measurements are unchanged; only the repository it names moved.

- 2026-08-28: T6 — `NEWS.md` gains a first entry for the move, naming both new addresses and recording what was checked of the old ones: `https://github.com/jmgirard/nestedtune` answers 301 to the new repository, `https://jmgirard.github.io/nestedtune/` answers 404. The earlier entry's sentence now reads "`DESCRIPTION` and the README have pointed at the site since the guide was added", naming no address.

- 2026-08-28: T7 — `devtools::document()` rewrote `man/nestedtune-package.Rd`'s three Useful-links entries to the new addresses. It also emitted two changes the milestone did not ask for; kept, and recorded in this file's Decisions section. `devtools::test()` after regeneration: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1628 ]`.

- 2026-08-28: T8 — the site half was already done and needed no access. `gh api repos/tidymodels/nestedtune/pages` reports `status: built`, `cname: nestedtune.tidymodels.org`, source branch `gh-pages`, `https_enforced: true` with an approved certificate to 2026-11-26; `gh-pages` carries a `CNAME` file reading `nestedtune.tidymodels.org`; `dig` resolves the host to `tidymodels.github.io` and the Pages addresses; and the served page's title is `Nested Cross-Validation for Tidymodels • nestedtune`. The deploy action runs with `clean: false`, so it does not remove that `CNAME`. The coverage half is not done and is left so by the gate decision above: the badge under the new name renders `unknown`. A `CODECOV_TOKEN` repository secret dated 2026-07-27 survived the transfer, but whether it still authorizes uploads under the new owner is not established here. `test-coverage.yaml` sets `fail_ci_if_error` true off pull requests, so a token that no longer works turns that workflow red on the next default-branch run rather than failing quietly.

## Decisions

### Regenerating `man/` also carried roxygen2 8.1.0's own output changes

`devtools::document()` on this machine runs roxygen2 8.1.0 against the
`RoxygenNote: 8.0.0` the last documenting milestone recorded. Beside the three
addresses T7 exists to update, it made two changes M30 did not ask for:
`RoxygenNote: 8.0.0` in `DESCRIPTION` became `Config/roxygen2/version: 8.1.0`,
and `NAMESPACE`'s two `importFrom(tune, ...)` lines became one multi-argument
call spread over three lines. Both are kept rather than reverted. Reverting
them would make the review consistency check — `document()` produces no diff —
fail, since the same roxygen would rewrite them again on the next run; the only
other route is downgrading an installed development tool to protect a diff.
The suite after the regeneration is `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1628 ]`.

## Review
