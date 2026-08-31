# What the outer loop needs from the resampling object (M27)

**Provenance.** Ingested 2026-08-01 by M27 from first-hand reading of this
package's own sources — `R/checks.R`, `R/nested-tune-grid.R`,
`R/nested-resamples.R`, `R/parallel.R`, `R/nested-final-fit.R`,
`R/nested-results.R` at the M27 branch point (`9b8dd07`) — plus the
measurements in `benchmarks/outer-loop-object-requirements.R`.
Pagination: —.
Extraction: first-hand record; every `file:line` was read directly at `9b8dd07` before being cited — observed 2026-08-01.

**Scope.** A requirements inventory for a redesigned nested-resampling
object: every read this package's driver makes of the current object (R
rows), what the driver reconstructs because the object does not carry it (C
rows), and where the rsample class boundary forces a workaround (W rows).
It deliberately builds no replacement class and proposes no API — that is
joint work with the rsample maintainer, and this page supplies only the
requirements such a design would have to meet. It is not a source summary of
rsample; `tidymodels-nested-cv-gaps.md` snapshots the ecosystem where this
page snapshots our own driver. This is a reference, not an authority —
status lives in `ROADMAP.md`, decisions in `DECISIONS.md`, architecture in
`DESIGN.md`.

**Evidence snapshot.**

- The six driver files above, read whole — branch
  `m27-resampling-object-requirements`, cut from `main` at `9b8dd07` —
  observed 2026-08-01.
- A sweep of the remaining `R/` files (`nested-results-print.R`,
  `nested-results-plot.R`, `nested-final-fit-print.R`,
  `nested-final-fit-extract.R`, `reexports.R`, `nestedtune-package.R`)
  found no read of the resampling design outside the six files — those
  files read only the results and final-fit objects — observed 2026-08-01.

## What the resampling object is today

The design both constructors produce is an rsample `rset`: a data frame
with a `splits` list column (one `rsplit` per outer fold), an
`inner_resamples` list column (one inner `rset` per outer fold), one or
more `id*` columns naming the folds, the classes
`nested_resamples`/`nested_cv` plus the outer scheme's own classes, and two
attributes storing the construction calls (`outside`, `inside`,
`R/nested-resamples.R:129-130`). Each `rsplit` carries three index-bearing
fields the package touches — `in_id`, `out_id`, `data` — none of them
behind a public accessor. Everything else the driver needs, it derives.

## R — every read the driver makes of the object

"Driver" here is the consuming path: validation (`check_nested()` and
friends), the loop (`nested_tune_grid()` → `dispatch_folds()`), results
assembly (`new_nested_results()`), and the final fit
(`nested_final_fit()`). The constructor's own reads of rsample's objects
are inventoried under W, since they exist to cross the class boundary.

