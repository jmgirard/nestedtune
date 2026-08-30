# What we keep, what is only glue, and what belongs to rsample (M28)

**Provenance.** Ingested 2026-08-30 by M28 from this repository's own `R/`
directory at commit `89d8418`, classified against two upstream source trees
read-only outside this repo: `tidymodels/tune` at tag `v2.1.0` (commit
`4c74638`) and `tidymodels/rsample` at tag `v1.3.2` (commit `658545c`), the
versions installed in the development library on the day of the read.
Pagination: —.
Extraction: read directly from `R/*.R` at `89d8418` and from the two upstream trees named above — observed 2026-08-30.

**Scope.** This is an inventory of this package's own R code, sorted by where
each definition would live in a world without package boundaries. It is not a
summary of any external source, and it builds no argument that this package
should or should not continue: `cairn/DECISIONS.md` settled that separately and
this page takes it as given. It also proposes nothing upstream — the asks
drafted from it live in `benchmarks/upstream-asks.md`, unposted. It is a
reference, not an authority: status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

**Evidence snapshot.**

- Every top-level function definition in `R/*.R`, emitted by the extraction
  procedure stated below — commit `89d8418`, 106 definitions across 10 of the 12 files in `R/` —
  observed 2026-08-30.
- `NAMESPACE` at the same commit — 8 `export()` lines, 10 `S3method()` lines —
  observed 2026-08-30.
- `tidymodels/tune` source tree at tag `v2.1.0`, commit `4c74638`, shallow clone
  outside this repository — observed 2026-08-30.
- `tidymodels/rsample` source tree at tag `v1.3.2`, commit `658545c`, shallow
  clone outside this repository — observed 2026-08-30.
- Installed versions in the development library: tune 2.1.0, rsample 1.3.2,
  reported by `packageVersion()` — observed 2026-08-30.
- The complete `export()` surface of both upstream trees — tune 152 names,
  rsample 62 — read against every entry this page does not bucket `core` or
  `furniture`, by the sweep procedure stated below — observed 2026-08-30.

## What the inventory is

### The extraction procedure

Every entry in the ledger below comes from one command, run from the repository
root:

```
grep -nE '^[A-Za-z._][A-Za-z0-9._]* <- function' R/*.R
```

It emits 106 lines. The pattern anchors at column one, so it finds top-level
definitions and not the anonymous and nested functions that make `R/*.R` carry
153 occurrences of `function(` in total. It also requires the name to start with
a letter, a dot, or an underscore, which is what excludes the one backtick-quoted
definition in the package; that definition is carried as an addendum below rather
than silently lost.

Each entry carries its `file:line`, its export status read from `NAMESPACE`
(`exported`, `S3 method (registered)`, or `internal`), an approximate line count
taken from the definition line to the closing brace at column one, and exactly
one bucket. Bucket assignment is a judgment, so it is held as a separate
name-to-bucket list and merged against the extraction output by a script that
refuses to run unless the two name sets are equal — a definition cannot be
dropped, duplicated, or left unbucketed on the way into the table.

### The five buckets

- **`core`** — logic this package carries regardless of where it lives. The
  outer loop, the per-fold reproducibility contract, failure containment, the
  final-fit path, the daemon pre-flight.
- **`glue`** — code that exists only because this package sits outside `tune`.
  Each such entry names, below, the fact about being inside tune that would make
  it unnecessary.
- **`resampling-layer`** — code whose natural home is the resampling layer,
  whether or not it is ever proposed there. Each names what `rsample`'s own
  surface would have to accept.
- **`furniture`** — the user-facing surface this package owns: its print, plot,
  collect and extract methods, and the helpers that serve only them.
- **`ambiguous`** — an entry that resists a single bucket, with the reason
  stated rather than a bucket forced onto it.

### The upstream-counterpart sweep

The `glue`, `resampling-layer` and `ambiguous` entries each rest on a claim about
what upstream does and does not offer. Two earlier passes of this page checked
those claims one entry at a time, against the symbols the entry happened to cite,
and both times a reviewer found a counterpart nobody had thought to look for. A
per-entry check cannot fail safely: it is bounded by what the author recalled,
not by what upstream exports.

So the claims rest instead on a sweep over the whole surface, stated here so a
later pass re-runs it rather than hunting fresh:

```
grep -oE '^export\(([^)]+)\)' NAMESPACE   # in each upstream tree
```

That emits 152 names for tune at `4c74638` and 62 for rsample at `658545c`. Both
lists were then **read** — not matched by name — against the 36 entries this page
buckets `glue` (16), `resampling-layer` (12) or `ambiguous` (8), asking of each
upstream name whether it does the work the entry does. A name match is not the
test and would have missed two of the three hits below: `new_bare_tibble` against
`new_tbl`, and `load_pkgs` against `check_model_spec`.

Run 2026-08-30, the sweep found three counterparts this page had missed, all
three exported and all three in the `empty_ellipses` doc block:

- `.config_key_from_metrics` (tune `R/collect.R:618`) — the candidate
  reconstruction F070–F073 perform.
- `load_pkgs` (tune `R/load_ns.R:11`) over `.load_namespace` (`:41`) — the
  engine-package refusal F003 performs.
- `new_bare_tibble` (tune `R/utils.R:82`) — the tibble construction F061
  performs.

