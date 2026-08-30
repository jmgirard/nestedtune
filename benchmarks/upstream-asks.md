# Upstream asks — draft, unposted

**Status: a draft. Nothing here has been posted to `tidymodels/tune` or
`tidymodels/rsample`, and nothing should be until the maintainer decides to.**

Drafted 2026-08-30 by M28 from `cairn/references/code-inventory.md`, which owns
the inventory these asks are keyed to. Every `F0NN` below is an entry in that
page's ledger. Read against tune v2.1.0 (commit `4c74638`) and rsample v1.3.2
(commit `658545c`).

## What these asks are for

nestedtune continues as a package. It is not being wound down, ported into
`tune`, or split up, and none of these asks is a step toward any of those: they
are the ordinary requests one package in an organization makes of its siblings
once it stops guessing and reads their source. Each one names code nestedtune
carries today that a sibling could make unnecessary — either because the sibling
already does the same work behind an unexported name, or because the sibling
builds an object nestedtune has to work around. Granting all of them would leave
nestedtune with 76 of its 106 top-level functions and the same public surface;
granting none of them costs nothing but the duplication that is already there.

The asks are grouped by theme rather than one per function, because a maintainer
acts on a change, not on a list of our helper names. Every `glue` and
`resampling-layer` entry in the inventory appears under exactly one ask below,
and the one entry no upstream change retires is stated as such rather than
padded into an ask that would not do it.

---

# Asks to `tune`

## T-A1 — Expose the pre-fit argument checks, or a stable equivalent

**Retires: F001 `check_workflow()`, F002 `has_preprocessor()`,
F003 `check_model_spec()`, F006 `check_grid()`, F007 `check_grid_params()`,
F011 `check_metrics()`** — 6 functions, ~160 lines.

nestedtune validates `object`, `grid` and `metrics` before it starts a run,
because it tunes once per outer fold: a malformed grid that tune would reject per
fold surfaces here as every fold in the design failing alike, after the whole
cost has been paid. tune already makes each of these checks — `check_workflow()`
(`R/checks.R:314`), `check_installs()` over `is_installed()` (`R/checks.R:234`,
`:229`), `.check_grid()` (`R/checks.R:67`), `check_extra_tune_parameters()`
(`R/checks.R:361`), `check_metrics()` (`R/checks.R:397`) — all unexported.

The ask: export them, or export one entry point that validates a
`(workflow, grid, metrics)` triple up front and returns the expanded grid. A
caller that loops over resamples needs these answers before the loop, not inside
it.

One of the six is a `workflows` question wearing a tune coat. F002 exists because
`workflows` has an unexported `has_spec()` and `:::` is a check failure, so
nestedtune asks the workflow's structure directly. tune's own
`.has_preprocessor()` family (`R/grid_helpers.R:116-139`) is the same workaround
one package further in; the durable fix is for `workflows` to export the
predicates, and the tune-side ask stands either way.

## T-A2 — Record the expanded grid on a `tune_results`

**Retires: F070 `scored_candidates()`, F071 `scored_candidates_impl()`,
F072 `scored_metric_frames()`, F073 `empty_candidates()`** — 4 functions,
~68 lines, and one documented limitation nestedtune cannot fix from outside.

A returned `tune_results` carries `parameters`, `metrics`, `outcomes` and
`rset_info`, and none of them is the grid the run expanded. tune has it: the
expansion happens in `.check_grid()` (`R/checks.R:67`, reaching
`dials::grid_space_filling()` at `:145`) and the result is bound at
`R/tune_grid.R:375`, live for the whole run — and then discarded.

nestedtune needs it, because with the default `grid = 10` and any continuous
parameter the expansion is stochastic and each outer fold tunes under its own
seed, so the folds genuinely search different menus. A user comparing what each
fold selected is entitled to know that. Lacking the record, nestedtune
reconstructs it by pooling the per-resample metric frames and de-duplicating on
`.config`.

The reconstruction has a hole that only tune can close: **a candidate that failed
on every inner resample leaves no metric row anywhere and cannot be recovered.**
It is absent from the reconstructed record and present only in the notes. That is
not a bug we can fix; it is the consequence of deriving the grid from what scored.

The ask: attach the expanded grid to the returned object — an attribute or a
list element, whatever fits tune's own conventions. It is data tune already holds.

## T-A3 — Export the note and metric tibble constructors

**Retires: F075 `own_note()`, F076 `tune_notes()`, F077 `bind_notes()`,
F078 `empty_notes()`, F079 `empty_metrics()`** — 5 functions, ~45 lines.

nestedtune records a per-fold note frame in tune's own shape: `location`, `type`,
`note`, `trace`. It builds that frame by hand, reads tune's notes back out
through `tune::collect_notes()`, re-tags each row with the stage it came from,
concatenates, and supplies zero-row versions for folds that produced none. tune
builds and appends the same structures internally — `new_note()`
(`R/logging.R:320`), `append_log_notes()` (`R/logging.R:282`),
`remove_log_notes()` (`:414`), `has_log_notes()` (`:274`).

