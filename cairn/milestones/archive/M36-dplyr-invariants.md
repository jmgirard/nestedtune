# M36: Removing an outer fold's row stops producing a `nested_results`

**Status:** done (2026-08-31, PR #45 https://github.com/tidymodels/nestedtune/pull/45)

**Goal:** Give `nested_results` the subclass invariants tune's `tune_results` declares, so a dplyr
verb that changes the row set returns a bare tibble, not an object still claiming its old design.

**Outcome:** One rule — `can_reconstruct_results()` / `reconstruct_results()` / `bare_results()` in
`R/nested-results.R` — decides whether an operation keeps the class: rows reorderable but never added
or removed, columns addable and reorderable, every constructor-written column present holding its
values. `dplyr_reconstruct.nested_results()` registers against it and `[.nested_results` delegates,
so `slice()`, `head()`, `x[1, ]`, a `filter()` dropping a fold and `bind_rows()` return a bare
tibble, record stripped. `dplyr (>= 1.1.0)` joins Imports. `id_columns()` (`^id[0-9]*$`) is the one
place the design's own label columns are named, asked by `record_columns()`,
`has_results_columns()` and `fold_ids()` alike, which also fixed a pre-existing mislabel pasting an
added `id`-prefixed column into every fold's label. Closes #32; breaking, under D-003's waiver.

**Decisions:** D-031 (dplyr into Imports; the invariant set is every column the constructor writes;
one registered method, not three). Milestone-local: how the fold-label columns are identified.

**Review:** Three rounds, three-lens fan-out each; two defect returns (the keep branch dropping tibble
classes and `^id` set-equality; then a stale `@details` promise and the `^id` grep's order-key error
and unremovable added column). Round 3 found the family alive under `id2`/`id0`/`id9`; the maintainer
declined a third return, fixed the record at the gate, sent the behavior to a candidate row, and
retired the M03/M20 stale-attribute lesson — this milestone's tests now fail on it.
