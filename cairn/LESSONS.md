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
- 2026-07-26 (M02): `tune` >= 2.0.0 derives its own per-resample L'Ecuyer substreams *even under* `control_grid(allow_par = FALSE)`, and is net-zero on the caller's `.Random.seed` and `RNGkind()`; only `last_fit()` consumes the ambient stream. A fold's outcome therefore hangs on exactly two RNG states, and tune 1.x seeded differently — which is why `tune (>= 2.0.0)` is pinned.
- 2026-07-26 (M02): with a deterministic engine every RNG test passes vacuously, including under seeding schemes that are wrong. Any test claiming to pin reproducibility needs an engine whose randomness flows through R's RNG (ranger qualifies; kernlab and the deep-learning engines do not, at all).
- 2026-07-26 (M02): testthat's `expect_equal()` carries a 1.5e-8 numeric tolerance in edition 3, so a criterion demanding `identical()` is not met by it — reach for `expect_identical()` when the criterion says exact.
- 2026-07-26 (M02): `workflows::workflow()` already refuses a model spec with an unknown mode, so a downstream mode check is unreachable dead code; and trained-ness is a *field*, not a class — test it with `workflows::is_trained_workflow()`, never `inherits(x, "trained_workflow")`.
- 2026-07-26 (M02): a cli pluralization marker takes its quantity from the preceding `{}` substitution in the *same* string, so `{?is/are}` in a bare `i =` bullet errors with "Cannot pluralize without a quantity" — set it explicitly with `{cli::qty(x)}`.
- 2026-07-25 (M01): `NEWS.md` must head with `# <pkg> <version>`; the usethis-style `# <pkg> (development version)` is unparseable by R's news reader and produces a "No news entries found" NOTE.
- 2026-07-26 (M03): tune's failure surfaces are not where you would look. `tune_grid()` returns *normally* (with a warning) when every candidate fails — `select_best()` and `collect_metrics()` are what raise — and `last_fit()` never raises at all, handing back a result whose `collect_metrics()` is `NULL`. Catching only thrown errors records a failed fold as a success carrying nothing.
- 2026-07-26 (M03): `testthat::expect_warning()` returns the *condition* when it catches one, not the expression's value, so `x <- expect_warning(f())` binds the warning and any assertion on `x` tests the wrong object; fetch the value separately.
- 2026-07-26 (M03): `tune::extract_parameter_set_dials()` omits a parameter the engine cannot tune (`penalty` on the `lm` engine) even though it is marked with `tune()` — so a grid that omits it passes a tunable-set check and `tune_grid()` raises later. Useful as a test vehicle; a trap for any check that treats the set as complete.
- 2026-07-26 (M03): attributes survive `[` on a tibble subclass, so a count stamped at construction goes on describing the parent after a row subset. Derive such facts from a column at use time, or give the class a `[` method that recomputes them.
