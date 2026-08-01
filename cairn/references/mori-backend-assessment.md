# What `mori` would and would not change about this package's parallel path (M26)

**Provenance.** Ingested 2026-07-31 by M26 from first-hand execution against
`mori` 0.2.2, `mirai` 2.7.2, `tune` 2.1.0 and `rsample` 1.3.2 on R 4.6.1
(aarch64-apple-darwin25.4.0), driven by `benchmarks/probe-mori-dispatch.R` in
this repo; from a read of mori's CRAN source tarball (`mori_0.2.2.tar.gz`, 5 R
functions over 2,245 lines of C) and its `DESCRIPTION`; and from a read-only
read of `tidymodels/tune` issue #1188 via `gh`.
Pagination: —.
Extraction: rewritten at M29 against the installed-state manifest
(`benchmarks/mori-wire-manifest.json`), every current wire figure re-read from
that manifest at the rewrite — observed 2026-08-01; the assessed external
artifacts (mori 0.2.2, tune#1188) move independently of this repo and have not
been re-read since 2026-07-31 — observed 2026-08-01.

<!-- drift-check: lean_bundle_bytes=941,683 B@2; mori_bundle_bytes=103,109 B@2; lean_payload_bytes=98,342 B; ratio_lean_over_mori=9.13@2; gap_bytes=838,574 B; shared_reference_bytes=267 B; shared_marginal_bytes=175 B; worker_closure_bytes=524 B@2; sum_of_parts_overstatement_bytes=150 B -->

**Scope.** This page assesses what adopting `mori` would and would not change
about this package's outer-loop dispatch, and is not a summary of any one
source. It deliberately builds no adoption proposal and no dispatch design:
adding `mori` to `DESCRIPTION` is a dependency change requiring its own
question gate and D-entry, and this page's job is to make that gate decidable,
not to pre-empt it. Every current wire figure on this page is a value from
`benchmarks/mori-wire-manifest.json` (M26's installed-state, single-stream
capture); figures marked **[historical]** belong to a prior milestone's
committed record or to M26's superseded development-state capture and support
no current claim. Standing disclaimer: this is a reference, not an authority
— status lives in `ROADMAP.md`, decisions in `DECISIONS.md`, architecture in
`DESIGN.md`.

**Evidence snapshot.**

- `mori` 0.2.2 CRAN source, `R/share.R` and `src/{altrep,shm,serialize,init}.c` — `mori_0.2.2.tar.gz` — observed 2026-07-31.
- `mori`'s `DESCRIPTION`: no hard package dependencies (`Depends: R (>= 4.3)`, `Suggests: mirai, testthat`), and shared memory via POSIX (Linux, macOS) **or a Win32 file mapping (Windows)** — observed 2026-07-31.
- `tidymodels/tune` issue #1188, "proof of concept of adding {mori}", open, filed 2026-04-27 by **EmilHvitfeldt** (Emil Hvitfeldt), no comments. tune's maintainer is Max Kuhn; the benchmark in that issue is Emil's, not his — observed 2026-07-31.
- Identity and transport measurements — `benchmarks/probe-mori-dispatch.R` in this repo; wire figures — `benchmarks/mori-wire-manifest.json`, its committed installed-state capture — observed 2026-08-01.
- The dispatch path assessed against — `R/parallel.R:118-138` (`is_fold_payload`), `:140-179` (`lean_payload`/`rehydrate_payload`), `:190` (`dispatch_folds`) — observed 2026-07-31.
- M23's committed figures, re-derived here — `fixture_design()` (v = 5, inner_v = 5, `set.seed(2)`), moved at M26 review to `tests/testthat/helper-payload-size.R` so the probe can source it, and `tests/testthat/test-parallel-payload.R:140` (`expect_identical(count_data_copies(fat, sentinel), 6L)`) — observed 2026-08-01.

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
assumed: one shared object serializes to 267 B (`shared_reference_bytes`), and
each additional reference in the same stream costs about ~175 B
(`shared_marginal_bytes`). The data itself stays off the wire entirely — both
figures' copy-count oracles assert 0 copies of the frame in the stream. The
region name embeds the creating process id in hex, so its length follows the
pid; the serialized reference, not the name's width, is what carries the cost.

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

This applies to the **identity** finding only. The wire figures (below, in the
measurements section) take their lean row from the real dispatcher by capture;
their mori rows are modelled — by substitution into the captured bundle, and
independently member-by-member — since no dispatch sends them today.

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
| P1 | D-011 — per-fold RNG is two kind-pinned integer seeds drawn at entry, and the driver is net-zero on the caller's RNG state | Seeds are drawn host-side (`R/nested-tune-grid.R:318` — observed 2026-07-31) and travel as integers in the payload; `set_fold_seed()` runs worker-side inside `nested_fold_fit()`. mori changes only how the *data* reaches the worker and has no RNG surface to perturb either through. Measured: fold records `identical()` to serial at 2 and 3 workers | `Untouched` |
| P2 | IP2 — same seed, same result, any worker count, parallel or serial | Held under mori at both worker counts on a ranger workflow, i.e. an engine whose randomness flows through R's RNG so the assertion is not vacuous (M02). The probe additionally asserts every fold completed, since three arms that all failed identically would compare equal too — observed 2026-07-31 | `Untouched` |
| P3 | D-018 — `mirai` is the outer-loop parallel backend | mori composes with mirai rather than replacing it. Adopting mori would not revisit the backend choice | `Untouched` |
| P4 | The mirai-vs-`future` question raised on tune#969 | mori is not a scheduler, so it supplies no evidence either way. The question stays open | `Out of reach` |
| P5 | M23 — per-fold wire cost | Changed substantially: the data leaves the wire entirely (1 copy → 0), taking the per-fold total from 941,683 B (`lean_bundle_bytes`) to 103,109 B (`mori_bundle_bytes`), a factor of 9.13 (`ratio_lean_over_mori`) — installed-state, single-stream capture — observed 2026-08-01 | `Changed` |
| P6 | That `lean_payload()`/`rehydrate_payload()`/`is_fold_payload()` (`R/parallel.R:118-179` — observed 2026-07-31) could therefore be deleted | Two reasons they could not. **(a)** `is_fold_payload()` is not leanness machinery at all — it enforces the one-frame-per-fold invariant, and M23 review F1 (scored 93) recorded that without it a `manual_rset()` over differing frames is tuned on the wrong rows in parallel and the right ones serially: an IP2 breach with an IP1 exposure (`R/parallel.R:100-118`). mori needs that predicate exactly as much as leaning did, though the fat-path fallback it currently triggers has no mori analogue and adoption would have to say what replaces it. **(b)** mori is same-machine, so a remote pool cannot map the host's region and the by-value path must stay as its fallback. Adoption removes the blanking and rehydration, not the gate | `Conditional` |
| P7 | M24 — the pre-flight capability probe (`check_daemons_can_load()`, `R/parallel.R:543` — observed 2026-07-31) | A daemon needs mori installed in its library, which the probe does not currently ask. Only `daemon_symbol_manifest()` takes a `package` argument (`R/parallel.R:391`); `daemon_probe_expr()` has no formals (`:420`) and `check_daemons_can_load()` has no `package` parameter, so probing a second package is new machinery rather than a new argument value — and M24 review F6 recorded a further constraint, that `asNamespace(package)` runs host-side, so the host must also have the probed package installed — observed 2026-07-31 | `Changed` |
| P8 | rsample#283 / M01 — memory scaling with the outer fold count | Not addressed. `nested_cv()`'s cost is analysis frames materialized **in-process** before any parallelism; mori addresses transfer to daemons. Different axis, and the package's founding gap is untouched by mori either way — observed 2026-07-31 | `Out of reach` |
| P9 | mori's own adoption cost | `Depends: R (>= 4.3)` against this package's `R (>= 4.1)` (`DESCRIPTION` — observed 2026-07-31), so adoption either raises the floor or makes mori conditional. No hard package dependencies otherwise, and Windows is supported via Win32 file mapping rather than being excluded | `Changed` |
| P10 | Byte-exact reproducibility of the wire measurements | Unaffected in the installed state: the probe regenerates every manifest figure byte-identically within a process; across processes the totals move by a few bytes because the pid's hex string serializes inside the bundles, and the manifest's `reproducibility` field states the bound on that movement (a re-measurement bound — the committed documents are locked to the committed manifest at the precision they print, a separate and stricter comparison). The srcref-laden worker closure that moved between environments is a development-state artifact absent from the installed capture — observed 2026-08-01 | `Untouched` |

### The measurements behind P2, P5 and P10

Per fold on M23's own fixture — `fixture_design()`, now in
`tests/testthat/helper-payload-size.R`: 5,000×21, v = 5 outer, inner_v = 5,
`set.seed(2)`. Package state: installed to a temporary library with srcrefs
stripped — the state `install.packages()` produces. The record is
`benchmarks/mori-wire-manifest.json`: 9 figures, each carrying its fixture and
an install-dependence flag — the seven captured ones backed by asserted
oracles (the probe's registry refuses an oracle string with no assertion
behind it), the two derived ones computed from asserted quantities.

**These figures are captured, not reconstructed.** The lean row is taken by
running the package's own `dispatch_folds()` and intercepting
`mirai::mirai_map()` to record exactly the bundle mirai hands `request()` —
one serialization per task, one stream. Summing separately serialized members
overstates that stream — by 150 B (`sum_of_parts_overstatement_bytes`) at this
fixture in the installed state, and by far more wherever shared structure is
large — which is why every total here is a whole-stream figure and no
accounting convention is left to choose.

The mori row is **modelled**, necessarily — no dispatch sends it today — but
modelled from that same captured bundle, substituting only what adoption would
change: the shared frame replaces `.args$shared`, and the rehydrating wrapper
collapses back to `fold_task` because there is nothing to rehydrate. The worker
closure is carried on **both** rows, since a real adoption would still send the
package's own worker. Its independent oracle: a bundle assembled
member-by-member in mirai's order serializes to the same bytes.

| Route | Total/fold | Copies of the data |
|---|---|---|
| lean (captured) | 941,683 B | 1 |
| mori (modelled) | 103,109 B | 0 |

The factor is 9.13, and the copy counts are those two figures' asserted
copy-count oracles, found by searching each stream for the big-endian bytes of
one numeric column. The gap, 838,574 B (`gap_bytes`), re-derives to the byte
within each run from the independently assembled bundle, and is dominated by
the data itself: the manifest's frame cross-check oracle asserts the `.args`
rung equals the frame serialized alone, within 5%. The worker closure is
524 B installed (`worker_closure_bytes`) — near-negligible on both routes,
asserted srcref-free by walking its language tree, with `removeSource()`
leaving its byte count identical. The payload alone is 98,342 B
(`lean_payload_bytes`), carries 0 copies of the frame (the frame rides in
`.args`), and is backed by a closed form predicting it from the design's
scalars alone, asserted within M23's 5% band — an oracle sharing no arithmetic
with the capture.

### Historical record **[historical]**

Everything in this subsection is a prior milestone's committed record or a
superseded capture, kept because it explains how the published numbers
changed; no current claim rests on it.

- **M23's committed totals reconcile on the fat route.** M23 recorded
  25,714,635 B → 5,783,645 B over 5 folds. Rebuilding the pre-M23 fat route at
  this fixture gave 5,141,166 B/fold and 6 copies, matching M23's test-locked
  `6L`, and 25,714,635 / 5 = 5,142,927 B/fold — a difference of 1,761 B,
  exactly M23's own per-fold `.args`. The lean total did **not** reconcile
  against the development-state capture, which briefly suggested M23 had
  under-reported the wire cost. That suggestion was withdrawn rather than
  filed: it rested on development-state closure sizes and sum-of-parts
  accounting, and M23's committed totals were measured under M23's own
  convention — payload and `.args` summed separately — a different quantity
  from the manifest's single-stream bundle, so the two totals do not compare
  term-by-term and support no under-report conclusion in either direction.
- **M26's first capture (superseded).** A `pkgload::load_all()` capture summing
  separately serialized parts published 1,523,499 B lean, 393,841 B mori and a
  3.87× ratio. Both accounting premises were wrong: mirai performs one
  serialization per task, and the worker closure's bulk (291,491 B dev-state
  against 524 B installed) was srcref structure that install strips. Git holds
  the full superseded text.