It found none on the rsample side. The two constructors that came closest —
`make_splits()` (`R/misc.R:18`) and `new_rset()` (`R/rset.R:14`) — are declined
for a stated reason in this repo's own comment at `R/nested-resamples.R:160-164`:
rebuilding the splits from scratch drops the split subclass and the per-split
`id` tibble that `labels()` reads. `populate()` (`R/complement.R:126`) fills a
split's `out_id`, but in that split's own index space, not the outer-fold space
F026 remaps into.

The three hits are folded into the entries below. What the sweep does not settle
is behavioural equivalence beyond the reading: it establishes that a counterpart
exists and what it does, not that swapping it in would leave every test green.

## Ledger — all 106 definitions

| # | Definition | Location | Export status | Lines | Bucket |
|---|---|---|---|---|---|
| F001 | `check_workflow()` | `R/checks.R:7` | internal | ~65 | ambiguous |
| F002 | `has_preprocessor()` | `R/checks.R:82` | internal | ~3 | glue |
| F003 | `check_model_spec()` | `R/checks.R:91` | internal | ~16 | glue |
| F004 | `check_nested()` | `R/checks.R:108` | internal | ~70 | resampling-layer |
| F005 | `check_column_class()` | `R/checks.R:185` | internal | ~18 | resampling-layer |
| F006 | `check_grid()` | `R/checks.R:204` | internal | ~23 | ambiguous |
| F007 | `check_grid_params()` | `R/checks.R:234` | internal | ~41 | ambiguous |
| F008 | `check_inside_spec()` | `R/checks.R:285` | internal | ~16 | resampling-layer |
| F009 | `eval_inside_spec()` | `R/checks.R:312` | internal | ~39 | resampling-layer |
| F010 | `check_plot_type()` | `R/checks.R:357` | internal | ~21 | furniture |
| F011 | `check_metrics()` | `R/checks.R:379` | internal | ~12 | glue |
| F012 | `extract_tune_results()` | `R/nested-final-fit-extract.R:75` | exported | ~3 | furniture |
| F013 | `extract_tune_results.default()` | `R/nested-final-fit-extract.R:80` | S3 method (registered) | ~7 | furniture |
| F014 | `extract_tune_results.nested_final_fit()` | `R/nested-final-fit-extract.R:89` | S3 method (registered) | ~3 | furniture |
| F015 | `extract_scored_candidates()` | `R/nested-final-fit-extract.R:145` | exported | ~3 | furniture |
| F016 | `extract_scored_candidates.default()` | `R/nested-final-fit-extract.R:150` | S3 method (registered) | ~6 | furniture |
| F017 | `extract_scored_candidates.nested_final_fit()` | `R/nested-final-fit-extract.R:158` | S3 method (registered) | ~6 | furniture |
| F018 | `abort_no_extract_method()` | `R/nested-final-fit-extract.R:170` | internal | ~11 | furniture |
| F019 | `print.nested_final_fit()` | `R/nested-final-fit-print.R:30` | S3 method (registered) | ~21 | furniture |
| F020 | `selected_label()` | `R/nested-final-fit-print.R:56` | internal | ~9 | furniture |
| F021 | `nested_final_fit()` | `R/nested-final-fit.R:174` | exported | ~26 | core |
| F022 | `final_fit_worker()` | `R/nested-final-fit.R:213` | internal | ~28 | core |
| F023 | `new_nested_final_fit()` | `R/nested-final-fit.R:251` | internal | ~12 | core |
| F024 | `extract_workflow.nested_final_fit()` | `R/nested-final-fit.R:266` | S3 method (registered) | ~3 | furniture |
| F025 | `nested_resamples()` | `R/nested-resamples.R:60` | exported | ~71 | resampling-layer |
| F026 | `inner_resamples_from_split()` | `R/nested-resamples.R:138` | internal | ~49 | resampling-layer |
| F027 | `eval_spec()` | `R/nested-resamples.R:197` | internal | ~18 | resampling-layer |
| F028 | `split_data()` | `R/nested-resamples.R:218` | internal | ~3 | resampling-layer |
| F029 | `autoplot.nested_results()` | `R/nested-results-plot.R:81` | S3 method (registered) | ~12 | furniture |
| F030 | `plot_selection()` | `R/nested-results-plot.R:94` | internal | ~31 | furniture |
| F031 | `value_scale()` | `R/nested-results-plot.R:141` | internal | ~15 | furniture |
| F032 | `panel_breaks()` | `R/nested-results-plot.R:157` | internal | ~13 | furniture |
| F033 | `panel_owner()` | `R/nested-results-plot.R:187` | internal | ~20 | furniture |
| F034 | `whole_number_breaks()` | `R/nested-results-plot.R:208` | internal | ~5 | furniture |
| F035 | `plot_performance()` | `R/nested-results-plot.R:214` | internal | ~65 | furniture |
| F036 | `design_line()` | `R/nested-results-plot.R:286` | internal | ~7 | furniture |
| F037 | `qualify_panels()` | `R/nested-results-plot.R:297` | internal | ~8 | furniture |
| F038 | `from_folds()` | `R/nested-results-plot.R:309` | internal | ~3 | furniture |
| F039 | `chose_value()` | `R/nested-results-plot.R:313` | internal | ~3 | furniture |
| F040 | `metric_panel()` | `R/nested-results-plot.R:320` | internal | ~7 | furniture |
| F041 | `ambiguous_metrics()` | `R/nested-results-plot.R:328` | internal | ~4 | furniture |
| F042 | `selection_frame()` | `R/nested-results-plot.R:340` | internal | ~36 | furniture |
| F043 | `selection_raw()` | `R/nested-results-plot.R:386` | internal | ~12 | furniture |
| F044 | `selection_axis()` | `R/nested-results-plot.R:407` | internal | ~22 | furniture |
| F045 | `print.nested_results()` | `R/nested-results-print.R:59` | S3 method (registered) | ~18 | furniture |
| F046 | `print_design()` | `R/nested-results-print.R:78` | internal | ~10 | furniture |
| F047 | `print_failures()` | `R/nested-results-print.R:89` | internal | ~14 | furniture |
| F048 | `fold_failure_stage()` | `R/nested-results-print.R:107` | internal | ~6 | furniture |
| F049 | `print_selection()` | `R/nested-results-print.R:114` | internal | ~25 | furniture |
| F050 | `print_candidate_sets()` | `R/nested-results-print.R:151` | internal | ~22 | furniture |
| F051 | `same_candidates()` | `R/nested-results-print.R:179` | internal | ~4 | ambiguous |
| F052 | `candidate_key()` | `R/nested-results-print.R:184` | internal | ~29 | ambiguous |
| F053 | `rendered_rows()` | `R/nested-results-print.R:215` | internal | ~14 | ambiguous |
| F054 | `selection_params()` | `R/nested-results-print.R:233` | internal | ~4 | furniture |
| F055 | `selection_values()` | `R/nested-results-print.R:246` | internal | ~18 | furniture |
| F056 | `print_one_parameter()` | `R/nested-results-print.R:275` | internal | ~32 | furniture |
| F057 | `print_estimate()` | `R/nested-results-print.R:308` | internal | ~32 | furniture |
| F058 | `new_nested_results()` | `R/nested-results.R:8` | internal | ~32 | core |
| F059 | `outer_scheme_label()` | `R/nested-results.R:48` | internal | ~9 | ambiguous |
| F060 | `has_results_columns()` | `R/nested-results.R:111` | internal | ~4 | core |
| F061 | `new_tbl()` | `R/nested-results.R:119` | internal | ~7 | glue |
| F062 | `collect_metrics.nested_results()` | `R/nested-results.R:209` | S3 method (registered) | ~10 | furniture |
| F063 | `summarize_folds()` | `R/nested-results.R:228` | internal | ~35 | core |
| F064 | `check_any_completed()` | `R/nested-results.R:269` | internal | ~17 | core |
| F065 | `warn_partial_summary()` | `R/nested-results.R:290` | internal | ~17 | core |
| F066 | `per_fold_metrics()` | `R/nested-results.R:310` | internal | ~11 | core |
| F067 | `fold_ids()` | `R/nested-results.R:324` | internal | ~7 | resampling-layer |
| F068 | `nested_tune_grid()` | `R/nested-tune-grid.R:300` | exported | ~42 | core |
| F069 | `nested_fold_fit()` | `R/nested-tune-grid.R:350` | internal | ~67 | core |
| F070 | `scored_candidates()` | `R/nested-tune-grid.R:432` | internal | ~20 | glue |
| F071 | `scored_candidates_impl()` | `R/nested-tune-grid.R:453` | internal | ~33 | glue |
| F072 | `scored_metric_frames()` | `R/nested-tune-grid.R:491` | internal | ~7 | glue |
| F073 | `empty_candidates()` | `R/nested-tune-grid.R:503` | internal | ~8 | glue |
| F074 | `failed_fold()` | `R/nested-tune-grid.R:521` | internal | ~19 | core |
| F075 | `own_note()` | `R/nested-tune-grid.R:541` | internal | ~8 | glue |
| F076 | `tune_notes()` | `R/nested-tune-grid.R:553` | internal | ~13 | glue |
| F077 | `bind_notes()` | `R/nested-tune-grid.R:567` | internal | ~8 | glue |
| F078 | `empty_notes()` | `R/nested-tune-grid.R:576` | internal | ~8 | glue |
| F079 | `empty_metrics()` | `R/nested-tune-grid.R:587` | internal | ~8 | glue |
| F080 | `warn_failed_folds()` | `R/nested-tune-grid.R:598` | internal | ~17 | core |
| F081 | `set_fold_seed()` | `R/nested-tune-grid.R:620` | internal | ~8 | core |
| F082 | `restore_rng()` | `R/nested-tune-grid.R:634` | internal | ~8 | core |
| F083 | `is_mirai_installed()` | `R/parallel.R:11` | internal | ~3 | glue |
| F084 | `mirai_workers()` | `R/parallel.R:15` | internal | ~12 | glue |
| F085 | `use_parallel()` | `R/parallel.R:28` | internal | ~3 | glue |
| F086 | `pool_is_cancellable()` | `R/parallel.R:46` | internal | ~6 | core |
| F087 | `record_dispatch()` | `R/parallel.R:62` | internal | ~4 | core |
| F088 | `last_dispatch()` | `R/parallel.R:67` | internal | ~3 | core |
| F089 | `reset_dispatch_record()` | `R/parallel.R:71` | internal | ~4 | core |
| F090 | `is_fold_payload()` | `R/parallel.R:118` | internal | ~21 | resampling-layer |
| F091 | `lean_payload()` | `R/parallel.R:140` | internal | ~18 | resampling-layer |
| F092 | `rehydrate_payload()` | `R/parallel.R:159` | internal | ~21 | resampling-layer |
| F093 | `dispatch_folds()` | `R/parallel.R:190` | internal | ~106 | core |
| F094 | `preflight_timeout()` | `R/parallel.R:320` | internal | ~21 | core |
| F095 | `daemon_symbol_manifest()` | `R/parallel.R:391` | internal | ~6 | core |
| F096 | `daemon_probe_expr()` | `R/parallel.R:420` | internal | ~11 | core |
| F097 | `daemons_load_status()` | `R/parallel.R:432` | internal | ~27 | core |
| F098 | `daemon_report()` | `R/parallel.R:478` | internal | ~12 | core |
| F099 | `preflight_outcome()` | `R/parallel.R:497` | internal | ~39 | core |
| F100 | `check_daemons_can_load()` | `R/parallel.R:543` | internal | ~137 | core |
| F101 | `warn_if_not_cancellable()` | `R/parallel.R:697` | internal | ~19 | core |
| F102 | `classify_fold_result()` | `R/parallel.R:726` | internal | ~33 | core |
| F103 | `is_cancelled_value()` | `R/parallel.R:772` | internal | ~11 | core |
| F104 | `is_fold_record()` | `R/parallel.R:784` | internal | ~6 | core |
| F105 | `worker_failure_message()` | `R/parallel.R:791` | internal | ~23 | core |
| F106 | `fold_task()` | `R/parallel.R:823` | internal | ~11 | ambiguous |

