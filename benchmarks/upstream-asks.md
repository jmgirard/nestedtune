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
already does the same work behind a name it will not promise, or because the
sibling builds an object nestedtune has to work around. The asks reach 28
functions: all 16 the inventory buckets `glue` and all 12 it buckets
`resampling-layer`. Twenty-seven of those go entirely; `check_nested()`
survives R-A2 in part, three of its refusals being nestedtune's own concern
(see there, where it is listed by number). So granting every ask leaves nestedtune with **79 of its 106
top-level functions**, one of them a thinner `check_nested()`. It would change
the public surface in exactly one place: R-A1 takes the memory-lean nested
constructor into rsample, and `nested_resamples()` is an exported function of
this package, so that ask — and only that ask — retires something users call by
name. Granting none of them costs nothing but the duplication that is already
there.

The asks are grouped by theme rather than one per function, because a maintainer
acts on a change, not on a list of our helper names. Every `glue` and
`resampling-layer` entry in the inventory appears under exactly one ask below.

**One correction worth stating up front, because it changes what most of these
asks are.** An earlier draft asked tune to *export* helpers it turns out to
export already. The inventory now rests on a sweep of tune's whole 152-name
`export()` surface at v2.1.0 rather than on the symbols it happened to cite, and
that sweep finds **twelve** relevant symbols already exported: `check_workflow`
(:191), `.has_preprocessor` (:157), `.has_spec` (:161), `.check_grid` (:136),
`check_metrics` (:186), `check_metrics_arg` (:187), `choose_framework` (:193),
`get_mirai_workers` (:237), `mirai_installed` (:265),
`.config_key_from_metrics` (:138), `load_pkgs` (:247), and `new_bare_tibble`
(:267). Every one carries `#' @keywords internal`, documented under
`empty_ellipses`, `internal-parallel`, `choose_metric`, or its own block.

So the code is callable today and the thing missing is not visibility but a
promise. **Almost nothing here is an export request.** Where the promise is the
whole story, the ask asks for the promise. Where nestedtune's version also does
something tune's does not, the inventory moved the entry out of `glue` into
`ambiguous` and it is not claimed as a retirement here.

---

# Asks to `tune`

## T-A1 — Promise the developer-facing helpers nestedtune duplicates

**Retires: F002 `has_preprocessor()`, F003 `check_model_spec()`,
F011 `check_metrics()`, F061 `new_tbl()`** — 4 functions, ~38 lines.

nestedtune validates `object`, `grid` and `metrics` before it starts a run,
because it tunes once per outer fold: a malformed grid that tune would reject per
fold surfaces here as every fold in the design failing alike, after the whole
cost has been paid. A caller that loops over resamples needs these answers before
the loop, not inside it.

tune makes each of these checks, and the ask splits by whether we may call it.

**Exported, but not promised.** `.has_preprocessor()` (`R/grid_helpers.R:116`,
`NAMESPACE:157`) and `check_metrics_arg()` (`R/metric-selection.R:307`,
`NAMESPACE:187`) both do exactly what nestedtune's F002 and F011 do. They are
exported with `#' @keywords internal`, under doc blocks whose own text calls them
developer-facing. A package on CRAN cannot put its argument checking on a surface
its dependency has said it may change. The ask is not to export them — it is to
say which of these developer-facing helpers a downstream package may depend on,
and to deprecate rather than remove them. A short "these are stable for
downstream use" note in `empty_ellipses` and `choose_metric` would do it.

**The engine-package check is reachable too, by another name.**
`check_installs()` over `is_installed()` (`R/checks.R:234`, `:229`) is indeed
unexported — but `load_pkgs()` (`R/load_ns.R:11`, `NAMESPACE:247`) is exported,
and its `model_spec` method asks `required_pkgs()` and refuses through
`.load_namespace()` (`:41`, also exported), which aborts naming the packages that
could not be loaded. That is F003's whole job. It loads rather than only
checking, and it adds tune's infra packages — neither of which matters at a
pre-fit check, since tune loads them a moment later anyway. So there is nothing
to export here either: `load_pkgs` carries `#' @keywords internal`
(`R/load_ns.R:9`), and the ask is the same promise as above.

