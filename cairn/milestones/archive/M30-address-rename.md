# M30: Every address the package shows names its new home

**Status:** done (2026-08-30, PR #31 https://github.com/tidymodels/nestedtune/pull/31)

**Goal:** Every address the package shows the outside world names
`tidymodels/nestedtune` and the documentation site it actually publishes to.

**Outcome:** `DESCRIPTION`, `_pkgdown.yml`, the README's badges, links, install
and guide lines, the rsample draft, `.github/ci-usage-baseline.md`'s title and
the regenerated `man/nestedtune-package.Rd` name `tidymodels/nestedtune` and
`https://nestedtune.tidymodels.org/`; `NEWS.md` gains a move entry, its earlier
site sentence no address. The site was already served at the new host; the
coverage badge reads `unknown` until the first upload. Old repo address 301s.

**Decisions:** Regenerating `man/` also carried roxygen2 8.1.0's own output
(`RoxygenNote` → `Config/roxygen2/version: 8.1.0`; two `importFrom(tune, ...)`
lines merged over the same symbols) — kept, since reverting would fail the
standing `document()` no-diff gate.

**Review:** Three-lens fan-out; only diff-bug found anything — six, one fixed
(a `NEWS.md` sentence whose "the site" would read as the new address for a
period predating the move), five rejected. Five criteria passed on fresh
evidence, gate clean. Merged under a logged override of never-merge-red: both
red legs failed upstream of this package, the branch changes no R code, and a
check on the maintainer's Mac (the failing runner's arch and R) was `Status: OK`.