The ask: export the note constructor and the append helper, and document the
zero-row shape of a notes tibble and of a metrics tibble. Any package that
composes tune results into a larger object needs to produce empty ones that
downstream `rbind`-shaped code will accept, and today it guesses at the columns.

## T-A4 — Export the parallel-backend decision

**Retires: F083 `is_mirai_installed()`, F084 `mirai_workers()`,
F085 `use_parallel()`** — 3 functions, ~18 lines.

nestedtune parallelizes over outer folds and runs inner tuning with
`control_grid(allow_par = FALSE)`, because nested parallelism oversubscribes
cores. For that to be coherent, "parallel" has to mean the same thing in both
packages, so nestedtune mirrors tune's detection: mirai installed, at least two
connected daemons. tune decides this in `mirai_installed()` (`R/parallel.R:51`),
`get_mirai_workers()` (`:87`) and `choose_framework()` (`:117`).

Mirroring is the fragile part. If tune changes its threshold, adds a backend, or
changes how it reads `mirai::status()`, nestedtune goes on using the old rule and
the two silently disagree about whether a run is parallel — and `choose_framework()`
already knows about a `future` backend nestedtune's three functions do not model
at all.

The ask: export the decision — a function returning which framework tune would
use for a given `(object, control)`. Callers should read tune's answer, not
re-derive it.

## Not retired by any ask to tune

**F061 `new_tbl()`** (`R/nested-results.R:119`, ~7 lines) builds a tibble by
setting three classes and compact row names by hand, to avoid depending on
`tibble` for the sake of a constructor. It is `glue` in the inventory's sense —
tune declares `tibble (>= 3.1.0)` in its `Imports` (`DESCRIPTION:37`), so inside
tune the dependency is already paid — but **no ask to tune retires it.** It is
retired, if ever, by nestedtune adding `tibble` to its own `Imports`, which is a
local dependency decision requiring its own gate. T-A2 and T-A3 would remove most
of its call sites (the note, metric and candidate constructors); three would
remain, in the results object and its two summarizers.

It is listed here rather than dropped so that every `glue` entry in the inventory
is accounted for, including the one whose honest answer is "nothing upstream".

---

# Asks to `rsample`

## R-A1 — Let a nested design's inner splits index the caller's frame

**Retires: F025 `nested_resamples()`, F026 `inner_resamples_from_split()`,
F027 `eval_spec()`** — 3 functions, ~138 lines, and the exported constructor
nestedtune exists to offer.

`rsample::nested_cv()` (`R/nested_cv.R:50`) evaluates the inner specification
against `as.data.frame(src)` — `inside_resample()`, `R/nested_cv.R:98-101` — so
each outer fold's inner splits reference their own materialized copy of that
fold's analysis set. Object size grows by roughly one copy of the data per outer
fold.

nestedtune's `nested_resamples()` produces the same splits and keeps only the row
indices, remapped onto the caller's single frame. It is a drop-in: the splits
select the same rows, `analysis()` and `assessment()` return identical frames
attributes included, and each inner split keeps the class and resample id rsample
gave it, so `labels()` and `add_resample_id()` behave the same.

The ask: take the remapping into `nested_cv()`, or accept it as an option. What
rsample would have to accept, concretely — this is the substance of the ask, not
a side note:

1. An index-remapping step after the inner specification runs, rewriting `in_id`,
   `out_id` and `data` on each inner split.
2. An explicit `out_id` where `nested_cv()` currently leaves `NA`. It can leave it
   `NA` because its inner splits index a frame that *is* the analysis set, so the
   complement is derivable; remapped splits index the whole data, where the
   complement would sweep in the outer fold's assessment rows.
3. A recomputed `fingerprint` for the remapped splits, since the inherited one
   describes rsample's indices.

## R-A2 — Validate the design `nested_cv()` builds, and refuse an outer bootstrap

**Retires: F004 `check_nested()`, F005 `check_column_class()`,
F008 `check_inside_spec()`** — 3 functions, ~104 lines.

`nested_cv()` builds a design whatever `inside` returned: `R/nested_cv.R:88`
assigns `map(outside$splits, inside_resample, ...)` with no check on the result.
A specification that produces something other than an `rset` therefore yields a
design that constructs cleanly and cannot be run, and complains only inside a
driver, one fold at a time, as that driver's per-fold notes rather than as the
call error it is. nestedtune checks the two columns' element classes up front for
exactly that reason.

The ask has two halves, and the second is the harder one.

**The easy half:** validate `inner_resamples` at construction, and validate that
`splits` holds `rsplit` objects.

**The half that is a breaking change:** `nested_cv()` **warns** on an outer
bootstrap — `warn(boot_msg)` at `R/nested_cv.R:71` and `:77` — where nestedtune
**refuses**. The same observation can land in both the inner analysis and the
inner assessment set, which makes the nested estimate invalid rather than merely
unusual. We would ask rsample to turn that warning into an error. We recognize
what that means for a released surface, and we are not asking for it lightly;
a deprecation cycle would be the obvious path. Where rsample declines, nestedtune
keeps refusing at its own door and this ask reduces to the easy half.

