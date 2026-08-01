# Draft note to topepo on mori (tune#1188)

Drafted 2026-07-31 by M26. **Not posted.** Posting is the maintainer's call.

Follows through on the second offer in `benchmarks/tune-969-reply-2.md`, which
said mori had not been evaluated and offered to check it against the
reproducibility behaviour measured on the mirai path. This is that check.

Written without em dashes, per request.

Every figure below comes from `benchmarks/probe-mori-dispatch.R` in the
nestedtune repository, run against mori 0.2.2, mirai 2.7.2, tune 2.1.0 and
rsample 1.3.2 on R 4.6.1 (aarch64-apple-darwin25.4.0), 2026-07-31. The fuller
assessment, including what was not measured, is in
`cairn/references/mori-backend-assessment.md` in that repo.

Claims are marked **[measured]** or **[inferred]** throughout. Nothing below is
a recommendation about whether tune should adopt mori.

---

I had a look at mori against the reproducibility behaviour I measured on the
mirai path. Short version: it does not disturb it, and the wire numbers are
better than I expected. Two caveats that I think matter more than the headline.

**Reproducibility is untouched.** **[measured]** I ran one nested design three
ways under one seed: nestedtune's own dispatcher serially, the same dispatcher
in parallel, and a replica of its parallel branch that routes the fold data
through mori instead of by value. The fold records are `identical()` across all
three, at 2 and at 3 workers. The engine is ranger rather than lm on purpose,
since with a deterministic engine that comparison passes even against a
dispatcher that seeds wrongly.

**[inferred]** The reason it holds looks structural rather than lucky. mori has
no RNG surface at all: none of `unif_rand`, `norm_rand`, `GetRNGstate`,
`PutRNGstate`, `R_unif`, `rand`, `srand` or `random` appears anywhere in its
2,245 lines of C, and none of its five R functions is stochastic. It changes how
data reaches a worker, not what the worker draws.

**Wire cost.** **[measured]** Per outer fold, counting only the data-bearing
terms, on a 5,000 x 21 frame at v = 5 outer and v = 3 inner:

| route | payload | `.args` | total per fold | copies of the data |
|---|---|---|---|---|
| before our lean-dispatch work | 3,427,624 B | 0 | 3,427,624 B | 4 |
| after it | 65,744 B | 840,540 B | 906,284 B | 1 |
| via mori | 67,253 B | 0 | 67,253 B | 0 |

The copy count is measured directly by searching the serialized stream for the
big-endian bytes of one numeric column, not inferred from the totals. The
workflow, grid and metrics also ride in `.args` on all three routes and cancel
out of the comparison, so these are smaller than a full per-fold figure.

What that buys is not just the ratio. Our lean path exists to get that copy
count from 4 down to 1, and it costs about 60 lines that blank the data field
on every split before dispatch and restore it worker-side. With mori there is
nothing to blank: every split can point at one shared object and the ALTREP
serialization hook carries it as a ~30 byte name.

**First caveat: same machine.** **[measured, then inferred]** mori is
same-machine shared memory. A daemon on another host cannot map the region. So
if you route fold data through mori, the by-value path does not go away, it
becomes the fallback for remote pools. I would not plan on deleting anything.

**Second caveat: it does not address the nested_cv memory problem.**
**[measured]** This one I want to flag because I nearly misread it myself.
rsample#283 is about analysis frames materialized in the host process before
any parallelism happens. mori addresses transfer to workers. They are different
axes, and adopting mori would leave #283 exactly where it is.

**A smaller thing that surprised me.** **[measured]** Daemons do not need mori
preloaded. I had assumed they would, since the unserialize hook lives in mori's
DLL, and my first version of the probe called
`everywhere(loadNamespace("mori"))`. They do not: R records the owning package
on an ALTREP class and loads that namespace itself on deserialize. A daemon with
mori merely installed, never attached, received a shared frame and reported the
host's own region name back. What a daemon does need is mori installed in its
library, which is the same requirement any package-backed worker already has.

**One thing I could not answer.** **[not measured]** Peak host memory.
`share()` writes the frame into a shared region, so the host transiently holds
the original plus the shared copy. Your 18.9 GB to 4.23 GB figure on #1188 is a
whole-process-tree measurement and I would expect the daemon side to dominate,
but I did not measure the host side separately and I would not want to assume
it.

Finally, and this is the part I would most want your view on: mori is not a
scheduler, so none of this bears on the mirai versus future question you
raised. I still have no measured evidence there.
