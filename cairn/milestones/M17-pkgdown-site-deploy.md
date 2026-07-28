# M17: The advertised documentation site exists

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m17-pkgdown-site-deploy` · https://github.com/jmgirard/nestedtune/pull/16

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

- [x] AC1 `.github/workflows/pkgdown.yaml` runs `pkgdown::check_pkgdown()` and
      then builds the site, and its run on this milestone's PR completes with
      both steps reporting success. `DESCRIPTION` carries
      `Config/Needs/website: pkgdown`, the workflow's `setup-r-dependencies`
      step declares `needs: website` so the builder installs from that
      declaration rather than an ad-hoc line, and `.gitignore` lists `docs/` so
      a local build leaves nothing committable (`.Rbuildignore:9` already
      carries `^docs$`).
- [x] AC2 The site the workflow builds carries no page derived from `CLAUDE.md`
      or `.github/ci-usage-baseline.md`: a step in the same run, after the build
      and before the publish step, fails if `docs/CLAUDE.html` or
      `docs/ci-usage-baseline.html` exists, and it passes. Both were produced by
      `pkgdown::build_site()` on 2026-07-27 before this milestone, and
      `pkgdown:::package_mds(".")` returns exactly those two sources.
- [x] AC3 Both pkgdown URLs the package advertises resolve to a page in the
      build output: `docs/index.html` for `DESCRIPTION:15`'s
      `https://jmgirard.github.io/nestedtune/`, and `docs/articles/nested-cv.html`
      for README's `[guide]` link (`README.md:110`). A step in the same run
      fails if either file is missing.
- [x] AC4 `.github/ci-usage.py`'s `read_paths_ignore()` returns one agreed list
      with `pkgdown.yaml` in the workflow set — shown by calling it directly,
      not by running the script, which shells out to `gh` and can exit for
      unrelated reasons — rather than exiting on a disagreeing or missing
      `paths-ignore` list. Every comment stating how many copies of that list
      exist (`.github/workflows/R-CMD-check.yaml:12`,
      `.github/workflows/test-coverage.yaml:3`) names the count that is then
      true.
- [x] AC5 Nothing publishes except from the default branch: the workflow
      declares a `push` trigger on the default branch, its publish step carries
      `if: github.ref_name == github.event.repository.default_branch`, and this
      milestone's own PR run shows the build step succeeded and the publish step
      skipped.
- [x] AC6 The milestone file carries a handoff line naming the GitHub Pages
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
- [x] T2 Add `Config/Needs/website: pkgdown` to `DESCRIPTION` and `needs: website`
      to the workflow's `setup-r-dependencies` step; add a `check_pkgdown()`
      step before the build; add `docs/` to `.gitignore`; add the step asserting
      `docs/index.html` and `docs/articles/nested-cv.html` exist.
- [x] T3 Remove `CLAUDE.md` and `.github/ci-usage-baseline.md` from the runner's
      checkout before the build, so pkgdown never renders them; assert
      `docs/CLAUDE.html` and `docs/ci-usage-baseline.html` are absent after the
      build and before the publish step.
- [x] T4 Add the handoff line naming the Pages setting; leave the URL-status
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
- 2026-07-27: T3 amended (minor, mechanism only — AC2 is unchanged and still verified exactly as written). The plan said delete the two built HTML pages after the build; implementation removes the two markdown SOURCES before it instead, because `pkgdown:::get_site_paths()` globs every `*.html` under `docs/` and both `sitemap.xml` and `search.json` are built from that glob — so a post-build delete would leave the pages in the sitemap and `CLAUDE.md`'s full text in the public search index. Verified by execution: `package_mds()` on a fixture returns both files before removal and nothing after.
- 2026-07-27: T2 + T3 landed in one checkpoint commit rather than two, because both edit `.github/workflows/pkgdown.yaml` and splitting them would have meant staging partial hunks of one file.
- 2026-07-27: T2 — added a `NEWS.md` entry as a discovered sub-task the plan did not name; the profile's consistency-gate requires the changelog to cover user-visible change, and a published documentation site qualifies. The entry describes the mechanism (built and republished on default-branch changes), which is true at merge; the URL itself resolves only once the maintainer completes AC6's handoff.
- 2026-07-27: verify slot — `devtools::test()` clean before checking T2/T3 off; an earlier run was discarded because it was piped through `tail`, so the reported exit code was the pipe's and the results summary had been truncated away.
- 2026-07-27: T4 HANDOFF — the maintainer must enable GitHub Pages on `jmgirard/nestedtune` once this merges and the workflow has pushed a `gh-pages` branch: **Settings → Pages → Source: Deploy from a branch → Branch: `gh-pages`, folder `/ (root)`**. Nothing in this milestone can do it — it is a repository setting, and the repo has no Pages site today (`gh api repos/jmgirard/nestedtune/pages` → HTTP 404, observed 2026-07-27). LIVE URL STATUS: unfilled. It is recorded as a new work-log line, not by editing this one, because the work log is append-only (D-045).

