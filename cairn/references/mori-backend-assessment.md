# What `mori` would and would not change about this package's parallel path (M26)

**Provenance.** Ingested 2026-07-31 by M26 from first-hand execution against
`mori` 0.2.2, `mirai` 2.7.2, `tune` 2.1.0 and `rsample` 1.3.2 on R 4.6.1
(aarch64-apple-darwin25.4.0), driven by `benchmarks/probe-mori-dispatch.R` in
this repo; from a read of mori's CRAN source tarball (`mori_0.2.2.tar.gz`, 5 R
functions over 2,245 lines of C); and from a read-only read of
`tidymodels/tune` issue #1188 via `gh`.
Pagination: —.
Extraction: values read directly from execution on 2026-07-31; the assessed
artifacts (mori 0.2.2, tune#1188) move independently of this repo and none has
been re-read since — observed 2026-07-31.

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
- `mori` on CRAN with no hard dependencies (`Depends: R (>= 4.3)`, `Suggests: mirai, testthat`) — `available.packages()` — observed 2026-07-31.
- `tidymodels/tune` issue #1188, "proof of concept of adding {mori}", open, filed 2026-04-27 by the tune maintainer, no comments — `gh issue view 1188 --repo tidymodels/tune` — observed 2026-07-31.
- Identity and wire-cost measurements — `benchmarks/probe-mori-dispatch.R` in this repo — observed 2026-07-31.
- The dispatch path assessed against — `R/parallel.R:118-179` (`is_fold_payload`/`lean_payload`/`rehydrate_payload`), `R/parallel.R:190` (`dispatch_folds`) — observed 2026-07-31.

## What `mori` is

`mori` writes an R object into a POSIX shared memory region and returns an
ALTREP-backed object that reads from it without copying. Other processes on the
**same machine** map the region by name. An ALTREP serialization hook is what
makes it interesting for dispatch: a shared object crossing a `mirai()` call
serializes as its ~30-byte region name rather than as its contents. The region
is reference-counted and freed when the last reference goes away or the session
exits cleanly; `prune_shared()` recovers regions orphaned by a killed process.

Three properties matter here and none is obvious from the description.

First, it is **not a scheduler**. `mori` is an object-transport mechanism that
composes with `mirai`; it is not an alternative to `mirai`, and it is not a
third option beside `mirai` and `future`. Nothing in it bears on the multi-level
parallelism question.

Second, it has **no RNG surface**. None of `unif_rand`, `norm_rand`,
`GetRNGstate`, `PutRNGstate`, `R_unif`, `rand`, `srand` or `random` occurs
anywhere in its C sources, and none of its five R functions is stochastic.

Third, a receiving process needs `mori` **installed but not loaded**. R records
the owning package on an ALTREP class and loads that namespace itself when
deserializing — verified by execution: a daemon that had never attached `mori`
and received no preload call reported `is_shared()` TRUE on the arriving frame,
the host's own region name, and a correct column sum. The natural assumption,
that daemons need `everywhere(loadNamespace("mori"))` first, is wrong; an
earlier draft of the probe carried exactly that call and it was removed as dead
weight.

## Premise ledger — what mori does to each thing this package's parallel path rests on

Tags: `Untouched` (the premise is unaffected) · `Changed` (the premise would
change if mori were adopted) · `Conditional` (changed on some pools, not all) ·
`Out of reach` (mori does not address this at all).

| # | Premise | What mori does to it | Tag |
|---|---|---|---|
| P1 | D-011 — per-fold RNG is two kind-pinned integer seeds drawn at entry, and the driver is net-zero on the caller's RNG state | Seeds are drawn host-side (`R/nested-tune-grid.R:318`) and travel as integers in the payload; `set_fold_seed()` runs worker-side inside `nested_fold_fit()`. mori changes only how the *data* reaches the worker and has no RNG surface to perturb either through. Measured: fold records `identical()` to serial at 2 and 3 workers | `Untouched` |
| P2 | IP2 — same seed, same result, any worker count, parallel or serial | Held under mori at both worker counts on a ranger workflow, i.e. an engine whose randomness flows through R's RNG so the assertion is not vacuous (M02) | `Untouched` |
| P3 | D-018 — `mirai` is the outer-loop parallel backend | mori composes with mirai rather than replacing it. Adopting mori would not revisit the backend choice | `Untouched` |
| P4 | The mirai-vs-`future` question the tune maintainer raised | mori is not a scheduler, so it supplies no evidence either way. The question stays open | `Out of reach` |
| P5 | M23 — per-fold wire cost, and the `lean_payload()`/`rehydrate_payload()`/`is_fold_payload()` machinery that achieves it (`R/parallel.R:118-179`, ~60 lines) | mori reaches 0 copies of the data on the wire without any of that machinery: every split can point at one shared object and there is nothing to blank or rehydrate. 906,284 B → 67,253 B per fold on M23's own fixture | `Changed` |
| P6 | That the lean path could therefore be retired | It could not. mori is same-machine, so a pool with remote daemons cannot map the host's region and the by-value lean path has to remain as the remote fallback. Adoption makes M23's machinery conditional, not obsolete | `Conditional` |
| P7 | M24 — the pre-flight capability probe (`check_daemons_can_load()`, `R/parallel.R:543`) | A daemon needs mori installed in its library, which is the same requirement class the probe already checks for nestedtune. Adoption would extend the symbol manifest rather than need new machinery | `Changed` |
| P8 | rsample#283 / M01 — memory scaling with the outer fold count | Not addressed. `nested_cv()`'s cost is analysis frames materialized **in-process** before any parallelism; mori addresses transfer to daemons. Different axis, and the package's founding gap is untouched by mori either way | `Out of reach` |
| P9 | Byte-exact reproducibility of the wire measurements | Lost on the mori route: a shared object serializes as its region name and the name encodes the creating process, so the figure moves a few bytes per run (3,525 vs 3,529). The copy count stays exact on every route, which is why it carries the claim | `Changed` |

### The measurements behind P2, P5 and P9

Per fold, data-bearing terms only, on M23's 5,000×21 fixture at v=5/v=3.
`.args` is charged once per task, not once per run, so it is per-fold wire cost
exactly as the payload is. The workflow, grid, metrics and worker closure also
ride in `.args`, identically on all three routes, so they cancel from a route
comparison — which is why these totals are smaller than M23's committed
5,783,645 B over 5 folds, which counts them.

| Route | Payload | `.args` | Total/fold | Copies of the data |
|---|---|---|---|---|
| fat (pre-M23) | 3,427,624 | 0 | 3,427,624 | 4 |
| lean (current) | 65,744 | 840,540 | 906,284 | 1 |
| mori | 67,253 | 0 | 67,253 | 0 |

Two independent oracles per GP2, both from `tests/testthat/helper-payload-size.R`:
serialized bytes, and a direct count of the data's own wire bytes found by
searching the stream for the big-endian doubles of one numeric column. The
count is not a proxy for the size arithmetic — it answers "how many copies of
this frame are in here", which is the claim itself.

## Disposition

- P1, P2, P3 — no action. Recorded here so a later plan does not re-derive them.
- P4 — the multi-level parallelism question is unaffected and stays for the maintainer conversation.
- P5, P6, P7 — these are what an adoption decision turns on. They land on a ROADMAP candidate row for adopting mori, which carries P6's fallback requirement as a condition rather than an afterthought; adoption itself is a dependency gate and a D-entry, deliberately not taken here.
- P8 — recorded specifically to head off the misreading that shared memory answers rsample#283. Nothing to action.
- P9 — actioned in `benchmarks/probe-mori-dispatch.R`, which states the non-determinism rather than leaving a reader to trip over it.
- The `mirai::everywhere()` preload candidate row is dominated on its own terms if mori is adopted: that shape buys one-copy-per-daemon with daemon state, cleanup and a stale-object hazard, where mori is one-copy-per-machine with no daemon state, automatic GC and lazy mapping — and the row's motivation, cutting per-fold `.args` transfer, is exactly what mori zeroes. The row is cross-referenced to M26 rather than closed, because closing it is part of the adoption decision.
- The remote-daemon-pool candidate row gains a reason to stay open: P6 makes it the case that decides whether the lean path can ever be retired.

No rule here is locked by a test; this page produces no rule. The measurements
are re-derivable by `Rscript benchmarks/probe-mori-dispatch.R`.

## Open questions

- Peak **host** memory under mori is not measured. `share()` writes the frame into a shared region, so the host transiently holds the original plus the shared copy; whether that matters at realistic sizes is unmeasured here. tune#1188's 18.9 GB → 4.23 GB is a whole-process-tree figure on `fit_resamples()`, measured by the tune maintainer rather than here, and does not answer the host-side question — observed 2026-07-31.
- Wall-clock effect on this package's dispatch is not measured; only bytes and identity are — observed 2026-07-31.
- Behaviour when a shared region's owner dies mid-run, and whether `prune_shared()` is needed in this package's teardown, is unexamined — observed 2026-07-31.
- Whether `share()` on an `rsplit` is stable across rsample versions is unexamined; the probe shares the data frame and points splits at it, which relies only on `$data` assignment — observed 2026-07-31.
- tune#1188 is a proof of concept with no comments and no linked PR as of this reading; whether tune actually adopts mori is unknown, and this page's P5–P7 assume nothing about that — observed 2026-07-31.