## What a real adoption would send that this model does not

Three deltas, recorded as unmeasured — none has a figure here, and measuring
them belongs to whatever milestone takes the adoption gate.

- **The per-fold frame on the mixed-frame path.** `lean_payload()` attaches a
  fold's own `outer_data`/`inner_data` whenever that fold's frame is not the
  shared one (`R/parallel.R:150-155` — observed 2026-08-01). The modelled mori
  row assumes the one-frame fixture; a `manual_rset()` over differing frames
  would still send per-fold frames by value under mori.
- **The retained by-value branch.** mori is same-machine (P6b), so a remote
  pool keeps the current by-value path as its fallback — an adoption ships
  both routes, not a replacement.
- **The host-side `share()` cost.** Writing the frame into a shared region
  makes the host transiently hold the original plus the shared copy; see Open
  questions.

## Disposition

- P1, P2, P3 — no action. Recorded here so a later plan does not re-derive them.
- P4 — the multi-level parallelism question is unaffected and stays for the maintainer conversation.
- P5, P6, P7, P9 — these are what an adoption decision turns on. They land on a ROADMAP candidate row, which carries P6's two retention reasons and P9's R-floor cost as conditions rather than afterthoughts; adoption itself is a dependency gate and a D-entry, deliberately not taken here.
- P8 — recorded specifically to head off the misreading that shared memory answers rsample#283. Nothing to action.
- P10 — resolved with a stated bound: every identity and oracle re-asserts on every run, and totals reproduce byte-exactly within a process, while across processes they move by a few bytes because the pid's hex string serializes inside the bundles.
- The `mirai::everywhere()` preload candidate row is dominated on its own terms if mori is adopted: that shape buys one-copy-per-daemon with daemon state, cleanup and a stale-object hazard, where mori is one-copy-per-machine with no daemon state, automatic GC and lazy mapping — and the row's motivation, cutting per-fold `.args` transfer, is exactly what mori zeroes. The row is cross-referenced to M26 rather than closed, because closing it is part of the adoption decision.
- The remote-daemon-pool candidate row gains a reason to stay open: P6(b) makes it the case that decides whether the by-value path can ever be retired.

