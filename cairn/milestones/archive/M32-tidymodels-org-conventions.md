# M32: The community files and site template the tidymodels organization shares

**Status:** done (2026-08-30, PR #40 https://github.com/tidymodels/nestedtune/pull/40)

**Goal:** A contributor arriving at `tidymodels/nestedtune` finds the same
contributing guide, code of conduct and documentation site the organization's
other packages carry.

**Outcome:** `.github/CODE_OF_CONDUCT.md` and `.github/CONTRIBUTING.md` vendored byte-identical
to blobs `3ac34c82` and `23b135bd`, chosen by a nine-repository survey (rsample, tune, workflows,
yardstick, parsnip, recipes, dials, broom, hardhat): the code of conduct unanimous, the guide the
mode at 3 of 9, `34272f04` runner-up at 2. pkgdown renders both as site pages. `_pkgdown.yml` gains
`template: package: tidytemplate`, `bootstrap: 5`, `bslib` `primary`/`danger` `#CA225E` — rsample's
and tune's block; `Config/Needs/website` reads `pkgdown, tidyverse/tidytemplate`, the workflow's
`extra-packages` left at `local::.` so the field stays load-bearing. `README.md` gains a lifecycle
`experimental` badge.

**Decisions:** D-027 (the template switch and the `tidyverse/tidytemplate`
declaration, extending D-022).

**Review:** Three-lens fan-out (user-facing tier), five findings. Actioned: the
site-analytics `in_header` block all nine siblings carry, which no criterion ruled
on, absorbed into the standing conventions candidate row; the `NEWS.md` bullet
reworded at the gate to claim only what the build does. Rejected: a broken link, a
Covenant version mismatch inside the hash-pinned upstream texts, key-order drift.
