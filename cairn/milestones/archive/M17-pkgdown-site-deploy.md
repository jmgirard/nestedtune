# M17: The advertised documentation site exists

**Status:** done (2026-07-27, PR #16 https://github.com/jmgirard/nestedtune/pull/16)

**Goal:** The advertised pkgdown URL resolves to a built site, rebuilt from the
default branch whenever the package changes.

**Outcome:** `.github/workflows/pkgdown.yaml` builds the site and publishes it to
`gh-pages` in two jobs — `build` at `read-all` uploads `docs/` as an artifact;
`deploy` holds `contents: write`, runs no repository code, and is gated on
`github.ref_name == github.event.repository.default_branch`. The builder resolves
from `Config/Needs/website: pkgdown` (D-022), `extra-packages: local::.` alone.
`CLAUDE.md` and `.github/ci-usage-baseline.md` are dropped from the checkout
*before* the build, not as HTML after, because `sitemap.xml` and `search.json`
derive from a `docs/**/*.html` glob; two assertion steps guard that. `docs/`
joined `.gitignore`, the copy count went four to six, Pages stayed maintainer's.

**Decisions:** D-022 (pkgdown declared via `Config/Needs/website`, unpinned).

**Review:** Three lenses, 14 findings, separately scored, five fixed on the
branch: F1 (93) `any::pkgdown` made the declaration decorative and AC1
unfalsifiable; F7 (92) a load-bearing comment sat above the wrong step; F2 (85)
the build job held `contents: write` while running vignette code; F3 (85) NEWS
claimed a live site; F10 (82) the write-scoped action was tag-pinned. Nine
logged below 80; F4/F5/F6/F9/F13 became two candidate rows.