No rule here is locked by a test; this page produces no rule. The measurements
are re-derivable by `Rscript benchmarks/probe-mori-dispatch.R`, which asserts
every oracle the manifest credits — a divergence, an incomplete fold, or a
failure of mori transport to engage aborts the run. The two `derived` figures
(the ratio and the sum-of-parts overstatement) are computed from asserted
quantities rather than asserted at their own values, and the manifest marks
them so. The figures this page cites are additionally locked to the manifest
by a drift check (`tests/testthat/`), which reads the declaration comment near
the top of this page.

## Open questions

- Peak **host** memory under mori is not measured here. `share()` writes the frame into a shared region, so the host transiently holds the original plus the shared copy. tune#1188 reports whole-process-tree peak RSS falling 18.9 GB → 4.23 GB on `fit_resamples()`, but its host-side `mem_alloc` column moves the other way, 6.22 MB → 16.5 GB, which is the datum that bears on this question and it is Emil Hvitfeldt's measurement of tune's path, not ours — observed 2026-07-31.
- Wall-clock effect on this package's dispatch is not measured; only bytes, transport and identity are — observed 2026-08-01.
- Behaviour when a shared region's owner dies mid-run is unexamined. The probe calls `prune_shared()` at the end as cheap insurance, but nothing tests the orphan path — observed 2026-07-31.
- Whether `share()` on an `rsplit` is stable across rsample versions is unexamined; the probe shares the data frame and points splits at it, which relies only on `$data` assignment — observed 2026-07-31.
- tune#1188 is a proof of concept with no comments and no linked PR as of this reading; whether tune adopts mori is unknown, and P5–P7 assume nothing about that — observed 2026-07-31.
