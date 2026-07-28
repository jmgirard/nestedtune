# M17: The advertised documentation site exists

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m17-pkgdown-site-deploy`

## Goal

The pkgdown URL `DESCRIPTION` and `README` already advertise resolves to a built
site, rebuilt from the default branch whenever the package changes.

## Scope

**In:** A `.github/workflows/pkgdown.yaml` that builds the site from the
`_pkgdown.yml` already committed and publishes it to a `gh-pages` branch from the
default branch only; `Config/Needs/website: pkgdown` in `DESCRIPTION` so
`setup-r-dependencies` installs the builder from a declaration; `docs/` in
`.gitignore`; keeping the two repo-internal markdown files pkgdown renders today
off the published site; and a handoff line naming the repository setting the
maintainer must enable.

**Out:** Enabling GitHub Pages in the repository settings — only the maintainer
can make that change, and the workflow publishes nothing until it is made; AC6's
handoff line names it and holds the slot for the result. Any change to
`_pkgdown.yml`'s reference or article structure — `pkgdown::check_pkgdown()`
already reports no problems, so a restructure would be its own milestone rather
than a fix. Publishing a separate development-version site under `/dev/`
(pkgdown's `development: mode`), which is a real choice for a `0.0.0.9000`
package and stays a ROADMAP candidate row; this milestone keeps pkgdown's
default single-site layout.

## Acceptance criteria

- [ ] AC1 `.github/workflows/pkgdown.yaml` runs `pkgdown::check_pkgdown()` and
      then builds the site, and its run on this milestone's PR completes with
      both steps reporting success. `DESCRIPTION` carries
      `Config/Needs/website: pkgdown`, the workflow's `setup-r-dependencies`
      step declares `needs: website` so the builder installs from that
      declaration rather than an ad-hoc line, and `.gitignore` lists `docs/` so
      a local build leaves nothing committable (`.Rbuildignore:9` already
      carries `^docs$`).
- [ ] AC2 The site the workflow builds carries no page derived from `CLAUDE.md`
      or `.github/ci-usage-baseline.md`: a step in the same run, after the build
      and before the publish step, fails if `docs/CLAUDE.html` or
      `docs/ci-usage-baseline.html` exists, and it passes. Both were produced by
      `pkgdown::build_site()` on 2026-07-27 before this milestone, and
      `pkgdown:::package_mds(".")` returns exactly those two sources.
- [ ] AC3 Both pkgdown URLs the package advertises resolve to a page in the
      build output: `docs/index.html` for `DESCRIPTION:15`'s
      `https://jmgirard.github.io/nestedtune/`, and `docs/articles/nested-cv.html`
      for README's `[guide]` link (`README.md:110`). A step in the same run
      fails if either file is missing.
- [ ] AC4 `.github/ci-usage.py`'s `read_paths_ignore()` returns one agreed list
      with `pkgdown.yaml` in the workflow set — shown by calling it directly,
      not by running the script, which shells out to `gh` and can exit for
      unrelated reasons — rather than exiting on a disagreeing or missing
      `paths-ignore` list. Every comment stating how many copies of that list
      exist (`.github/workflows/R-CMD-check.yaml:12`,
      `.github/workflows/test-coverage.yaml:3`) names the count that is then
      true.
- [ ] AC5 Nothing publishes except from the default branch: the workflow
      declares a `push` trigger on the default branch, its publish step carries
      `if: github.ref_name == github.event.repository.default_branch`, and this
      milestone's own PR run shows the build step succeeded and the publish step
      skipped.
- [ ] AC6 The milestone file carries a handoff line naming the GitHub Pages
      setting the maintainer must enable (Source: Deploy from a branch →
      `gh-pages` / root) — the repo has no Pages site today
      (`gh api repos/jmgirard/nestedtune/pages` returned HTTP 404, observed
      2026-07-27) — and carries an empty slot for the live URL's HTTP status, to
      be filled in after the maintainer enables it.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T2
- AC4 → T1
- AC5 → T1
- AC6 → T4

## Tasks

- [x] T1 Add `.github/workflows/pkgdown.yaml` derived from the r-lib/actions
      example: `push` on the default branch, `pull_request`, and
      `workflow_dispatch`, with both triggers carrying the `paths-ignore` list
      the other workflows carry; `JamesIves/github-pages-deploy-action` to
      `gh-pages` under `permissions: contents: write`, guarded by
      `if: github.ref_name == github.event.repository.default_branch`. Update
      both copy-count comments (`R-CMD-check.yaml:12`, `test-coverage.yaml:3`)
      from four to six, and confirm `read_paths_ignore()` still returns one list.
