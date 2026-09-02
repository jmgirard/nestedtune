# M43: The print and summary follow-ups M39 left behind

**Status:** done (2026-09-01, PR #52 https://github.com/tidymodels/nestedtune/pull/52)

**Goal:** A user meeting a `nested_results` through `print()` and `summary()` gets failure advice that
resolves, rows they can page through, and a help page that says which return belongs to which call.

**Outcome:** `print_failures()` (`R/nested-results-print.R`) closes with ``See the `.notes` column of the
results object for what went wrong.`` in place of `x$.notes`, which named nothing inside the summary's
print method; the other three `.notes` advice sites are unchanged, `x` being the results object there.
`print.nested_results(x, ..., n = NULL, width = NULL)` hands both to tibble's print of the class-stripped
rows; the dots fence stays, so `print(res, w = 40)` is refused. `?summary.nested_results` labels its
`\value` paragraphs ``summary()` returns` / ``print()` returns` and carries an engines-guarded example
ending in `summary(res)`; `?print.nested_results` documents `n` and `width`. The four `print(<results>)`
snapshots pass through `scrub_tibble_body()`: the `# A tibble` header and every cli line kept, one marker
for tibble's body. Measured: `rbind()` of seven fixture copies is a bare tibble (the M36 row-count rule).

**Decisions:** none.

**Review:** one round, three-lens fan-out. History and prior-review lenses: no findings. Diff lens:
eight; fixed at the gate the NEWS threshold (twenty, not ten), the comment claiming tibble places `width`
after its dots, and AC3's call assertion (whole call, not its name); rejected the `na.print` partial match
under D-037's degraded path, the scrub's recorded trade-off, its synthetic-only test, the AC3 engine gate,
and the other advice sites' wording (Scope Out). Hygiene retired the M39 follow-ups candidate row this
milestone took whole; nothing graduated.
