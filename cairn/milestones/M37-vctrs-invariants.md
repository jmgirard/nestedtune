<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M37: The vctrs half, so `rbind()` stops claiming a design it never ran

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** `m037-vctrs-invariants`

## Goal

Register the vctrs compatibility methods tune ships beside its dplyr ones, so
the operations that reach `nested_results` through vctrs rather than dplyr obey
the same invariants, and close `rbind()`, which reaches it through neither.

## Scope

Surface tier: **user-facing** — the deliverable is S3 method behavior on an
exported class that callers reach through ordinary vctrs and base verbs.

**In:** `vec_restore.nested_results()` delegating to the rule M36 built
(`reconstruct_results()` in `R/nested-results.R`), plus the `vec_ptype2` and
`vec_cast` pairs among `nested_results`, `tbl_df` and `data.frame`. `vctrs`
joins Imports on the same argument D-031 used for `dplyr`. `rbind.nested_results()`
is written too: base `rbind()` consults neither dplyr nor vctrs, so rsample and
tune both leave it returning a six-row object still reporting three folds, and
IP4 does not let this package do the same. `names<-.nested_results()` is
written for the same reason: `dplyr::rename()` is `set_names()`, which reaches
neither dplyr's `dplyr_reconstruct()` nor any vctrs generic — measured
2026-08-31 on a subclass carrying each method set in turn — so rsample closes
it with `names<-.rset`, and AC1's rename form cannot be met any other way.
The `@return`'s gap paragraph is
corrected — it currently implies the vctrs methods would close `rbind()`, which
is measured false against rsample, which ships them. Reopens and closes
[#32](https://github.com/tidymodels/nestedtune/issues/32).

**Out:** `group_by()`, `rowwise()` and `tibble::as_tibble()` leaving the run's
recorded attributes readable on the object they return — measured identical on
rsample's own `rset`, and none of the three returns something claiming to be a
results object → `DESIGN.md` Known issues, written by this milestone. The
`^id[0-9]*$` fold-label collision → its own ROADMAP candidate row. `vec_proxy()`
and `vec_ptype_abbr()`, which tune does not register either → not planned.

## Acceptance criteria

- [ ] AC1 Each of `vctrs::vec_slice(x, 1)`, `vctrs::vec_rbind(x, x)`,
      `vctrs::vec_c(x, x)`, `rbind(x, x)` and `dplyr::rename(x, fold = id)`
      applied to a completed 3-fold `nested_results` returns an object carrying
      neither class `nested_results` nor any attribute named by
      `results_attributes()`, asserted form by form in
      `tests/testthat/test-vctrs-compat.R`.
- [ ] AC2 `vctrs::vec_slice(x, c(2, 1, 3))` returns an object carrying class
      `nested_results` whose `outer_label`, `grid` and `metrics` are identical
      to the source object's and whose `id` column holds the source's three
      values in the order asked for.
- [ ] AC3 `vctrs::vec_cbind(x, tibble::tibble(extra = 1:3))` and
      `dplyr::bind_cols(x, tibble::tibble(extra = 1:3))` each return an object
      carrying class `nested_results`, and their class vectors are identical,
      so the same operation answers the same way through either door.
- [ ] AC4 `vctrs::vec_cast(x, tibble::as_tibble(vctrs::vec_ptype(x)))` returns
      an object carrying no `nested_results` class, and casting that same
      prototype to `x` raises a condition inheriting `vctrs_error_cast` but not
      `vctrs_error_cast_lossy`, so the refusal to build one is distinguished
      from an ordinary lossy failure rather than asserted by message text.
- [ ] AC5 `vctrs::vec_ptype2()` returns a prototype rather than raising, on
      each of the five ordered pairs combining a `nested_results` with a
      `nested_results`, a `tbl_df` or a `data.frame`, asserted pair by pair.
- [ ] AC6 `?nested_tune_grid`'s `@return` no longer says the vctrs methods
      would close the `rbind()` gap. It states that `group_by()`, `rowwise()`
      and `tibble::as_tibble()` return an object on which the run's recorded
      attributes stay readable, and a test asserts that on a `nested_results`
      directly. `NEWS.md` records the `rename()` and `rbind()` changes and the
      new behavior of `vec_slice()`, `vec_rbind()` and `vec_c()`.
- [ ] AC7 `cairn/PROFILE.md`'s verify slot is clean (`devtools::test()`), and
      the fuller pre-review check it names (`devtools::check()`) passes with 0
      errors and 0 warnings, any NOTE justified in the review record.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T1, T3
- AC5 → T1, T3
- AC6 → T1, T4
- AC7 → T5

## Tasks

- [x] T1 Write `tests/testthat/test-vctrs-compat.R`: AC1's five forms one block
      apiece, AC2–AC5's assertions, and AC6's three leftover paths asserted on a
      `nested_results`. Reuse `test-dplyr-compat.R`'s completed-3-fold fixture
      builder rather than keying a new signature (M36 paid for that once). Record
      which forms already pass against the current code, so the file demonstrably
      fails before T3.
- [ ] T2 Settle the dependency and write the `cairn/DECISIONS.md` entry:
      `vctrs` into Imports (already installed under `dplyr`, `tibble` and
      `rsample`, and Suggests plus `vctrs::s3_register()` would let AC1–AC5 skip
      vacuously), and the `rbind` divergence from rsample and tune, which is an
      IP4 call rather than a compatibility one.
- [ ] T3 Register `vec_restore.nested_results()` against
      `reconstruct_results()`. **Measure before registering the rest**: which
      vctrs entry points reach `vec_restore` and which reach `vec_ptype2` —
      `vec_ptype2(f, f)` on an rsample `rset` returns a bare tibble, measured
      2026-08-31, so tune's `stop_never_called()` shape is only safe where the
      method is shown unreachable, and AC3 asks `vec_cbind` to keep the class.
      Register the `vec_ptype2`/`vec_cast` pairs to what that measurement
      supports. Then `rbind.nested_results()` routing through the same rule.
- [ ] T4 Roxygen: correct the `@return` gap paragraph (`R/nested-tune-grid.R`);
      add the `group_by()`/`rowwise()`/`as_tibble()` limitation to `DESIGN.md`'s
      Known issues; NEWS entries; `devtools::document()`.
- [ ] T5 Run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-08-31: created by /milestone-plan, from the `vctrs compatibility methods` candidate row, which M36 and D-031 both parked here; that row is absorbed and its `group_by()` half goes to DESIGN.md Known issues instead.
- 2026-08-31: [O] criteria audit ran in **full** mode (declared tier user-facing) and returned twelve findings, all disposed here: `vec_cast(x, tibble())` errors as a lossy cast rather than returning a bare tibble (AC4 now casts to the object's own prototype, verified against rsample); `vctrs_error_incompatible_type` is inherited by ordinary lossy failures too, so it cannot pin the refusal (AC4 now asserts `vctrs_error_cast` without `vctrs_error_cast_lossy`); the drafted AC1 promised eleven registered method names, which is instrument-bound and not exhaustively enumerable (dropped to T3); AC3's fold-count clause could not fail on a reorder or a column add (cut); the drafted AC5's "no method aborts on a combination vctrs reaches" quantified over a domain nine calls do not enumerate (narrowed to the five pairs asserted); the drafted AC6 asserted the out-of-rule paths on an rsample object and claimed parity with every rset rsample builds from one exemplar at an unpinned version (both cut; the paths are asserted on a `nested_results`); NEWS under-reported the changed operations (all six named); no criterion covered declaring `vctrs` (T2, and AC7's 0-warning check fails on an undeclared namespace); and the drafted `vec_cbind` clause assumed tune's recipe keeps the class where rsample's drops it, which the gate resolved in the other direction (AC3).
- 2026-08-31: plan gate chose `vctrs` in Imports over Suggests plus load-time registration because the tests of these invariants would otherwise skip vacuously where it is absent, and `dplyr`, already an Import, requires it anyway. Falsified by a user for whom the addition changes an install.
- 2026-08-31: plan gate chose to write `rbind.nested_results()` over leaving base `rbind()` as rsample and tune both leave it, because a six-row object reporting three folds attempted is the untrue record IP4 forbids, and a `@return` sentence is not how an inviolable principle is traded away; the cost is a divergence from upstream on a method neither registers. Falsified by base `rbind()` reaching a path the method cannot control, or by a downstream package depending on `rbind()` returning a `nested_results`.
- 2026-08-31: plan gate chose one rule through both doors — `vec_cbind()` keeping the class exactly as `dplyr::bind_cols()` does — over copying tune's recipe verbatim, which drops it, because a caller cannot predict which door a verb uses and M36 documented the invariant without qualifying it by entry point. The divergence from tune is flagged to topepo on #32. Falsified by a vctrs coherence requirement that forbids the ptype2 lattice AC3 implies, which T3 measures before registering.
- 2026-08-31: plan gate chose to leave `group_by()`, `rowwise()` and `tibble::as_tibble()` carrying the run's attributes over intercepting all three, because each returns an object that no longer claims to be a results object and rsample behaves identically; it goes to DESIGN.md Known issues rather than a candidate row. Falsified by any of the three producing something a `nested_results` method will dispatch on.
- 2026-08-31: /milestone-implement started on `m037-vctrs-invariants`, cut from `main` at `b26eb77`.
- 2026-08-31: amendment (substantive, Scope In) — `names<-.nested_results()` added to the method set at the implementation gate; the plan's premise that `rename()` reaches the class through vctrs is measured false, `dplyr:::rename.data.frame` being `set_names()`, and rsample closes it with `names<-.rset`. AC1 is unchanged.
- 2026-08-31: T3 measurement, ahead of registering: `vec_slice`, `vec_rbind`, `vec_c`, `vec_cbind`, `vec_ptype` and `vec_cast` all reach `vec_restore`; `rbind()` and `rename()` reach no vctrs or dplyr generic; a plain tibble subclass keeps its class through every form but `vec_cbind`, which drops it, and an rsample `rset` sheds on all but `rbind()` and a reorder.
- 2026-08-31: implementation gate chose `vctrs (>= 0.6.1)` in Imports, matching tune's declared minimum; `dplyr`, already an Import, requires 0.7.1, so no install changes.
- 2026-08-31: T1 — `tests/testthat/test-vctrs-compat.R`, 11 blocks, on the same fixture signature `test-dplyr-compat.R` builds (cache report: 1 build, 11 requests). Against the current code 7 fail and 4 pass: AC1's five forms all fail, AC3's `vec_cbind` fails (it drops the class where `bind_cols()` keeps it) and AC4's refusal fails (a tibble casts up silently); AC2's reorder, AC4's downward cast, AC5's five pairs and AC6's three paths pass, the reorder only because nothing intercepts it yet.