| # | Read | Site | What it answers |
|---|---|---|---|
| R1 | `is.data.frame(resamples)` | `R/checks.R:109` | is this a design at all |
| R2 | `names(resamples)` must contain `splits`, `inner_resamples` | `R/checks.R:109` | the two load-bearing columns exist |
| R3 | `nrow(resamples)` | `R/checks.R:123` | refuse a zero-fold design |
| R4 | `grepl("^id", names(resamples))` | `R/checks.R:129` | at least one fold-label column exists |
| R5 | `inherits(resamples, "bootstraps")` | `R/checks.R:143` | refuse an outer bootstrap (class stands in for "rows can repeat") |
| R6 | `resamples[[column]]` element-wise `inherits()` — `splits` → `rsplit`, `inner_resamples` → `rset` | `R/checks.R:198-199`, driven from `:160-175` | every element is the class the loop will hand to tune |
| R7 | `attr(resamples, "inside")` | `R/checks.R:302` | the stored inner specification, as an unevaluated call |
| R8 | `nrow(resamples)` | `R/nested-tune-grid.R:307` | how many seed pairs to draw |
| R9 | `resamples$splits[[i]]` | `R/nested-tune-grid.R:324` | fold i's outer split, into the payload |
| R10 | `resamples$inner_resamples[[i]]` | `R/nested-tune-grid.R:325` | fold i's inner rset, into the payload |
| R11 | `payload$split$data`, via `payloads[[1L]]$split$data` | `R/parallel.R:244` | the one shared frame every fold is leaned against |
| R12 | payload shape: `names()`, `inherits(split, "rsplit")`, `split$data`, `inner$splits`, `inner$splits[[1L]]$data` | `R/parallel.R:119-129` | is this a fold payload lean dispatch may rewrite |
| R13 | every inner split's `$data`, pairwise `identical()` | `R/parallel.R:137-141` | do the inner splits share one frame (the invariant C2 reconstructs) |
| R14 | `payload$split$data`, `payload$inner$splits[[1L]]$data` against `shared` | `R/parallel.R:145-146,150-155` | which frames travel with the fold rather than once per run |
| R15 | `names(resamples)` less `splits`, `inner_resamples` | `R/nested-results.R:10` | the id-column set, by subtraction (C4) |
| R16 | `resamples$splits`, `resamples[[nm]]` per id column | `R/nested-results.R:12,14` | the columns the results object copies over |
| R17 | `class(resamples)`, stripped of `nested_resamples`/`nested_cv`, then `pretty()` | `R/nested-results.R:50-51` | a printable name for the outer scheme (W1) |
| R18 | `x$splits[[1]]$data` via `split_data()` | `R/nested-resamples.R:223-225`, called at `R/nested-final-fit.R:183` | the training data itself (C1) |
| R19 | `attr(resamples, "inside")` via `check_inside_spec()`, then re-evaluated | `R/nested-final-fit.R:180`, `R/checks.R:328-369` | the procedure to re-run on all rows (C5) |

Two reads deliberately absent, worth recording: nothing on the driver path
reads `attr(resamples, "outside")` (stored at `R/nested-resamples.R:129`,
consumed only by tests — observed 2026-08-01), and nothing reads the
`fingerprint` attribute after construction.

## C — what the driver reconstructs because the object does not carry it

Each row names the reconstruction, its site, and what the object would
have to carry for the reconstruction to disappear.

| # | Reconstruction | Site | What the object would have to carry |
|---|---|---|---|
| C1 | The training data. The design has no data field; the whole frame is recovered by reaching into the first split's private `$data` (`split_data()`). | `R/nested-resamples.R:223-225`; consumed at `R/nested-final-fit.R:183` and `R/nested-resamples.R:86` | One first-class `data` slot on the design, with an accessor — the single shared frame every index refers to. |
| C2 | The one-shared-frame invariant. Lean dispatch takes one frame per fold and writes it onto every inner split, which is sound only if they shared it; the object asserts nothing, so `is_fold_payload()` verifies it pairwise per fold, and a design that fails is sent down the fat path. M23 review F1 (scored 93) showed the absence of this gate tunes on the wrong rows in parallel. | `R/parallel.R:133-141` | The invariant as a guarantee of the class: indices-into-one-frame by construction, so sharing is a property, not a per-dispatch measurement. |
| C3 | Fold labels. `fold_ids()` greps for `^id` columns and pastes `id`/`id2` together to label folds uniquely. | `R/nested-results.R:351-357` | A declared fold-label accessor (or a single canonical label column) instead of a naming convention to grep for. |
| C4 | The id-column set, by subtraction: every column that is not `splits` or `inner_resamples` is assumed to be an id column. A design carrying any other column would silently sweep it into the results object. | `R/nested-results.R:10` | The id columns declared positively — named by the object rather than inferred from what remains. |
| C5 | The re-evaluable inner specification. The `inside` attribute is an unevaluated call that travels without its environment, so `eval_inside_spec()` re-evaluates it wherever the caller now stands, and a spec written against a variable silently resolves to whatever that name means today — undetectable from the design alone; the docs defend by asking for literals. | `R/checks.R:328-369` | A self-contained specification — arguments substituted at construction, or a closure — that re-evaluates identically anywhere. |
| C6 | The fold↔seed binding. Reproducibility per fold requires two seeds assigned by fold position; the object carries nothing, so `nested_tune_grid()` draws `2n` seeds at entry and binds them positionally into each payload, and the results object must then store them per fold for a single fold to be reproducible by hand. | `R/nested-tune-grid.R:318,322-328` | Nothing, necessarily — but a design that carried per-fold seed slots (or a seed contract) would make a fold reproducible from the design alone rather than from the results object. |
| C7 | The outer scheme's name. The design describes both levels at once through rsample's `pretty()`, so printing the outer scheme alone requires stripping classes first (also W1). | `R/nested-results.R:48-56` | The outer and inner schemes separately describable — each level answering for itself. |

