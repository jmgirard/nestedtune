# Lessons

_Durable "how this repo behaves" notes — build quirks, testing tricks,
toolchain gotchas. Captured at milestone end, harvested at plan time._

_One lesson per line. Current knowledge, not history: a lesson proven false
is **corrected in place** and marked (`(M07, corrected M11)`); git holds the
original. A lesson is **retired** — leaving no line behind — once a test
fails on the mistake it warns about, another tracking file's slot owns the
content, or a matured family graduates whole into a doctrine module._

_Hard cap: 50 lines._

## Lessons

- `cairn/references/INDEX.md` entries must be bullet lines (`- page.md — what it covers`); the references check matches only that form, so a table-formatted index reads as empty and every page reports "no INDEX.md line". (design interview, 2026-07-25)
- 2026-07-25 (M01): `rsample::make_splits()` returns a bare `rsplit` — no split subclass and no per-split `$id` — so splits built with it break `labels()`, `add_resample_id()`, and rsample's class generics; rewrite the fields of the splits rsample itself produced instead.
- 2026-07-25 (M01): `rsample::analysis()` and `assessment()` renumber row names on retrieval, so a split indexing the original data is indistinguishable from one indexing a materialized copy — do not design around a row-name difference that is not observable.
- 2026-07-25 (M01): a roxygen `@section` title containing `::` inside backticks yields a malformed Rd section and two `R CMD check` WARNINGs; keep code formatting out of section titles.
- 2026-07-25 (M01): `NEWS.md` must head with `# <pkg> <version>`; the usethis-style `# <pkg> (development version)` is unparseable by R's news reader and produces a "No news entries found" NOTE.
