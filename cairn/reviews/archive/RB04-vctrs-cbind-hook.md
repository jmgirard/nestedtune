# RB04: An invariant resting on vctrs' experimental frame-prototype generic (M37)

- **Date:** 2026-08-31
- **Output required:** write findings to `cairn/reviews/RR04-vctrs-cbind-hook.md`
- **Binding criteria:** not requested

You are performing an independent expert review. This brief is fully
self-contained — do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

`nestedtune` is an R package that runs nested cross-validation for the
tidymodels ecosystem. It orchestrates the outer resampling loop itself and
delegates inner tuning to the `tune` package. Its main result object is
`nested_results`: a tibble subclass with one row per outer fold, carrying the
per-fold record in columns (`splits`, an `id` fold label, `.metrics`,
`.selected`, `.grid`, `.notes`, `.completed`, `.tuning_seed`,
`.outer_fit_seed`) and the run's description in attributes (`grid`, `metrics`,
`outer_label`, `folds_attempted`, `folds_completed`).

The package holds an inviolable principle, IP4: **what ran is recorded
positively, and a record on an object must be true of that object.** A
three-row object that still reports "3-fold cross-validation, 3 folds
attempted" after being cut down from a ten-fold run is exactly what IP4
forbids.

The previous milestone (M36) implemented, for the dplyr interface, the same
invariants `tune` declares on its own results objects: **rows may be reordered
but never added or removed; columns may be added or reordered; every column
the constructor wrote must still be present holding the same values.** An
operation inside that set gets the class back with the run's record; anything
else gets a plain tibble, with the record removed along with the class. That
rule lives in one function, `reconstruct_results()`, reached through a
`dplyr_reconstruct.nested_results()` method and through `[`.

The current milestone (M37) does the same for the vctrs interface, plus the
two doors that consult neither dplyr nor vctrs (`base::rbind()` and
`dplyr::rename()`, which is `set_names()` and so reaches `names<-`).

**The decision under review.** At M37's planning gate the maintainer chose
that the answer must not depend on which door the caller used: adding a column
with `vctrs::vec_cbind()` should keep the class exactly as `dplyr::bind_cols()`
does, on the reasoning that a caller cannot predict which door a verb goes
through, and the documented invariant is not qualified by entry point. This
diverges from both upstream packages: on an `rsample` `rset`, `vec_cbind()`
drops the class while `bind_cols()` keeps it (measured 2026-08-31 against
rsample 1.3.2, vctrs 0.7.3).

Implementation then found that `vec_cbind()` does not reach `vec_ptype2()` or
`vec_restore()` on the source object at all. It builds its output container by
calling `x[0]` through the generic `vctrs::vec_cbind_frame_ptype()`, whose
default method is exactly `x[0]`. Because `[.nested_results` sheds the class
on a zero-column subset (a subset with none of the record's columns cannot
answer for the run), the class is gone before either vctrs generic is
consulted, and the assembled result is a plain tibble.

The only lever found is registering `vec_cbind_frame_ptype.nested_results()`.
That generic is exported from vctrs, has its own help page, and that help page
marks it `[Experimental]` with the keyword `internal`, describing it as "an
experimental generic that returns zero-columns variants of a data frame... It
is needed for `vec_cbind()`, to work around the lack of colwise primitives in
vctrs. Expect changes." A sweep of every package installed in this
environment's library found no package other than vctrs itself that mentions
the generic in its `NAMESPACE`.

The method is currently registered and every M37 test passes. The maintainer
escalated rather than settle it: whether a user-facing invariant on an exported
class should rest on an interface its own package marks experimental and
internal.

## Materials

All paths are relative to the repository root.

- `R/nested-results.R` — the class and every method.
  - `can_reconstruct_results()` at line 121 and `reconstruct_results()` at line
    149: the rule itself.
  - `stamp_results()` at 167, `bare_results()` at 188: what a kept object and a
    shed object carry.
  - `dplyr_reconstruct.nested_results()` at 217, `[.nested_results` at 226: the
    dplyr door M36 shipped.
  - `vec_restore.nested_results()` at 260: the vctrs door, including the
    "empty container" branch that exists only to let `vec_cbind()`'s assembly
    pass through — read its comment.
  - `nested_results_ptype()` at 290 and `copy_results_attributes()` at 301.
  - **`vec_cbind_frame_ptype.nested_results()` at 321 — the method under
    review**, with the comment stating the risk.
  - The `vec_ptype2` pairs at 329–353, the `vec_cast` pairs at 363–392,
    `rbind.nested_results()` at 416, `names<-.nested_results()` at 434.
