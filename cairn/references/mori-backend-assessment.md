# What `mori` would and would not change about this package's parallel path (M26)

**Provenance.** Ingested 2026-07-31 by M26 from first-hand execution against
`mori` 0.2.2, `mirai` 2.7.2, `tune` 2.1.0 and `rsample` 1.3.2 on R 4.6.1
(aarch64-apple-darwin25.4.0), driven by `benchmarks/probe-mori-dispatch.R` in
this repo; from a read of mori's CRAN source tarball (`mori_0.2.2.tar.gz`, 5 R
functions over 2,245 lines of C) and its `DESCRIPTION`; and from a read-only
read of `tidymodels/tune` issue #1188 via `gh`.
Pagination: —.
Extraction: values read directly from execution on 2026-07-31; the assessed artifacts (mori 0.2.2, tune#1188) move independently of this repo and none has been re-read since — observed 2026-07-31.

**Scope.** This page assesses what adopting `mori` would and would not change
about this package's outer-loop dispatch, and is not a summary of any one
source. It deliberately builds no adoption proposal and no dispatch design:
adding `mori` to `DESCRIPTION` is a dependency change requiring its own
question gate and D-entry, and this page's job is to make that gate decidable,
not to pre-empt it. Standing disclaimer: this is a reference, not an authority
— status lives in `ROADMAP.md`, decisions in `DECISIONS.md`, architecture in
`DESIGN.md`.

**Evidence snapshot.**

- `mori` 0.2.2 CRAN source, `R/share.R` and `src/{altrep,shm,serialize,init}.c` — `mori_0.2.2.tar.gz` — observed 2026-07-31.
- `mori`'s `DESCRIPTION`: no hard package dependencies (`Depends: R (>= 4.3)`, `Suggests: mirai, testthat`), and shared memory via POSIX (Linux, macOS) **or a Win32 file mapping (Windows)** — observed 2026-07-31.
- `tidymodels/tune` issue #1188, "proof of concept of adding {mori}", open, filed 2026-04-27 by **EmilHvitfeldt** (Emil Hvitfeldt), no comments. tune's maintainer is Max Kuhn; the benchmark in that issue is Emil's, not his — observed 2026-07-31.
- Identity, transport and wire-cost measurements — `benchmarks/probe-mori-dispatch.R` in this repo — observed 2026-07-31.
- The dispatch path assessed against — `R/parallel.R:118-138` (`is_fold_payload`), `:140-179` (`lean_payload`/`rehydrate_payload`), `:190` (`dispatch_folds`), `:243` (mirai charges `.f` per task exactly as `.args`) — observed 2026-07-31.
- M23's committed figures, re-derived here — `tests/testthat/test-parallel-payload.R:40` (`fixture_design()`, v = 5, inner_v = 5, `set.seed(2)`) and `:145` (`expect_identical(count_data_copies(fat, sentinel), 6L)`) — observed 2026-07-31.

## What `mori` is

`mori` writes an R object into shared memory — POSIX on Linux and macOS, a
Win32 file mapping on Windows — and returns an ALTREP-backed object that reads
from it without copying. Other processes on the **same machine** map the region
by name. An ALTREP serialization hook is what makes it interesting for
dispatch: a shared object crossing a `mirai()` call serializes as a compact
reference rather than as its contents. The region is reference-counted and
freed when the last reference goes away or the session exits cleanly;
`prune_shared()` recovers regions orphaned by a killed process.

**What a shared reference actually costs on the wire**, measured rather than
assumed: the region name is 19 characters, one shared object serializes to
**267 B**, and each additional reference in the same stream costs about
**175 B**. The name's own length is not the wire cost — a serialized shared
object carries the ALTREP class and its metadata too. Against a 160,187 B
frame by value, that is still a reduction of nearly three orders of magnitude,
but it is 175 B per reference and not the ~30 B an earlier draft of this page
claimed.

Three further properties matter here and none is obvious from the description.

First, it is **not a scheduler**. `mori` is an object-transport mechanism that
composes with `mirai`; it is not an alternative to `mirai`, and it is not a
third option beside `mirai` and `future`. Nothing in it bears on the multi-level
parallelism question.

Second, it has **no RNG surface**. None of `unif_rand`, `norm_rand`,
`GetRNGstate`, `PutRNGstate`, `R_unif`, `rand`, `srand` or `random` occurs
anywhere in its C sources, and none of its five R functions is stochastic.

Third, a receiving process needs `mori` **installed but not loaded**. R records
the owning package on an ALTREP class and loads that namespace itself when
deserializing — verified by execution in the probe, which asserts per run that
the daemon reports `is_shared()` TRUE and the host's own region name back. The
natural assumption, that daemons need `everywhere(loadNamespace("mori"))`
first, is wrong.

## How the probe differs from `dispatch_folds()`

This applies to the **identity** finding only. The wire figures above are
captured from the real dispatcher and reconstruct nothing.

The identity finding comes from three arms: the package's own
`dispatch_folds()` serial branch, its parallel branch, and a **replica** of
that parallel branch routing the frame through mori. Only the third is
hand-rolled, and it departs from `R/parallel.R:190` in three ways a reader
should weigh before trusting the result.

1. **No leaning, and no invariant gate.** `dispatch_folds()` blanks `$data` on
   every split and sends one frame in `.args`, rehydrating worker-side; the
   mori arm leaves `$data` in place pointing at one shared object. But
   `is_fold_payload()` is not part of that leaning machinery — see P6 — and
   the replica has no equivalent, which is safe only because its fixture
   provably shares one frame. The probe asserts that rather than assuming it.
2. **No pre-flight and no cancellation guard.** `check_daemons_can_load()` and
   `warn_if_not_cancellable()` are diagnostics around the dispatch, not part of
   it, and the identity question does not reach them.
3. **No `record_dispatch()` seam.** The by-value arm asserts `last_dispatch()`
   out of band; the replica has nothing to assert.

Everything else is copied deliberately: the seed scheme, the per-fold payload
shape, the namespace-by-name worker lookup, the `environment(task) <-
globalenv()` strip, and the `collect_mirai()` plus cancelling `on.exit()`
collect the real dispatcher uses.

## Premise ledger — what mori does to each thing this package's parallel path rests on

Tags: `Untouched` (the premise is unaffected) · `Changed` (the premise would
change if mori were adopted) · `Conditional` (changed on some pools, not all) ·
`Out of reach` (mori does not address this at all).

| # | Premise | What mori does to it | Tag |
|---|---|---|---|
| P1 | D-011 — per-fold RNG is two kind-pinned integer seeds drawn at entry, and the driver is net-zero on the caller's RNG state | Seeds are drawn host-side (`R/nested-tune-grid.R:318`) and travel as integers in the payload; `set_fold_seed()` runs worker-side inside `nested_fold_fit()`. mori changes only how the *data* reaches the worker and has no RNG surface to perturb either through. Measured: fold records `identical()` to serial at 2 and 3 workers | `Untouched` |
| P2 | IP2 — same seed, same result, any worker count, parallel or serial | Held under mori at both worker counts on a ranger workflow, i.e. an engine whose randomness flows through R's RNG so the assertion is not vacuous (M02). The probe additionally asserts every fold completed, since three arms that all failed identically would compare equal too | `Untouched` |
| P3 | D-018 — `mirai` is the outer-loop parallel backend | mori composes with mirai rather than replacing it. Adopting mori would not revisit the backend choice | `Untouched` |
| P4 | The mirai-vs-`future` question raised on tune#969 | mori is not a scheduler, so it supplies no evidence either way. The question stays open | `Out of reach` |
| P5 | M23 — per-fold wire cost | Changed substantially: the data leaves the wire entirely (1 copy → 0), taking the per-fold total from 1,523,499 B to 393,841 B, a factor of 3.87. See the table below | `Changed` |
| P6 | That `lean_payload()`/`rehydrate_payload()`/`is_fold_payload()` (`R/parallel.R:118-179`) could therefore be deleted | Two reasons they could not. **(a)** `is_fold_payload()` is not leanness machinery at all — it enforces the one-frame-per-fold invariant, and M23 review F1 (scored 93) recorded that without it a `manual_rset()` over differing frames is tuned on the wrong rows in parallel and the right ones serially: an IP2 breach with an IP1 exposure (`R/parallel.R:100-118`). mori needs that predicate exactly as much as leaning did, though the fat-path fallback it currently triggers has no mori analogue and adoption would have to say what replaces it. **(b)** mori is same-machine, so a remote pool cannot map the host's region and the by-value path must stay as its fallback. Adoption removes the blanking and rehydration, not the gate | `Conditional` |
| P7 | M24 — the pre-flight capability probe (`check_daemons_can_load()`, `R/parallel.R:543`) | A daemon needs mori installed in its library, which the probe does not currently ask. Only `daemon_symbol_manifest()` takes a `package` argument (`R/parallel.R:391`); `daemon_probe_expr()` has no formals (`:420`) and `check_daemons_can_load()` has no `package` parameter, so probing a second package is new machinery rather than a new argument value — and M24 review F6 recorded a further constraint, that `asNamespace(package)` runs host-side, so the host must also have the probed package installed | `Changed` |
| P8 | rsample#283 / M01 — memory scaling with the outer fold count | Not addressed. `nested_cv()`'s cost is analysis frames materialized **in-process** before any parallelism; mori addresses transfer to daemons. Different axis, and the package's founding gap is untouched by mori either way | `Out of reach` |
| P9 | mori's own adoption cost | `Depends: R (>= 4.3)` against this package's `R (>= 4.1)` (`DESCRIPTION`), so adoption either raises the floor or makes mori conditional. No hard package dependencies otherwise, and Windows is supported via Win32 file mapping rather than being excluded | `Changed` |
| P10 | Byte-exact reproducibility of the wire measurements | Unaffected. An earlier draft of this page claimed the mori route varied per run because the region name encodes the creating process; the name is fixed-width 19 characters, and the modelled mori bundle measured 100,589 B in three separate processes with three distinct region names. What does move between environments is the srcref-laden worker closure, which both routes carry equally | `Untouched` |

### The measurements behind P2, P5 and P10

Per fold on M23's own fixture — `fixture_design()` at
`tests/testthat/test-parallel-payload.R:40`: 5,000×21, v = 5 outer, inner_v = 5,
`set.seed(2)`.

**These figures are captured, not reconstructed.** Two earlier drafts of this
page built the payload and `.args` by hand and compared those, and twice the
published number failed to survive re-derivation — once because the fixture was
not M23's, once because the hand-built accounting charged the worker closure to
one route only. So the lean row is now taken by running the package's own
`dispatch_folds()` and intercepting `mirai::mirai_map()` to record exactly what
it was handed. mirai serializes `.f`, one element of `.x`, and `.args` per task,
so a fold's wire cost is the sum of the three and no accounting convention is
left to choose.

The mori row is **modelled**, necessarily — no dispatch sends it today — but
modelled from that same captured bundle, substituting only what adoption would
change: the shared frame replaces `.args$shared`, and the rehydrating wrapper
collapses back to `fold_task` because there is nothing to rehydrate. The worker
closure is carried on **both** rows, since a real adoption would still send the
package's own worker.

| Route | `.f` | `.x` | `.args` | Total/fold | Copies of the data |
|---|---|---|---|---|---|
| lean (captured) | 291,418 | 98,346 | 1,133,735 | 1,523,499 | 1 |
| mori (modelled) | 291,491 | 100,589 | 1,761 | 393,841 | 0 |

**3.87×**, and the data is off the wire entirely. Two terms explain the whole
gap: the worker closure, 291,491 B, common to both rows and cancelling; and the
data, 840,540 B, which the lean route carries in `.args$shared` and mori does
not. mori's `.args` is 1,761 B, which is exactly the workflow-plus-grid-plus-
metrics term that also reconciles the fat route below.

**Reconciliation against M23's committed totals.** M23 recorded 25,714,635 B →
5,783,645 B over 5 folds. The pre-M23 fat route reconciles exactly: rebuilding
it at this fixture gives 5,141,166 B/fold and 6 copies, matching M23's
test-locked `6L` at `test-parallel-payload.R:145`, and 25,714,635 / 5 =
5,142,927 B/fold, a difference of 1,761 B — exactly M23's own per-fold `.args`
of `list(object = workflow, grid = 3, metrics = NULL)`, measured at 1,761 B.

The lean total does **not** reconcile, for two reasons this page states rather
than smooths over. M23's accounting summed payloads plus `.args` and never
counted `.f`, which mirai charges per task exactly as `.args`; and the closure's
serialized size is srcref-dependent, so it grew from the 202,363 B recorded at
`R/parallel.R:246` to 291,491 B measured here. `R/parallel.R` grew from 26,759 B
at M23 to 39,066 B at M24, the only commit touching it between, which accounts
for the difference. M23's committed 5,783,645 B therefore under-reports today's
real per-fold cost on two independent counts; that is a finding about the older
record, not about mori, and it is filed as a ROADMAP candidate rather than
corrected here.

Two oracles back the lean payload, from `tests/testthat/helper-payload-size.R`:
a **closed form** predicting it from n/v/inner_v alone (96,000 B predicted
against 98,346 B measured, 2.4%, asserted against M23's own 5% band rather than
printed), and a **copy count** found by searching the stream for the big-endian
doubles of one numeric column. They share no arithmetic. The copy counts — 1 on
the lean route, 0 on mori — are asserted, not printed.

## Disposition

- P1, P2, P3 — no action. Recorded here so a later plan does not re-derive them.
- P4 — the multi-level parallelism question is unaffected and stays for the maintainer conversation.
- P5, P6, P7, P9 — these are what an adoption decision turns on. They land on a ROADMAP candidate row, which carries P6's two retention reasons and P9's R-floor cost as conditions rather than afterthoughts; adoption itself is a dependency gate and a D-entry, deliberately not taken here.
- P8 — recorded specifically to head off the misreading that shared memory answers rsample#283. Nothing to action.
- P10 — actioned in `benchmarks/probe-mori-dispatch.R`, which states the non-determinism, and in the `~` marks above.
- The `mirai::everywhere()` preload candidate row is dominated on its own terms if mori is adopted: that shape buys one-copy-per-daemon with daemon state, cleanup and a stale-object hazard, where mori is one-copy-per-machine with no daemon state, automatic GC and lazy mapping — and the row's motivation, cutting per-fold `.args` transfer, is exactly what mori zeroes. The row is cross-referenced to M26 rather than closed, because closing it is part of the adoption decision.
- The remote-daemon-pool candidate row gains a reason to stay open: P6(b) makes it the case that decides whether the by-value path can ever be retired.

No rule here is locked by a test; this page produces no rule. The measurements
are re-derivable by `Rscript benchmarks/probe-mori-dispatch.R`, which asserts
its own findings rather than printing them — a divergence, an incomplete fold,
or a failure of mori transport to engage aborts the run.

## Open questions

- Peak **host** memory under mori is not measured here. `share()` writes the frame into a shared region, so the host transiently holds the original plus the shared copy. tune#1188 reports whole-process-tree peak RSS falling 18.9 GB → 4.23 GB on `fit_resamples()`, but its host-side `mem_alloc` column moves the other way, 6.22 MB → 16.5 GB, which is the datum that bears on this question and it is Emil Hvitfeldt's measurement of tune's path, not ours — observed 2026-07-31.
- Wall-clock effect on this package's dispatch is not measured; only bytes, transport and identity are — observed 2026-07-31.
- Behaviour when a shared region's owner dies mid-run is unexamined. The probe calls `prune_shared()` at the end as cheap insurance, but nothing tests the orphan path — observed 2026-07-31.
- Whether `share()` on an `rsplit` is stable across rsample versions is unexamined; the probe shares the data frame and points splits at it, which relies only on `$data` assignment — observed 2026-07-31.
- tune#1188 is a proof of concept with no comments and no linked PR as of this reading; whether tune adopts mori is unknown, and P5–P7 assume nothing about that — observed 2026-07-31.