**The same promise retires a constructor, not just checks.** F061 `new_tbl()`
builds a bare tibble by hand — three classes and compact row names — to avoid
taking a `tibble` dependency for the sake of a constructor. tune exports
`new_bare_tibble()` (`R/utils.R:82`, `NAMESPACE:267`), which is
`vctrs::new_data_frame()` then `tibble::new_tibble()`: the same object, from a
caller that needs no `tibble` of its own. It is `@keywords internal` in this very
block (`R/utils.R:80`), so it is retired by this ask and by nothing else
upstream. It is listed here rather than under a heading of its own because the
promise that reaches it is this one.

**The convenient shape, if tune wants one.** A single entry point that validates
a `(workflow, grid, metrics)` triple up front and returns the expanded grid would
cover all of the above and T-A2's need at once.

F002 is also a `workflows` question wearing a tune coat: `workflows` has an
unexported `has_spec()` and `:::` is a check failure, so both nestedtune and tune
ask the workflow's structure directly. tune's `.has_preprocessor()` family
(`R/grid_helpers.R:116-139`) is the same workaround one package further in; the
durable fix is for `workflows` to export the predicates, and the tune-side ask
stands either way.

Three checks nestedtune makes are **not** claimed here. `check_workflow()`
(F001), `check_grid()` (F006) and `check_grid_params()` (F007) each overlap a
tune counterpart but also do something it does not — refusing an already-fitted
workflow, naming the user's call, and front-loading once per design what tune
raises per fold. The inventory buckets them `ambiguous` for that reason, and no
promise from tune retires them whole.

## T-A2 — Record the expanded grid on a `tune_results`

**Retires: F070 `scored_candidates()`, F071 `scored_candidates_impl()`,
F072 `scored_metric_frames()`, F073 `empty_candidates()`** — 4 functions,
~68 lines, and one documented limitation of deriving the grid from what scored.

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

The reconstruction has a hole: **a candidate that failed on every inner resample
leaves no metric row anywhere and cannot be recovered.** It is absent from the
reconstructed record and present only in the notes. That is the consequence of
deriving the grid from what scored, and it does not go away by trying harder from
outside.

**tune already exports the reconstruction, and this ask is honest about it.**
`.config_key_from_metrics()` (`R/collect.R:618`, `NAMESPACE:138`) does what
`scored_candidates_impl()` does: it keeps the tibble `.metrics`, unchops them,
selects the tuning parameter names plus `.config`, and returns the unique rows.
nestedtune could call it today and delete all four functions. Two neighbours in
the same block reach the same end differently — `.check_grid()`
(`NAMESPACE:136`) would let nestedtune expand each fold's grid itself and hand
the frame to `tune_grid()`, retiring the hole as well, and
`estimate_tune_results()` (`R/collect.R:645`) sits there too.

What every one of those costs is the same thing: they are `@keywords internal`
members of `empty_ellipses`, so the outer loop's record of what it searched would
rest on a surface tune reserves the right to change. That is T-A1's ask, not a
separate one — which is why this ask is *not* "export something". It is either
of two things, in preference order: attach the expanded grid to the returned
object — an attribute or a list element, whatever fits tune's own conventions,
since it is data tune already holds, and it is the only route that also closes
the hole above — or, failing that, let T-A1's promise cover
`.config_key_from_metrics()` and `.check_grid()`, and nestedtune deletes these
four and keeps the hole.

## T-A3 — Export the note and metric tibble constructors

**Retires: F075 `own_note()`, F077 `bind_notes()`, F078 `empty_notes()`
outright, and F079 `empty_metrics()` and F076 `tune_notes()` conditionally** —
5 functions, ~45 lines, of which ~21 (F076 and F079) depend on how far tune wants
to go. See the three parts below.

nestedtune records a per-fold note frame in tune's own shape: `location`, `type`,
`note`, `trace`. It builds that frame by hand, reads tune's notes back out
through `tune::collect_notes()`, re-tags each row with the stage it came from,
concatenates, and supplies zero-row versions for folds that produced none. tune
builds and appends the same structures internally — `new_note()`
(`R/logging.R:320`), `append_log_notes()` (`R/logging.R:282`),
`remove_log_notes()` (`:414`), `has_log_notes()` (`:274`).

The ask has three parts, and only the first is an export request — the sweep
found no exported counterpart for any of this, unlike T-A1 and T-A2.