## W — where the rsample class boundary forces a workaround

Each row names the site and the rsample behaviour that forces it.

| # | Workaround | Site | The rsample behaviour behind it |
|---|---|---|---|
| W1 | Strip `nested_resamples`/`nested_cv` off a copy of the design to reach the outer scheme's own `pretty()` method. | `R/nested-results.R:50-51` | `pretty()` on a nested design dispatches to a method describing both levels at once; no accessor yields the outer scheme alone. |
| W2 | Write `inner_split$in_id`, `$out_id`, `$data` directly to remap inner splits onto the original frame. | `R/nested-resamples.R:173-175` | An `rsplit`'s three index-bearing fields have no public constructor or setter that preserves the split subclass and its per-split `id` tibble; rebuilding via `manual_rset()` would drop both (the comment at `:160-168` records this). |
| W3 | Make `out_id` explicit where rsample leaves it `NA`. | `R/nested-resamples.R:170-174` | rsample derives an inner split's assessment set as the complement within the frame the split indexes — sound only because its inner splits index a materialized analysis set. Splits indexing the whole data would sweep the outer fold's assessment rows into the complement. |
| W4 | Recompute the `fingerprint` attribute by building a throwaway `manual_rset()` and harvesting its attribute. | `R/nested-resamples.R:185-186` | The fingerprint describes the indices it was computed from and rsample exports no way to recompute one in place. |
| W5 | Re-add rsample's classes — `c("nested_resamples", "nested_cv", class(outside))` — so methods written against `nested_cv` keep working. | `R/nested-resamples.R:128` | Class identity is the only compatibility surface: nothing short of carrying rsample's own classes makes existing methods dispatch. |
| W6 | Blank each split's `$data` with `x["data"] <- list(NULL)` before dispatch and write it back on the worker. | `R/parallel.R:148-151,169-173` | R's serializer does not preserve sharing, so each split's private `$data` field writes its own copy to the wire; rsample offers no data-free split, so leanness means reaching into the field and blanking it — with the `["data"] <- list(NULL)` idiom because `$data <- NULL` would delete the element and change the shape. |
| W7 | Read the frame through the private field path `x$splits[[1]]$data` (`split_data()`), asserting all splits share it. | `R/nested-resamples.R:223-225` | rsample has no accessor for the data an rset was built on; the frame exists only inside each split. |
| W8 | Read `split$in_id` and materialize `as.data.frame(split)` to hand the inner specification exactly what rsample would. | `R/nested-resamples.R:141-142` | `in_id` is a private field; the public path to a fold's analysis rows is materializing the frame, which is the copy the lean constructor exists to avoid keeping. |
| W9 | Guard the two load-bearing columns element-by-element (`rsplit`/`rset` classes) before running. | `R/checks.R:162-181,187-188` | `rsample::nested_cv()` builds a design whatever its `inside` returned, so a malformed design is representable and must be caught by the consumer; class inspection is the only cheap question an `rsplit` answers. |
| W10 | Read the stored inner specification from a bare attribute, `attr(resamples, "inside")`. | `R/checks.R:302` | The construction call is stashed as an undocumented attribute by both constructors — convention, not contract; a design assembled any other way carries none and is refused. |
| W11 | Detect "rows can repeat in the outer level" by class: `inherits(resamples, "bootstraps")`. | `R/checks.R:143` | The object exposes no property saying whether outer assessment sets can overlap analysis sets; the class name is the only signal, and `rsample::nested_cv()` itself only warns. |