## Decisions

## Review

Reviewed 2026-07-27 against PR #16. Evidence for AC1–AC3 and AC5 comes from the
`pkgdown` workflow run `actions/runs/30321336921` — the run *after* the
five actioned findings were fixed, since F1 and F2 changed the workflow's
structure and the earlier run (30320277988) no longer describes what ships.
Step conclusions are quoted from the GitHub jobs API, not from recall.
All ten PR checks pass.

### Acceptance criteria

- **AC1 — met.** Run 30321336921, job `build`: step 7
  `Check pkgdown config: success`, step 8 `Build site: success`; the config
  check precedes the build in step order. `DESCRIPTION:41` carries
  `Config/Needs/website: pkgdown` and the `setup-r-dependencies` step declares
  `needs: website` with `extra-packages: local::.` only. The criterion's "from
  that declaration rather than an ad-hoc line" is now falsifiable and observed:
  nothing else in the run installs pkgdown, so step 7 would fail outright if the
  DESCRIPTION field were absent. (Before the F1 fix `any::pkgdown` sat in
  `extra-packages`, which installed the builder either way and left the field
  decorative.) `git check-ignore -v docs/index.html` reports `.gitignore:23:docs/`,
  so a local build tree is uncommittable; `.Rbuildignore:9` already carried
  `^docs$`.

- **AC2 — met.** Run 30321336921, job `build`: step 9
  `Check the repo-internal pages are absent: success`. It sits after step 8
  (`Build site`) and before the publish step, which after the F2 split is the
  separate `deploy` job gated on `needs: build` — so it still precedes
  publication, and now cannot even be reached without it. It fails on the
  existence of either `docs/CLAUDE.html` or `docs/ci-usage-baseline.html`. The
  removal that makes it pass is step 6, `Drop the repo-internal sources: success`.

- **AC3 — met.** Run 30321336921, job `build`: step 10
  `Check the advertised pages exist: success`, in the same run and after the
  build. The step fails if either `docs/index.html` (the target of
  `DESCRIPTION:15`) or `docs/articles/nested-cv.html` (the target of README's
  `[guide]` link at `README.md:110`) is missing.

- **AC4 — met.** `read_paths_ignore()` called directly (not via the script, whose
  `gh` calls can exit for unrelated reasons) returns
  `['cairn/**', 'CLAUDE.md', '.claude/**']` with sources
  `R-CMD-check.yaml, pkgdown.yaml, test-coverage.yaml` — one agreed list, no
  exit. Enumerating `workflow_triggers()` over the workflow dir gives six
  copies, and both comments stating the count now say six
  (`R-CMD-check.yaml:12`, `test-coverage.yaml:3`).
  `stress-daemon-tests.yaml` still declares neither trigger and so contributes
  none.

- **AC5 — met, and more strongly than the criterion asks.** The workflow declares
  `push` on `branches: [main, master]`, and after the F2 split the guard
  `if: github.ref_name == github.event.repository.default_branch` sits on the
  `deploy` job rather than on a step inside the build job. On run 30321336921 the
  `build` job concluded `success` and the `deploy` job concluded `skipped` — a
  pull request built the site and published nothing, observed rather than
  reasoned about. The criterion says "publish step"; the guard now fences the
  whole publishing job, which satisfies it and additionally keeps the writable
  token out of any run that executes repository code.

- **AC6 — met.** The work log carries the handoff at
  `M17-pkgdown-site-deploy.md:124`, naming the setting in full (Settings → Pages
  → Source: Deploy from a branch → Branch `gh-pages`, folder `/ (root)`) and
  recording that the repo has no Pages site today. It carries
  `LIVE URL STATUS: unfilled`, with a note that the status arrives as a new
  appended work-log line rather than an edit to that one, the log being
  append-only under D-045.