Counts: 32 `core`, 38 `furniture`, 16 `glue`, 12 `resampling-layer`,
8 `ambiguous`.

### Addendum: the one definition the procedure does not emit

`[.nested_results` (`R/nested-results.R:69`, S3 method (registered), ~37 lines,
bucket **ambiguous**) is defined as `` `[.nested_results` <- function(x, i, j, ...) ``.
The backtick is the first character of the line, so the extraction pattern —
which requires a letter, a dot, or an underscore there — does not match it. It is
listed here rather than in the table above so that the table remains exactly what
the stated procedure emits. Its reason for being `ambiguous` is given with the
other eight below, and `NAMESPACE`'s `S3method("[",nested_results)` line is
reconciled against it in the reconciliation section.

## `glue` — the tune-internal fact that removes each entry

Sixteen entries. Each names a fact about being inside `tune` that would make the
code unnecessary, cited to tune's own source at v2.1.0 (`4c74638`) unless stated
otherwise.

**What "inside tune" means when tune already exports the counterpart.** Most of
the helpers cited below are *exported* at v2.1.0, so the code is callable today
as `tune::<name>()`. The upstream-counterpart sweep above found twelve such
symbols: `check_workflow` (`NAMESPACE:191`), `.has_preprocessor` (`:157`),
`.has_spec` (`:161`), `.check_grid` (`:136`), `check_metrics` (`:186`),
`check_metrics_arg` (`:187`), `choose_framework` (`:193`), `get_mirai_workers`
(`:237`), `mirai_installed` (`:265`), and the three the sweep added —
`.config_key_from_metrics` (`:138`), `load_pkgs` (`:247`), `new_bare_tibble`
(`:267`) — each verified against the pinned clone, observed 2026-08-30. Every one
of the twelve carries `#' @keywords internal`, in its own roxygen block or in the
block its `@rdname` joins, and each is documented in one of three developer-facing
topics:

- `empty_ellipses` — `.check_grid` (`R/checks.R:65`), `check_workflow`
  (`:311`), `check_metrics` (`:391`), `.has_preprocessor`
  (`R/grid_helpers.R:114`), `.has_spec` (`:152`), `.config_key_from_metrics`
  (`R/collect.R:615`), `new_bare_tibble` (`R/utils.R:80`).
- `internal-parallel` — `mirai_installed` (`R/parallel.R:49`),
  `get_mirai_workers` (`:85`), `choose_framework` (`:114`).
- `choose_metric` — `check_metrics_arg` (`R/metric-selection.R:305`, joining the
  block whose `@keywords internal` sits at `:35` and whose own text reads "These
  are developer-facing functions used to compute and validate choices for
  performance metrics").

`load_pkgs` carries `@keywords internal` on its own block (`R/load_ns.R:9`)
without joining any of the three.

That is the fact about being inside tune, and it is not that tune hides these:
inside tune they are ordinary internal calls, while outside tune they are a
surface tune has explicitly declined to promise. The ask these entries generate
is therefore that tune *promise* the surface, not that it export it. Where a
nestedtune function does work tune's counterpart does not do at all, the entry is
not `glue` and has moved to `ambiguous` — F001, F006 and F007, below.

**Argument checks tune already performs (F002, F003, F011).**
Each fires before any fitting and duplicates, in content, a check tune makes on
the same object.

- **F002 `has_preprocessor()`** — asks whether a workflow carries a formula,
  recipe, or variables. tune's `.has_preprocessor()` (`R/grid_helpers.R:116`,
  exported at `NAMESPACE:157`) asks exactly that, over the companions
  `.has_preprocessor_recipe()`, `.has_preprocessor_formula()` and
  `.has_preprocessor_variables()` at `:125`, `:132`, `:139`. This repo's own
  comment at `R/checks.R:73-81` records why the question is asked by name rather
  than as `length(object$pre$actions) > 0L`: `workflows::add_case_weights()` also
  files an action under `pre`, so the counting form is a different question and
  passes a workflow that cannot be fitted. Inside tune the predicate is a plain
  internal call rather than a `@keywords internal` export a downstream package
  would have to bet on.
