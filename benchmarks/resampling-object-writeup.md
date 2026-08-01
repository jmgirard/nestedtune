# Draft writeup: what an outer loop needs from a nested resampling object

**Not posted.** This is a draft for the conversation the rsample maintainer
opened about redesigning the nested resampling object (keeping one `data`
and reindexing the inner splits). A maintainer of this repository shares it
by hand; no script here posts it.

Every figure below comes from `benchmarks/outer-loop-object-requirements.R`
(rsample 1.3.2 / R 4.6.1, 2026-08-01) or, where noted, from
`benchmarks/mori-wire-manifest.json` (M26). The full requirements inventory
with `file:line` citations is `cairn/references/outer-loop-object-requirements.md`
(M27); the R/C/W row ids below refer to it. Each claim is tagged
**(measured)** — reproduced by a committed script in this repository — or
**(inferred)** — an argument from mechanism, not a number we ran.

The transfer-cost caveat M26 obligates: the paragraph "One caveat on the
wire numbers" below is the claim mori's shared-memory finding could change,
and it says so explicitly.

---

We've been running an outer tuning loop against both `nested_cv()` and a
reindexed variant of it for a while, so rather than argue for a design we
can report what a driver actually needs from the object, what it has to
rebuild because the object doesn't carry it, and what reindexing measures
out to. Everything below is reproducible from scripts in the nestedtune
repository; each claim is tagged **(measured)** or **(inferred)**.

## What reindexing buys

**In process (measured).** On `mlbench::LetterRecognition` (20,000 × 17),
`nested_cv()` against the reindexed shape measures 3.23× at v = 5,
inner v = 5 and 5.09× at v = 20, inner v = 5, each within ~1% of a
closed-form model whose leading term is `data_bytes × v` — the
materialized analysis frame per outer fold. The ratio grows with the outer
fold count because that term does; this is the same mechanism as
rsample#283, measured at two more settings.

**On the wire (measured).** Sending a fold to a worker serializes it, and
serialization does not preserve in-memory sharing. Our dispatcher already
strips the redundant frame copies a fold's splits carry and rebuilds them
worker-side, so this is measured *after* that mitigation: a reindexed
fold's payload is index vectors only (~98 kB at 5×5; zero embedded frames
by a byte-level copy count), while a `nested_cv()` fold still carries its
own materialized analysis frame (~755 kB at 5×5, ~70% of its payload; copy
count 1). That frame is not removable by any dispatch-side trick
**(inferred)**: the object owns the copy — each fold's inner splits index
a frame that exists nowhere else — so only the object's shape can remove
it. Reindexing removes it by construction.

**One caveat on the wire numbers.** We separately measured a shared-memory
transport (`mori`, cf. tune#1188): mapping the one shared frame instead of
serializing it takes a fold's wire cost from ~942 kB to ~103 kB, a factor
of 9.13 **(measured)**. If tune adopts that upstream, the *absolute* wire
figures above shrink for any single-frame design, and the "shared frame is
serialized once per task" premise disappears with them. Two things it does
not change **(inferred)**: shared memory is same-machine, so a remote pool
still pays serialization; and it presupposes exactly one shared frame —
`nested_cv()`'s per-fold materialized frames are the shape that defeats
it, so shared memory makes the case for reindexing stronger, not weaker.
The in-process axis is untouched either way: those frames are materialized
before any parallelism exists.

## What a driver reads from the object

The full inventory is 19 reads (R1–R19 in the linked note). Compressed,
the object's load-bearing surface for a driver is: the two list columns
(`splits`, `inner_resamples`) and their element classes; the `id*`
columns; `nrow()`; the class vector (for "is this a bootstrap", and for
reaching the outer scheme's `pretty()`); the stored `inside` call; and —
through a private field — the data itself. Everything else we consume, we
derive.

## What we rebuild because the object doesn't carry it

These are the requirements, in the sense that a redesigned object which
carried them would delete driver code on our side (C1–C7 in the note; all
**(measured)** in the weak sense that the cited code exists and runs):

1. **The data, first-class.** The design has no data field; we recover
   the frame via `splits[[1]]$data` and assert all splits share it. A
   `data` slot with an accessor is the single highest-value carry.
2. **The one-shared-frame invariant as a class property.** Our parallel
   path must verify, per dispatch, that every inner split of a fold
   indexes one frame — because with the current class it can be false
   (`manual_rset()` over differing frames), and when it is false a leaned
   dispatch tunes on the wrong rows. An object that guarantees
   indices-into-one-frame by construction turns a runtime measurement
   into a type fact.
3. **Declared id columns and fold labels.** We infer the id set by
   subtracting the two known column names and grep `^id` to label folds.
   Declared, these stop being conventions.
4. **A self-contained inner specification.** The stored `inside` call
   travels without its environment, so re-running the procedure (the
   final-fit path) evaluates it wherever the caller now stands —
   `vfold_cv(v = k)` silently means whatever `k` means today. A spec with
   its arguments substituted at construction (or a closure) re-evaluates
   identically anywhere.
5. **Per-level scheme description.** `pretty()` on a nested design
   describes both levels at once; we strip classes to name the outer
   scheme alone.

## Where the class boundary forces workarounds

Eleven sites in our code exist only to get past the current classes
(W1–W11 in the note). The ones a redesign could dissolve: no public
accessor for an `rsplit`'s `in_id`/`out_id`/`data` (we write all three
directly when remapping, because rebuilding via `manual_rset()` drops the
split subclass and per-split id tibble); `out_id = NA` semantics that are
only sound when the indexed frame *is* the analysis set (reindexed splits
must make the complement explicit or leak outer assessment rows);
no exported way to recompute a fingerprint (we build a throwaway
`manual_rset()` to harvest one); and compatibility-by-class-vector (we
append `nested_cv` to our class so existing methods dispatch).

None of this argues for our implementation — it argues that the
requirements above are what any outer-loop driver hits, ours included, and
that they're worth designing into the object rather than around it.