### Consistency gate

Universal cairn-file checks: `cairn_validate` exit 0, all checks passed.
`cairn_impact` skipped — `Principles touched:` is `—` and no IP/GP changed.

Toolchain checks, from the `r-package` profile's `consistency-gate` slot:
`devtools::check()` `Status: OK` (0 errors, 0 warnings, 0 notes);
`devtools::document()` leaves `man/`, `NAMESPACE`, and `DESCRIPTION` clean;
`pkgdown::check_pkgdown()` "No problems found."; `NEWS.md` carries an entry for
the user-visible change and names no milestone; no README.Rmd exists, so the
knit-sync check is a no-op; no new top-level file was added, so the
`.Rbuildignore` check is a no-op (`.github/` was already ignored).
`devtools::test()` at implement time: FAIL 0, WARN 0, SKIP 0, PASS 1239.

### Independent review

Three fresh-context reviewers with distinct evidence bases produced 14 findings
([O] diff-bug 12, [S] blame-history 1, [S] prior-review 1); a separate [S] scorer
that generated none of them scored each 0–100. The prior-review lens probed
`pulls/comments` and found no real GitHub inline threads, so it worked from
archived `## Review` sections.

**Actioned (≥80), all fixed on the branch in `f2dd777`:**

- **F1 (93)** — `extra-packages: any::pkgdown, local::.` installed the builder
  unconditionally, so `Config/Needs/website: pkgdown` was decorative and AC1's
  "installs from that declaration rather than an ad-hoc line" could not fail.
  D-022 had recorded that exact line as the rejected alternative. Dropped
  `any::pkgdown`; `local::.` stays, since it is what makes `install = FALSE`
  correct on the build step.
- **F7 (92)** — the comment describing the advertised-pages check sat above the
  repo-internal check. In a file whose comments are load-bearing, that invites a
  later reader to delete the wrong guard. Both steps now carry their own.
- **F2 (85)** — `permissions: contents: write` was job-level on the single job
  that also ran `build_site_github_pages()`, i.e. the vignette and every roxygen
  `@examples` block, with `GITHUB_PAT` in the environment — on pull requests too.
  Split into a `build` job at `read-all` that uploads `docs/` as an artifact and
  a `deploy` job holding `contents: write`, which runs no repository code and is
  gated on the default branch.
- **F3 (85)** — `NEWS.md` claimed the pages "are now reachable there" (false
  until the maintainer enables Pages) and "republished whenever the default
  branch changes" (false: `paths-ignore` skips tracking-only pushes). Reworded so
  both claims are true at merge.
- **F10 (82)** — `JamesIves/github-pages-deploy-action@v4.5.0` was tag-pinned
  while `test-coverage.yaml` SHA-pins codecov — and the tag-pinned one was the
  only action running with a token that can write to this repo. Pinned to
  `65b5dfd4f5bcd3a7403bbc2959c144256167464e`.

F2's split also retires F11 as a side effect: the workflow-level `read-all` was
dead code under one job that set its own permissions, and now governs `build`.

**Logged below threshold (<80), not actioned — 9 findings.** F4 (65) the absent-
assertion checks the two HTML pages but not `search.json`/`sitemap.xml`, so it
would not catch a future revert to the post-build-delete shape. F9 (65)
`.github/ci-usage-baseline.md:5` still says the filter is read from two
workflows, and M11's baseline was measured before a fourth workflow existed.
F11 (50) dead workflow-level `permissions` — retired by F2's fix. F6 (45)
`clean: false` makes deployment additive, so a page removed from `docs/` lives on
`gh-pages` forever. F5 (35) the internal-page list is hardcoded to two filenames,
so a future `AGENTS.md` would publish silently. F13 (35) `PROFILE.md`'s
test-doctrine slot still describes CI as two gating workflows and does not
mention the third. F8 (30) `read_paths_ignore()`'s all-copies-must-agree rule
welds `CLAUDE.md` into all six lists, so the exit the plan gate named (a future
pkgdown exclusion knob) needs all three workflows touched. F12 (15) empty
milestone `## Decisions` section — matches M11 and M16, so convention. F14 (15)
M06's F6 is only partly discharged since the URL still 404s until Pages is on —
which is the documented scope boundary, not an omission.

F4, F5, F6, F9, and F13 are the ones with residue worth a row; see the ROADMAP
candidates added at merge.