- [ ] T2 Add `Config/Needs/website: pkgdown` to `DESCRIPTION` and `needs: website`
      to the workflow's `setup-r-dependencies` step; add a `check_pkgdown()`
      step before the build; add `docs/` to `.gitignore`; add the step asserting
      `docs/index.html` and `docs/articles/nested-cv.html` exist.
- [ ] T3 Delete `docs/CLAUDE.html` and `docs/ci-usage-baseline.html`, and their
      `sitemap.xml` entries, after the build step and before the publish step;
      assert their absence in the same run.
- [ ] T4 Add the handoff line naming the Pages setting; leave the URL-status
      slot empty for after it is enabled.

## Work log

- 2026-07-27: created by /milestone-plan; absorbs the ROADMAP candidate row added 2026-07-26 from M06 review finding F6 (scored 45).
- 2026-07-27: plan gate chose declaring `pkgdown` via `Config/Needs/website` (D-022) over naming it in the workflow's `extra-packages` line, because a dependency that exists only inside a workflow file is invisible to everything else that reads DESCRIPTION; falsified by a builder that `setup-r-dependencies` cannot resolve from that field.
- 2026-07-27: plan gate chose the `gh-pages` branch route over publishing from Actions, because the repo's other three workflows are r-lib-derived and run `permissions: read-all`, which the Actions route would have to broaden to `pages: write` + `id-token: write`; falsified by evidence the branch route mis-serves the site or that a build artifact in git history costs something.
- 2026-07-27: plan gate chose building on pull requests as well as merges over merges-only, accepting the CI minutes against M11's economy stance, because the default branch is a distribution channel and a site that fails to build should not first be discovered as the published one; falsified by measurement showing the PR builds are a material share of CI time.
- 2026-07-27: plan gate chose keeping `CLAUDE.md` and `.github/ci-usage-baseline.md` off the site over shipping them, because pkgdown offers no exclusion knob and the only mechanism is a post-build delete costing about two lines; falsified by a pkgdown release adding a config option, which would make the delete the wrong shape.
- 2026-07-27: plan gate chose ending at a committed workflow plus a handoff line over enabling GitHub Pages within the milestone, because that is a repository setting only the maintainer can change; falsified by nothing short of the maintainer delegating the setting change explicitly.
- 2026-07-27: criteria audit ([O], fresh context) returned seven findings against the step-2 draft; six were fixed before the gate (AC2's unmeasurable "present in the build output", AC3's universal quantifier over a two-item list, AC4 naming only one of two copy-count comments and resting on the whole script rather than `read_paths_ignore()`, AC6 requiring a live URL unreachable before the maintainer acts, three uncovered deliverables, and the missing dependency D-entry) and the seventh — the publish step's guard — became the gate's second question.
- 2026-07-27: implement started on `m17-pkgdown-site-deploy`; no implementation question gate — the plan gate settled the dependency, publish route, triggers, and internal-page choices, leaving nothing genuinely open.
- 2026-07-27: T1 — `.github/workflows/pkgdown.yaml` added; `read_paths_ignore()` returns one list over `R-CMD-check.yaml, pkgdown.yaml, test-coverage.yaml` and the copies now number six, so both copy-count comments went from four to six.
- 2026-07-27: T1 — the profile's test for a fourth `paths-ignore` copy ("cannot change what the run sees") holds for `cairn/**` and `.claude/**` outright, but `CLAUDE.md` passes it only because T3 deletes the page pkgdown builds from it; the workflow's header comment says so, so removing T3's step without the entry reads as a contradiction rather than a silent lie.
- 2026-07-27: T1 — added a `concurrency` block and `timeout-minutes: 20` beyond what the plan named, matching the repo's other workflows; the cap is justified differently here (bounding a runaway against GitHub's 360-minute default) since this job runs no tests and the vignette starts no daemons.
- 2026-07-27: T1 — chose `if: github.ref_name == github.event.repository.default_branch` over r-lib's `github.event_name != 'pull_request'`, which would also publish from a `workflow_dispatch` on a feature branch.

## Decisions

## Review