## Measurements

From `benchmarks/outer-loop-object-requirements.R` — R 4.6.1 / rsample
1.3.2 / nestedtune 0.0.0.9000, seed 35222, run on this branch — observed
2026-08-01. Each axis carries a closed-form model beside the live number
(GP2); the models are the two `rsample-283-reprex.R` derives, extended to
the wire.

**Axis 1 — in-process object size**, `lobstr::obj_size()` on
`mlbench::LetterRecognition` (20,000 × 17; 2,644,640 B), at two settings
M13's script does not cover:

| scheme | `nested_cv()` bytes | model resid | `nested_resamples()` bytes | model resid | ratio | model ratio |
|---|---|---|---|---|---|---|
| 5×5 | 14,842,960 | −0.13% | 4,597,576 | −0.72% | 3.228 | 3.247 |
| 20×5 | 60,547,376 | −0.09% | 11,885,552 | −1.02% | 5.094 | 5.142 |

The ratio scales with v exactly as the model's `data_bytes × v` term says —
the reindexing benefit on this axis is roughly (v−1) avoided copies of the
data, so it grows with the outer fold count and is already 3.2× at the
practical 5×5.

**Axis 2 — per-fold wire bytes under the current dispatch path**
(`dispatch_folds()` with leaning, R/parallel.R), on the M23 payload
fixture (5,000 × 21 doubles; serializes to 840,540 B, model 840,000 B,
−0.06%). Per fold what crosses is the leaned payload plus the shared frame
riding in `.args`, which mirai serializes once per task; the workflow term
is the user's object, independent of constructor, measured at M23 and not
counted here:

| scheme | constructor | payload/fold | model resid | wire/fold | model | shared copies | own-frame copies |
|---|---|---|---|---|---|---|---|
| 5×5 | `nested_resamples()` | 98,346 | −2.39% | 938,886 | 936,000 | 0 | 0 |
| 5×5 | `nested_cv()` | 754,858 | −0.38% | 1,595,398 | 1,592,000 | 0 | 1 |
| 20×5 | `nested_resamples()` | 116,347 | −2.02% | 956,887 | 954,000 | 0 | 0 |
| 20×5 | `nested_cv()` | 895,859 | −0.32% | 1,736,399 | 1,733,000 | 0 | 1 |

The copy counts are the second, independent oracle type (occurrences of
the frame's own wire bytes in the stream, net of a sentinel-coincidence
the script documents): a leaned `nested_resamples()` fold carries no frame
at all, while a leaned `nested_cv()` fold still carries one — its own
materialized analysis frame, which leaning cannot remove because the
object, not the dispatcher, owns that copy. That frame is ~89% of a
`nested_cv()` fold's payload (672,540 B of 754,858 B at 5×5; 798,540 B of
895,859 B at 20×5). The payload gap between the constructors — 656,512 B
at 5×5 — is that frame less the 16,028 B of extra explicit indices the
reindexed fold carries (its inner splits store an explicit `out_id` where
`nested_cv()`'s derive the complement, W3). Reindexing removes the frame
by construction; no dispatch-side leaning can.

## Disposition

- R1-R19, C1-C7, W1-W11 feed the maintainer-facing draft under
  `benchmarks/` (M27 T7) and are the requirements input to the joint
  redesign conversation — no ROADMAP row of their own; the redesign itself
  is out of this milestone's scope by plan.
- Nothing here supersedes `tidymodels-nested-cv-gaps.md`; the two snapshot
  different objects (the ecosystem vs. this driver).

## Open questions

- Whether M26's shared-memory finding changes the wire-cost argument: mori
  maps the shared frame rather than serializing it per fold, which would
  shrink the per-fold wire gap between the two constructors that the
  measurement section quantifies — the draft under `benchmarks/` names
  which claims this touches — observed 2026-08-01.