## R-A3 — Offer a way to re-run a design's stored inner specification

**Retires: F009 `eval_inside_spec()`** — 1 function, ~39 lines.

`nested_cv()` stores the inner specification unevaluated —
`attr(out, "inside") <- cl$inside`, `R/nested_cv.R:93` — and that storage is what
makes a final fit possible at all: the procedure the nested estimate describes
can be run again on the whole dataset. But rsample exposes nothing that runs it,
so every consumer writes the re-evaluation itself.

The ask: an accessor, or a helper that re-evaluates the stored call against a
given frame. With it comes the scoping contract, which the helper should state
because the attribute alone does not: the stored call travels without its
environment, so it resolves wherever the caller stands now. A specification
written as `vfold_cv(v = k)` therefore resolves to whatever `k` means at
re-evaluation time — to a different design if `k` changed, and to an error if `k`
is gone. Only the second case is detectable. Documenting that literals are
required is part of the ask.

## R-A4 — The frame an rset indexes: an accessor, an invariant, and a detach/restore pair

**Retires: F028 `split_data()`, F090 `is_fold_payload()`,
F091 `lean_payload()`, F092 `rehydrate_payload()`** — 4 functions, ~63 lines.

This is one theme with three requests, in increasing order of how much rsample
would have to commit to.

**The accessor.** rsample exports `analysis()` (`R/rsplit.R:113`),
`assessment()` (`R/rsplit.R:133`) and `complement()` (`R/complement.R:22`), all of
which return *subsets*, and nothing that returns the frame the indices refer to.
nestedtune reads `x$splits[[1]]$data` directly. The ask: a data accessor on an
`rset` or `rsplit`.

**The invariant.** That accessor only makes sense alongside a documented promise
nestedtune already depends on: every split in an rset shares one data frame, so
the first split answers for all of them. Today that is an implementation detail we
read off the structure. The ask: make it a documented invariant, or say plainly
that it is not one.

**The detach/restore pair, and the predicate that guards it.** Every `rsplit`
carries the whole frame it indexes. In memory those are one shared copy — that is
what R-A1 achieves — but R's serializer does not preserve sharing for ordinary
objects, so each split writes its own copy onto the wire. Measured on this
package's own fixture at `v = 5, inner_v = 5`: six copies, 5,141,166 B against
840,540 B of actual data. `lobstr::obj_size()` reports 946.94 kB for that same
payload and so cannot see the problem at all, which is why it goes unnoticed.

Anyone dispatching resamples to workers hits this. The ask: a supported way to
detach a split's data before serialization and restore it after — with the exact
discipline, because it is easy to get wrong. `x["data"] <- list(NULL)` blanks the
element; `x$data <- NULL` **deletes** it, and the restored object then carries
`data` in last position instead of its own, so a round trip is merely equivalent
rather than `identical()`. And it needs a predicate answering whether a given
collection of splits really does share one frame: a `manual_rset()` of splits over
different frames does not, and restoring one frame onto all of them would train on
the wrong rows silently.

## R-A5 — `labels()` for a nested design, and for a repeated one

**Retires: F067 `fold_ids()`** — 1 function, ~7 lines.

`labels.rset()` (`R/labels.R:14-17`) opens by refusing this case outright:

```r
if (inherits(object, "nested_cv")) {
  cli_abort("{.arg labels} not implemented for nested resampling")
}
```

so nestedtune labels its outer folds by grepping the `^id` columns and pasting
them. The paste is not incidental: a repeated design carries `id` and `id2`, and
`labels.rset()`'s non-nested branch returns `object$id` alone, which would
silently collapse the repeats.

The ask: a `labels()` method for a nested design, and a stated rule for combining
more than one id column.

## Also raised, from the inventory's `ambiguous` entries

Not a retirement ask — these are entries the inventory could not place, where an
upstream change would settle them.

- **F059 `outer_scheme_label()`** (`R/nested-results.R:48`, ~9 lines).
  `pretty.nested_cv()` (rsample `R/printing.R:112`) describes both resampling
  levels at once. A results object printing a header needs the outer level alone,
  so nestedtune strips the nested classes and calls `pretty()` on what is left.
  A single-level scheme label for a nested design would delete this function and
  the class-stripping with it.

---

## What this list does not ask for

- No ask here proposes moving nestedtune's outer loop, its per-fold
  reproducibility contract, its failure containment, its final-fit path, or its
  daemon pre-flight into either package. Those are the 32 `core` entries in the
  inventory, and they stay here.
- No ask proposes moving nestedtune's public surface — its print, plot, collect
  and extract methods. Those are the 38 `furniture` entries, and they stay here
  too.
- Nothing here is a request that either package take on maintenance of nestedtune.