- **F003 `check_model_spec()`** — asks whether the engine's packages are
  installed and refuses, naming the missing ones. tune does this twice. Its
  `check_installs()` (`R/checks.R:234`, over `is_installed()` at `:229`) is
  unexported; but `load_pkgs()` (`R/load_ns.R:11`, `NAMESPACE:247`) is exported,
  and its `model_spec` method takes `required_pkgs(x)` — the same question this
  entry asks `parsnip::required_pkgs()` — through `.load_namespace()`
  (`R/load_ns.R:41`, also exported), which aborts with "The package{?s}
  {.pkg {bad}} could not be loaded." So the reachable counterpart exists and the
  fact here is the same one the preamble states: `load_pkgs` carries
  `#' @keywords internal` (`R/load_ns.R:9`). Two differences that do not change
  the bucket: it loads the namespaces rather than only checking them, and it adds
  tune's own infra packages to the list. Both are acceptable at a pre-fit check —
  tune loads them a moment later anyway — so this is a like-for-like duplicate of
  an unpromised export, not work tune's version fails to do.
- **F011 `check_metrics()`** — asks whether `metrics` is a `metric_set` or
  `NULL`. tune's `check_metrics()` (`R/checks.R:397`) is soft-deprecated at this
  very version — its first line is
  `lifecycle::deprecate_warn("2.1.0", "check_metrics()", "check_metrics_arg()")`
  (`R/checks.R:398`) — so the live counterpart is `check_metrics_arg()`
  (`R/metric-selection.R:307`), which performs the same validation and supplies a
  mode-appropriate default. Both are exported under `@keywords internal` —
  `check_metrics` in the `empty_ellipses` block (`R/checks.R:391`),
  `check_metrics_arg` in the `choose_metric` one (`R/metric-selection.R:305`) —
  so the fact is the promise, not the visibility.

**The candidate record tune discards (F070, F071, F072, F073).**
`scored_candidates()` and its three helpers reconstruct the set of candidates a
tuning run evaluated by pooling the per-resample metric frames and de-duplicating
on `.config`. They exist because a returned `tune_results` carries no record of
its own expansion — the fact stated in this repo's comment at
`R/nested-tune-grid.R:418-427` and measured at M21's plan gate against tune 2.1.0.
Inside tune the expansion is a local variable and never has to be recovered: the
grid is expanded by `.check_grid()` (`R/checks.R:67`, calling
`dials::grid_space_filling()` at `:145`) and bound at `R/tune_grid.R:375`, in hand
for the whole run.

  What the upstream sweep found is that tune also ships the recovery, exported.
  `.config_key_from_metrics()` (`R/collect.R:618`, `NAMESPACE:138`) takes a
  `tune_results`, keeps the tibble `.metrics`, unchops them, selects the tuning
  parameter names plus `.config`, and returns the unique rows — which is what
  `scored_candidates_impl()` does. It carries `#' @keywords internal` under
  `@rdname empty_ellipses` (`R/collect.R:615`), so these four are the preamble's
  case exactly: a like-for-like duplicate of a surface tune declines to promise,
  not of one it withholds. Two further routes rest on the same block —
  `.check_grid()` is exported (`NAMESPACE:136`), so this package could expand each
  fold's grid itself and hand the frame to `tune_grid()`; and
  `estimate_tune_results()` (`R/collect.R:645`) sits there too. That all three are
  unpromised is why the ask is a promise rather than an export.

  What nestedtune's version adds beyond the exported one is small, and none of it
  is a separate home: ordering by the key so the record does not depend on which
  inner resample scored a candidate first, a fallback for a shape carrying no
  `.config` column, and a zero-row return. What survives every route is the limit
  this repo's comment records: a candidate that fails on every inner resample
  leaves no metric row anywhere and cannot be recovered from what scored.

**Note and metric tibble assembly (F075, F076, F077, F078, F079).**
`own_note()`, `tune_notes()`, `bind_notes()`, `empty_notes()` and
`empty_metrics()` build, relabel, concatenate and zero-fill the note and metric
tibbles this package files per fold. tune builds the same structures internally:
`new_note()` at `R/logging.R:320`, `append_log_notes()` at `R/logging.R:282`,
`remove_log_notes()` at `:414`, `has_log_notes()` at `:274`. Inside tune a fold's
notes are appended through that machinery rather than rebuilt from
`tune::collect_notes()` output and re-tagged with a stage string.