- `tests/testthat/test-vctrs-compat.R` — the criteria as tests. The block at
  line 120 is the one this question decides; the file's header comment records
  which entry points reach which generic.
- `cairn/milestones/M37-vctrs-invariants.md` — acceptance criteria and the
  work log, including the two rounds of measurement summarized above.
- `cairn/DECISIONS.md`, entries D-031 (the dplyr half, and why the invariant
  set is every column the constructor writes) and D-032 (the vctrs half, the
  dependency, and the three deliberate divergences from upstream).
- vctrs itself: `?vctrs::vec_cbind_frame_ptype`, and
  `vctrs:::vec_cbind_frame_ptype.default`.

To reproduce the behavior without fitting a model, a synthetic object suffices:
a tibble with the nine record columns above, class
`c("nested_results", "tbl_df", "tbl", "data.frame")`, and the five attributes.
Run the package's tests with
`Rscript -e 'devtools::test(filter = "vctrs-compat")'`; the full suite is
`Rscript -e 'devtools::test()'` and takes roughly three minutes.

## Questions

1. Is registering a method for `vec_cbind_frame_ptype()` a defensible way for a
   package to make `vec_cbind()` preserve a data-frame subclass, given that
   vctrs marks the generic experimental and internal? Is there any other
   mechanism — one this brief has not found — by which `vec_cbind()` can be
   made to preserve a subclass, or by which the class can be restored
   afterwards on the same call?

2. What are the concrete failure modes if a future vctrs release changes or
   removes the generic? Specifically: would the registered method become inert
   (the class quietly stops being kept), would it error, or could it produce a
   malformed object? The package's test at `test-vctrs-compat.R:120` is the
   only thing that would notice — is a test in a package's own suite an
   adequate guard here, given that it fires only when the maintainer runs the
   suite against the new vctrs, not on a user's machine?

3. Weigh three dispositions, and recommend one:
   (a) **keep** the method, with the test as the guard;
   (b) **remove** it and accept that `vec_cbind()` returns a plain tibble where
       `dplyr::bind_cols()` returns a results object, matching what rsample and
       tune do, and document the difference;
   (c) some third shape this brief has not considered.
   Consider in particular whether option (b)'s door-dependent answer is a
   genuine hazard for a user, or a theoretical one: name a realistic sequence
   of calls in which a user is misled by it.

4. Independent of the disposition, is the "empty container" branch in
   `vec_restore.nested_results()` (line 260 onward) sound? It lets a frame with
   no columns and no rows carry the class through vctrs' assembly, and it is
   reachable — by construction — only from inside `vec_cbind()`. Can any
   sequence of public calls put a caller in possession of a `nested_results`
   with no columns, or otherwise exploit that branch to obtain an object whose
   record is untrue of its rows?

5. The prototype carriers (`nested_results_ptype()` at 290, and the frame
   prototype at 321) copy the source object's attributes verbatim rather than
   recomputing them, so a zero-row or zero-column prototype carries
   `folds_attempted = 3` from the object it was made from. `vec_restore()`'s
   third branch then uses that number as its row-count check. Is a type token
   carrying a count that is not true of its own rows a violation of IP4 in
   substance, or is a prototype outside what IP4 governs? If it is a violation,
   what carries the source's row count instead?

## Constraints

Fixed; flag disagreement explicitly rather than working around it.

- **IP4** — a record on an object is true of that object — is inviolable and is
  not up for trade. A recommendation that requires amending it must say so in
  those terms.
- **D-031** fixed the invariant set as every column the constructor writes, and
  fixed that the rule lives in one function. Do not re-litigate the invariant
  set or propose a second rule for the vctrs door.
- **D-032** fixed `vctrs (>= 0.6.1)` in Imports, the refusal to cast a plain
  table up to a `nested_results`, and `rbind()` and `names<-` methods of the
  package's own. Only the `vec_cbind` half is open.
- The package delegates inner tuning to `tune` and does not vendor or fork
  upstream code; a recommendation to patch or shim vctrs internals is out of
  bounds. A recommendation to raise the question upstream is in bounds and
  should say what the upstream ask would be.
- The package is pre-1.0 with the deprecation cycle waived (D-003), so a
  behavior change here costs no deprecation.

## Output format

In `RR04-vctrs-cbind-hook.md`: answer each question by number with your
reasoning and evidence; list any additional findings separately under "Beyond
the brief"; end with concrete recommendations, each marked apply / consider /
reject-with-reason. Your report is advisory: this brief does not request a
`## Binding criteria` section, so emit recommendations only.