1. **Export `new_note()` and `append_log_notes()`** (`R/logging.R:320`, `:282`).
   Neither is in tune's `NAMESPACE`. These retire F075 `own_note()` and F078
   `empty_notes()` outright — `new_note()`'s own defaults are what
   `empty_notes()` hand-builds.
2. **Document the zero-row shape of a notes tibble and of a metrics tibble.**
   Any package composing tune results into a larger object must produce empty
   ones that downstream `rbind`-shaped code accepts, and today it guesses at the
   columns. Documenting the shape does not delete F079 `empty_metrics()` — the
   constructor still has to be written — but it makes writing it correct rather
   than inferred, and a zero-row constructor alongside `new_note()` would delete
   it.
3. **A stage-tagging hook, or nothing.** F076 `tune_notes()` reads notes back
   through `tune::collect_notes()` and re-tags each row as
   `paste0(stage, inner_id, ": ", notes$location)`, because a nested run needs to
   say which loop and which inner resample a note came from.
   `append_log_notes()` takes a raw result's notes and a plain `location`, so it
   does not cover the re-tagging. If tune has no appetite for a location
   convention that composes, F076 stays here, and this ask retires four of the
   five rather than all five.

## T-A4 — Promise the parallel-backend decision

**Retires: F083 `is_mirai_installed()`, F084 `mirai_workers()`,
F085 `use_parallel()`** — 3 functions, ~18 lines.

nestedtune parallelizes over outer folds and runs inner tuning with
`control_grid(allow_par = FALSE)`, because nested parallelism oversubscribes
cores. For that to be coherent, "parallel" has to mean the same thing in both
packages, so nestedtune mirrors tune's detection: mirai installed, at least two
connected daemons. tune decides this in `mirai_installed()` (`R/parallel.R:51`),
`get_mirai_workers()` (`:87`) and `choose_framework()` (`:117`, applying the
two-worker threshold at `:146-147`).

**All three are already exported** — `NAMESPACE:265`, `:237`, `:193`. So this is
not an export request; nestedtune could read tune's answer today. All three sit
in the `internal-parallel` doc block under `#' @keywords internal`, which is tune
reserving the right to change them, and a package whose parallel behaviour must
agree with tune's cannot build on a surface held open like that.

Mirroring is the fragile half either way. If tune changes its threshold, adds a
backend, or changes how it reads `mirai::status()`, nestedtune goes on using the
old rule and the two silently disagree about whether a run is parallel — and
`choose_framework()` already knows about a `future` backend nestedtune's three
functions do not model at all.

The ask: promise `choose_framework()` — say that a downstream package may call it
to learn which framework tune would use for a given `(object, control)`, and that
its removal would go through a deprecation cycle. Nothing needs to be written.

That retires F084 and F085 and most of F083, but not all of it, and the ask
should not claim otherwise. `is_mirai_installed()` has a second caller inside
this package: `pool_is_cancellable()` (`R/parallel.R:47`, an inventory `core`
entry) asks the plain question "is mirai installed at all", which
`choose_framework()`'s return value cannot answer — it names a framework, not an
installation. Promising `mirai_installed()` (`NAMESPACE:265`) alongside
`choose_framework()` closes that too, and both sit in the same
`internal-parallel` block, so it is one promise covering the block rather than
two asks. `choose_framework()` also knows about a `future` branch nestedtune's
three functions do not model at all, which is a second reason to read tune's
answer rather than mirror its rule.

## T-A5 — Keep the `nested_cv` refusal top-level (a request to change nothing)

**Retires nothing.** This is the one ask on the list that asks tune to hold still
rather than to move, and `cairn/DECISIONS.md` records its substance as live.
D-025 supersedes D-024 clause (2) in form — "Clause (2) is superseded rather than
confirmed: it framed the alternative to retirement as staying an outside
companion, and organization membership is a third shape it did not anticipate"
(`DECISIONS.md:741-743`) — while keeping what it asked of tune: "What clause (2)
asked of tune still holds and costs tune nothing … but it is now an ask between
packages in one organization rather than across a boundary" (`:743-747`).