**Building a tibble without depending on tibble (F061).**
`new_tbl()` sets three classes and compact row names by hand. Its own comment
(`R/nested-results.R:116-118`) says why: it saves a dependency on tibble for the
sake of a constructor. tune declares `tibble (>= 3.1.0)` in its `Imports`
(`DESCRIPTION:37`), so inside tune the dependency is already paid.

  It does not have to be paid here either, and the upstream sweep found why: tune
  exports `new_bare_tibble()` (`R/utils.R:82`, `NAMESPACE:267`), which is
  `vctrs::new_data_frame()` followed by `tibble::new_tibble()` — what `new_tbl()`
  builds, reachable by a caller that carries no `tibble` dependency of its own. It
  carries `#' @keywords internal` under `@rdname empty_ellipses`
  (`R/utils.R:80`), the same block as the checks above, so F061 is retired by the
  same promise they are — and not, as an earlier draft of this page had it, only
  by this package adding `tibble` to its own `Imports`.

**Parallel-backend detection (F083, F084, F085).**
`is_mirai_installed()`, `mirai_workers()` and `use_parallel()` decide whether a
mirai pool is usable. tune makes the same decision in `R/parallel.R`:
`mirai_installed()` at `:51`, `get_mirai_workers()` at `:87` (reading the same
`mirai::status()$connections`), and the two-worker threshold inside
`choose_framework()`, which opens at `:117` and applies the threshold at
`:146-147` (`neither <- future_workers < 2 & mirai_workers < 2`). This repo's
comment at `R/parallel.R:4-7` states the coupling directly — detection mirrors
tune's own so that "parallel" means the same thing in both packages. Inside tune
it would not be mirrored; it would be the same code, and the `future` branch
`choose_framework()` also carries would come with it.

  All three tune functions are exported (`NAMESPACE:265`, `:237`, `:193`), so the
  mirroring is a choice, not a necessity — this package could read tune's answer
  today. It is `glue` because of what those exports are: `@keywords internal`
  members of the `internal-parallel` block, which is tune saying it may change
  them. Mirroring an unpromised rule and calling an unpromised rule fail the same
  way, and only tune promising the rule ends that.

## `resampling-layer` — what rsample's surface would have to accept

Twelve entries. Each names what `rsample`'s own surface would have to accept for
the code to live there, cited to rsample's source at v1.3.2 (`658545c`) unless
stated otherwise.

**The memory-lean constructor (F025, F026, F027).**
`nested_resamples()`, `inner_resamples_from_split()` and `eval_spec()` build the
same nested design `rsample::nested_cv()` builds, but keep index vectors into the
caller's frame instead of a materialized analysis set per outer fold. rsample
would have to accept that its inner splits may index a frame other than the one
the inner specification was evaluated against. Today they cannot: `nested_cv()`
(`R/nested_cv.R:50`) delegates to `inside_resample()` (`R/nested_cv.R:98-101`),
which evaluates the inner call with `data = as.data.frame(src)` — one
materialized copy of that fold's analysis set, which the resulting splits then
index. Concretely, rsample would have to accept an index-remapping step after the
inner specification runs (rewriting `in_id`, `out_id`, and `data` on each inner
split), an explicit `out_id` where it currently leaves `NA` because the complement
is derivable from a frame that *is* the analysis set, and a recomputed
`fingerprint` for the remapped splits.

**Validating a design rsample builds without validating (F004, F005, F008).**
`check_nested()`, `check_column_class()` and `check_inside_spec()` refuse a
design whose `splits` column does not hold `rsplit` objects, whose
`inner_resamples` column does not hold an `rset` per outer fold, or which carries
no stored `inside` call to re-run. rsample would have to accept refusing designs
its own constructor currently produces. `nested_cv()` builds the design whatever
`inside` returned — `R/nested_cv.R:88` assigns `map(outside$splits,
inside_resample, ...)` with no check on the result — so a specification returning
something that is not an `rset` yields a design that cannot be run and complains
only inside a driver, one fold at a time.

  A second thing rsample would have to accept sits in the same functions:
  `check_nested()` **refuses** an outer bootstrap where `nested_cv()` only
  **warns** (`R/nested_cv.R:71` and `:77`, both reaching `warn(boot_msg)`). The
  same observation can otherwise land in both the inner analysis and the inner
  assessment set. Moving this code to rsample means rsample changing a warning
  into an error, which is a breaking change to a released surface.

**Re-running the stored specification (F009).**
`eval_inside_spec()` re-evaluates a design's stored `inside` call against a whole
dataset. rsample stores that call — `attr(out, "inside") <- cl$inside` at
`R/nested_cv.R:93` — but exposes nothing that runs it again, so every consumer
that wants the procedure re-run writes this itself. rsample would have to accept
an accessor or a re-evaluation helper on `nested_cv`, together with the scoping
contract it implies: the stored call travels without its environment, so it
resolves wherever the caller stands now.

**Reaching the frame an rset indexes (F028).**
`split_data()` reads `x$splits[[1]]$data` because there is no accessor for it.
rsample exports `analysis()` (`R/rsplit.R:113`), `assessment()`
(`R/rsplit.R:133`) and `complement()` (`R/complement.R:22`) — all of which return
*subsets* — and nothing that returns the frame the indices refer to. rsample
would have to accept a data accessor on an `rset` or `rsplit`, and with it the
invariant this package depends on and states at `R/nested-resamples.R:216-217`:
every split in an rset shares one data frame, so the first split answers for all
of them.

