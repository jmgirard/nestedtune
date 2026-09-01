# M42: The fixture key's separation test, derived from the orchestrators' own arguments

**Status:** done (2026-09-01, PR #51 https://github.com/tidymodels/nestedtune/pull/51)

**Goal:** The test that pins what the fixture cache's key separates enumerates its
domain from the orchestrators' formal arguments at run time, instead of from a
hand-written list of signatures.

**Outcome:** `test-fixture-cache.R`'s hand-listed signature test is replaced by a
per-argument axis test: for every formal in `setdiff(names(formals(f)), "...")` of
`nested_tune_grid()` and `nested_final_fit()`, a base request and a variant differing
only in that formal, built and keyed at the same seed, must key apart under
`fixture_key()`. A `signature_variants` registry holds one alternate per formal; an
unregistered formal, a stale registry entry, and an enumeration lacking `object` or
`resamples` each fail naming the offender, above the engine and `dials` skips.
`fixture_key()` (`helper-orchestration.R`) refuses a request whose sorted arguments'
canonical form reaches `canonical_form()`'s 40-level cut (class `fixture_key_depth`),
naming each deep argument by name or `position <i>`; the deepest real request is 30
levels (2026-09-01). The `canonical_form()` preamble states what the derived test
pins, and that its attribute and environment clauses are not what it exercises.

**Decisions:** none.

**Review:** two rounds, three-lens fan-out each. Round 1 returned on O3 (a positional request left the guard's message naming no argument; AC3) and fixed O1, O2, O6, O7, O9 with it. Round 2 fixed R1 (the preamble claimed the test pins the attribute and environment clauses), R4 (the skips hid the enumeration checks) and R7 (the boundary comment named level 38 for 39); deferred the guard's blind spots (O5/R2: `fn` and the caller bindings hashed unguarded, the bindings canonicalized twice) with the fixture-family axis and a recipe-vs-recipe pair (O4, S1-S3, R3) to a candidate row; rejected O8 (absorbed by T5), O10/R8, R5, R6, R9, R10. Hygiene retired the M35/M41 fixture-cache candidate row this milestone took; nothing graduated.