`check_rset()` (`R/checks.R:4`, `NAMESPACE:189`) refuses a `nested_cv` at the top
level — `R/checks.R:19-21` — and `tune_grid()` calls it once on `resamples`
(`R/tune_grid.R:360`), as does `tune_bayes()` (`R/tune_bayes.R:322`). Each element
of an `inner_resamples` column is an ordinary `rset` and passes that check, which
is precisely what makes nestedtune's outer loop possible: it hands tune one inner
`rset` per outer fold and tune tunes it without knowing it sits inside a nested
design.

The ask: keep the refusal where it is. If nested support ever lands in tune, let
it be additive rather than a change to what `check_rset()` accepts of an ordinary
`rset`. This costs tune no new API and no commitment beyond not regressing, and
it is the only thing D-024 ever asked for.


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

**Retires: F005 `check_column_class()`, F008 `check_inside_spec()`, and the
larger part of F004 `check_nested()`** — 3 functions, ~104 lines, of which
roughly 30 stay behind. Granting this ask removes F004's element-class checks
(`R/checks.R:160-175`) and its bootstrap refusal (`:141-152`). Three of its
refusals survive it: a `resamples` that is not a data frame or lacks the two
columns (`:109-120`), a design with no outer folds (`:121-123`), and a design
with no `^id` column (`:127-136`) — that last one exists because this package's
own results object labels its rows from those columns, which is nestedtune's
concern and not rsample's. A caller has to check the argument it was handed
whatever rsample's constructor promises about the objects it built itself.

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

## R-A5 — `labels()` for a nested design

**Retires: F067 `fold_ids()`** — 1 function, ~7 lines.

Two methods refuse this case outright, with the same three lines —
`labels.rset()` (`R/labels.R:15-17`) and `labels.vfold_cv()` (`:28-30`):

```r
if (inherits(object, "nested_cv")) {
  cli_abort("{.arg labels} not implemented for nested resampling")
}
```

so nestedtune labels its outer folds by grepping the `^id` columns and pasting
them.

rsample already has the combining rule, which an earlier draft of this list
missed: `labels.vfold_cv()` pastes `id` and `id2` with a `.` when
`attr(object, "repeats") > 1` (`R/labels.R:31-36`), and a repeated design
dispatches there. So the ask is narrower than it looked.

The ask: let `labels()` answer for a nested design instead of aborting, reusing
the repeat-handling `labels.vfold_cv()` already performs. Only the outer level
needs labelling; the inner `rset`s are ordinary and already answer for
themselves.

---

## Also raised, from the inventory's `ambiguous` entries

Not retirement asks. These are entries the inventory could not place in a single
bucket, listed here because an upstream change above would settle part of what
each one is. They belong to both packages, which is why they sit outside the two
sections rather than inside either.

- **F059 `outer_scheme_label()`** (`R/nested-results.R:48`, ~9 lines).
  `pretty.nested_cv()` (rsample `R/printing.R:112`) describes both resampling
  levels at once. A results object printing a header needs the outer level alone,
  so nestedtune strips the nested classes and calls `pretty()` on what is left.
  A single-level scheme label for a nested design would delete this function and
  the class-stripping with it.
- **F001 `check_workflow()`, F006 `check_grid()`, F007 `check_grid_params()`**
  (`R/checks.R:7`, `:204`, `:234`; ~129 lines together). T-A1's promise would let
  the duplicated half of each go: the workflow-shape questions tune's own
  `check_workflow()` asks, and the grid validation `.check_grid()` performs. What
  stays is what tune's versions do not do — refuse an already-fitted workflow,
  name the user's call in the abort, and answer once per design rather than once
  per fold. That is why the inventory buckets these `ambiguous` and why they are
  not counted as retired anywhere above.

## What this list does not ask for

- No ask here proposes moving nestedtune's outer loop, its per-fold
  reproducibility contract, its failure containment, its final-fit path, or its
  daemon pre-flight into either package. Those are the 32 `core` entries in the
  inventory, and they stay here.
- No ask proposes moving nestedtune's print, plot, collect or extract methods.
  Those are the 38 `furniture` entries, and they stay here too. R-A1 is the one
  ask that touches an exported name at all: it would take the memory-lean
  constructor `nested_resamples()` into rsample.
- No ask claims one of the 8 `ambiguous` entries as a retirement. Four of them
  appear above only to say which half an upstream change would reach.
- Nothing here is a request that either package take on maintenance of nestedtune.