**Labelling a nested design's folds (F067).**
`fold_ids()` greps the `^id` columns and pastes them, because a repeated design
carries `id` and `id2`. rsample has the generic and refuses this exact case
twice: `labels.rset()` (`R/labels.R:15-17`) and `labels.vfold_cv()` (`:28-30`)
both open with `if (inherits(object, "nested_cv"))
cli_abort("{.arg labels} not implemented for nested resampling")`. The rule for
combining id columns is not the gap — `labels.vfold_cv()` already pastes `id` and
`id2` when `attr(object, "repeats") > 1` (`R/labels.R:31-36`), and a repeated
design dispatches there. What rsample would have to accept is a `labels()` method
that answers for a nested design at all, reusing the combining rule it already
has rather than refusing at the door.

**The payload trio (F090, F091, F092).**
`is_fold_payload()`, `lean_payload()` and `rehydrate_payload()` take the data out
of one fold's payload before it goes on the wire and put it back on the worker.
They exist because of a property of rsample's objects rather than of this
package: every `rsplit` carries the whole frame it indexes, and in memory those
are one shared copy, but R's serializer does not preserve sharing for ordinary
objects — so each split writes its own copy onto the wire. This repo records the
measurement at `R/parallel.R:78-84`: six copies for `v = 5, inner_v = 5`,
5,141,166 B against 840,540 B of data, and `lobstr::obj_size()` reports 946.94 kB
for that same payload and so cannot see the defect at all. rsample would have to
accept three things: that the shared-frame property is a documented invariant of
an `rset` rather than an implementation detail, that a split's `data` field may
be blanked and restored (with the exact blanking discipline — `x["data"] <-
list(NULL)` and not `x$data <- NULL`, which deletes the element and changes the
object's shape), and a predicate answering whether a given collection of splits
actually shares one frame, since a `manual_rset()` of splits over different
frames does not. Absent that last guarantee, restoring one frame onto all of them
would tune on the wrong rows.

## `ambiguous` — why each resists a single bucket

Eight entries in the ledger, plus the addendum.

- **F001 `check_workflow()`** (`R/checks.R:7`, ~65 lines). tune exports a
  `check_workflow()` of its own (`R/checks.R:314`, `NAMESPACE:191`), and three of
  this one's four refusals have a counterpart there: not a `workflow`, no
  preprocessor, no model specification. By that overlap it is `glue`. The fourth
  has no counterpart at all — this one refuses a workflow that is already fitted
  (`workflows::is_trained_workflow(object)`, `R/checks.R:20-29`), because nested
  cross-validation fits the workflow itself once per outer fold, and tune's
  version has no such branch. Every abort here also carries `call` so it names the
  user's call rather than an internal one, which the comment at `R/checks.R:30-36`
  gives as the reason the model-spec question is asked before
  `extract_spec_parsnip()`. That residue is `core`: it is GP3's refuse-a-provably-
  invalid-design rule, stated at the head of the file. Bucketing it `glue` would
  also carry a "~65 lines retired" figure that no upstream change reaches.
- **F006 `check_grid()`, F007 `check_grid_params()`** (`R/checks.R:204`, `:234`,
  ~23 and ~41 lines). tune's `.check_grid()` (`R/checks.R:67`, `NAMESPACE:136`)
  validates the same triple and returns the expanded grid, and
  `check_extra_tune_parameters()` (`R/checks.R:361`, unexported) repeats the
  column-versus-parameter half; by content these two are duplication, which is
  `glue`. What is not duplication is *when*. tune raises per fold, and this
  package tunes once per outer fold, so a malformed grid tune would reject
  surfaces here as every fold in the design failing alike after the whole cost has
  been paid — the comment at `R/checks.R:228-233` states exactly that, and M03's
  rule of recording fold failures rather than re-raising them is why the per-fold
  raise is not available as a check. Deciding what a loop refuses before it starts
  is this package's own question about its own loop, which is `core`; the content
  of the refusal is tune's. Neither half is wrong, and the pair moved here rather
  than staying `glue` once the counterpart turned out to be exported.
- **F051 `same_candidates()`, F052 `candidate_key()`, F053 `rendered_rows()`**
  (`R/nested-results-print.R:179`, `:184`, `:215`). These three compare the
  candidate sets different outer folds searched, and the print method warns when
  the folds did not search the same grid. By position they are `furniture`:
  nothing but `print.nested_results()` calls them, and what they produce is a
  line of output. By cause they are `glue`: they compare records this package had
  to *reconstruct* (F070–F073) because a `tune_results` keeps no expanded grid,
  and the situation they report — folds searching different menus under
  `grid = 10` with a continuous parameter — arises from each fold expanding its
  own grid under its own seed. Inside tune, with the expansion in hand, neither
  the reconstruction nor the warning would take this shape, and it is not clear
  the comparison would survive at all. Neither bucket is wrong, and forcing one
  would hide half the reason the code exists.
- **F059 `outer_scheme_label()`** (`R/nested-results.R:48`). It strips the nested
  classes from the design and calls `pretty()` on what is left, so the outer
  resampling scheme can describe itself in a header. It is `furniture` by
  purpose — it exists for a print method and its result is a string. But the work
  it does is assembly-time and resampling-layer in nature: it is a workaround for
  `pretty.nested_cv()` (rsample `R/printing.R:112`) describing both levels at
  once, where the results object needs the outer level alone. The label is
  computed once at construction (`R/nested-results.R:33`) and stored as an
  attribute, so it is not print-path code either. rsample offering a
  single-level scheme label would delete it; so would dropping the header line.
- **F106 `fold_task()`** (`R/parallel.R:823`). The one-fold worker. Its body is
  `core`: it unpacks the payload and calls `nested_fold_fit()`, which is the loop.
  Its first line is not: `ns <- asNamespace("nestedtune")`, a name-based namespace
  lookup that exists because a closure carrying this package's namespace loses it
  when a daemon cannot reconstruct it, silently falling back to the global
  environment (recorded at `R/parallel.R:817-822`). That indirection, the
  environment-stripping at the dispatch site, and the symbol pre-flight that makes
  its failure loud are all consequences of a third package shipping code to
  daemons that must load it from an installed library. Inside tune the lookup
  resolves to tune's own namespace and the problem does not disappear — daemons
  still load tune from a library — but the shape it takes is tune's dispatch
  problem, not a wrapper this package writes around tune's loop.
- **`[.nested_results`** (`R/nested-results.R:69`, the addendum). By shape it is
  `furniture`: an S3 method on a subsetting operator, the ordinary way a class
  keeps its identity under `[`. By content it is the invariant that a results
  object never claims a run it cannot describe — it sheds the class when a subset
  drops any defining column, recomputes `folds_attempted` and `folds_completed`
  from the rows in hand, and drops the outer scheme label outright because "10-fold
  cross-validation" is false of three retained rows. That is the same
  record-what-ran discipline the constructor applies, expressed in a method
  signature. Its own comment (`R/nested-results.R:80-95`) also records that which
  of its lines is load-bearing depends on whether `[.tbl_df` or `[.data.frame` is
  reached, so part of it is `glue` for not depending on tibble (F061) as well.

## Reconciliation against `NAMESPACE`

`NAMESPACE` at `89d8418` carries 8 `export()` lines and 10 `S3method()` lines.
Every one is accounted for.

**`export()` — 5 name a definition the extraction procedure emits:**
`nested_resamples` (F025), `nested_tune_grid` (F068), `nested_final_fit` (F021),
`extract_tune_results` (F012), `extract_scored_candidates` (F015).

**`export()` — 3 name a symbol the procedure's output does not define, and are
therefore re-exports, excluded from the function inventory:** `autoplot`,
`collect_metrics`, `extract_workflow`. The rule that generates this list is
mechanical rather than a registry: an `export()` line whose symbol appears
nowhere in the extraction procedure's 106 names defines no function here, and
`R/reexports.R` confirms each of the three as a bare `pkg::generic` re-export
statement (`tune::collect_metrics`, `tune::extract_workflow`,
`ggplot2::autoplot`). A fourth re-export added later is caught by the same
subtraction with no edit to this page's rule.

**`S3method()` — 9 name a definition the procedure emits:**
`autoplot.nested_results` (F029), `collect_metrics.nested_results` (F062),
`extract_scored_candidates.default` (F016),
`extract_scored_candidates.nested_final_fit` (F017),
`extract_tune_results.default` (F013),
`extract_tune_results.nested_final_fit` (F014),
`extract_workflow.nested_final_fit` (F024), `print.nested_final_fit` (F019),
`print.nested_results` (F045).

**`S3method()` — 1 names a definition the procedure does not emit:**
`S3method("[",nested_results)`, whose definition is the backtick-quoted
`` `[.nested_results` `` at `R/nested-results.R:69`. It is not a re-export — the
method is defined in this package — so it is carried in the addendum above with a
bucket and a reason, rather than excluded.

## Disposition

- The 16 `glue` entries and the 12 `resampling-layer` entries are drafted into
  upstream asks in `benchmarks/upstream-asks.md`, unposted. That draft is where
  each ask states what it would retire.
- The 32 `core` and 38 `furniture` entries land nowhere else: they are what this
  package carries, and naming them is the whole of this page's obligation to
  them.
- The 8 `ambiguous` entries plus the addendum land in the asks draft only where
  an upstream change would settle part of them: F059, which an rsample
  single-level scheme label would delete outright, and F001, F006 and F007, whose
  duplicated half a promised tune surface would remove while the residue stays
  here. F051–F053, F106 and the addendum appear in the draft nowhere and are
  recorded as unsettled here alone.
- No refactor follows from this page. Acting on any entry is its own milestone,
  planned from here — this page describes, it does not schedule.
- This page produced no rule, so no test file locks one.

## Open questions

- Whether the `glue` entries would survive contact with tune's maintainers as
  written is untested — nothing has been proposed and no upstream opinion has
  been sought — observed 2026-08-30.
- The upstream facts here are read from source trees at two fixed tags. Whether
  tune's `.check_grid()`, `check_workflow()`, `new_note()` and
  `choose_framework()`, or rsample's `nested_cv()`, `labels.rset()` and
  `inside_resample()`, still take these shapes at a later version is unchecked
  beyond v2.1.0 and v1.3.2 — observed 2026-08-30.
- Whether tune would attach any stability promise to the `empty_ellipses`,
  `internal-parallel` and `choose_metric` helpers, or whether `@keywords internal`
  is a deliberate refusal to be depended on, has not been asked. Which answer
  comes back decides whether the entries resting on that fact are retired by an
  upstream change or by this package accepting the risk — observed 2026-08-30.
- Whether `postprocessing`/tailor-era changes in tune touch the note and metric
  assembly cited for F075–F079 has not been examined — observed 2026-08-30.
