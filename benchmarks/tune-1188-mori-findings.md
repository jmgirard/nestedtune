# Draft note on mori (tune#1188)

Drafted 2026-07-31 by M26, corrected after review the same day. **Not posted.**
Posting is the maintainer's call.

Follows through on the mori offer in the second reply draft to topepo on
tune#969 (`benchmarks/tune-969-reply.md` and `tune-969-reply-2.md`, both
uncommitted at the time of writing), which said mori had not been evaluated and
offered to check it against the reproducibility behaviour measured on the mirai
path. This is that check.

**Note on audience.** tune#1188 was filed by Emil Hvitfeldt, and the 18.9 GB →
4.23 GB benchmark in it is his. If this goes to Max, it should not address that
work as his; if it goes on the issue, it is addressed to Emil. The text below
is written for the issue thread.

Written without em dashes, per request.

Every figure below comes from `benchmarks/probe-mori-dispatch.R` in the
nestedtune repository, run against mori 0.2.2, mirai 2.7.2, tune 2.1.0 and
rsample 1.3.2 on R 4.6.1 (aarch64-apple-darwin25.4.0), 2026-07-31. The fuller
assessment, including what was not measured, is in
`cairn/references/mori-backend-assessment.md` in that repo.

Claims are marked **[measured]** or **[inferred]** throughout. Nothing below is
a recommendation about whether tune should adopt mori.

---

I had a look at mori against the reproducibility behaviour I had measured on
the mirai path in a nested-resampling wrapper. Short version: it does not
disturb it, and the wire numbers are good. Three caveats that I think matter
more than the headline.

**Reproducibility is untouched.** **[measured]** I ran one nested design three
ways under one seed: the wrapper's own dispatcher serially, the same dispatcher
in parallel, and a replica of its parallel branch that routes the fold data
through mori instead of by value. The fold records are `identical()` across all
three, at 2 and at 3 workers. The engine is ranger rather than lm on purpose,
since with a deterministic engine that comparison passes even against a
dispatcher that seeds wrongly. The probe also asserts every fold completed,
because three arms that all failed identically would compare equal too.

**[measured]** The reason it holds looks structural rather than lucky. mori has
no RNG surface: none of `unif_rand`, `norm_rand`, `GetRNGstate`,
`PutRNGstate`, `R_unif`, `rand`, `srand` or `random` appears anywhere in its
2,245 lines of C, and none of its five R functions is stochastic. It changes how
data reaches a worker, not what the worker draws.

**Wire cost.** **[measured]** Per outer fold, on a 5,000 x 21 frame at v = 5
outer and v = 5 inner. Counting the data-bearing terms, plus the worker closure
on the route that actually carries it:

| route | payload | `.args` | total per fold | copies of the data |
|---|---|---|---|---|
| before the lean-dispatch work | 5,141,166 B | 0 | 5,141,166 B | 6 |
| after it | 98,346 B | 1,132,051 B | 1,230,397 B | 1 |
| via mori | ~100,589 B | 0 | ~100,589 B | 0 |

The copy count is measured directly by searching the serialized stream for the
big-endian bytes of one numeric column, not inferred from the totals. The mori
row carries a `~` because that route is not byte reproducible: a shared object
serializes as its region name and the name encodes the creating process, so it
moves a few bytes per run. The other two rows are exact.

One number worth stating precisely, since it is easy to overstate: a shared
reference is not free. The region name is 19 characters, but one shared object
serializes to 267 B and each additional reference costs about 175 B. Against a
frame that would otherwise travel whole, that is still a reduction of nearly
three orders of magnitude.

**First caveat: same machine.** **[measured]** mori is same-machine shared
memory. A daemon on another host cannot map the region. So if you route fold
data through mori, the by-value path does not go away, it becomes the fallback
for remote pools.

**Second caveat, and the one I would flag hardest: the invariant check is not
part of the leaning machinery.** **[measured]** In our wrapper the blanking and
rehydration are about 60 lines, and mori does make those unnecessary. But a
separate predicate guards the precondition that every split in a fold indexes
the *same* frame. Our own review found, by execution, that without it a
`manual_rset()` over splits built on different frames gets tuned on the wrong
rows in parallel and the right ones serially. Pointing every split at one shared
object has exactly the same precondition, so that check has to survive whatever
replaces the leaning. It would be easy to read a 12x wire improvement as
licence to delete the whole block.

**Third caveat: it does not address the nested_cv memory problem.**
**[inferred]** This one I nearly misread myself. rsample#283 is about analysis
frames materialized in the host process before any parallelism happens. mori
addresses transfer to workers. They are different axes, so adopting mori would
leave #283 where it is. This is a structural argument rather than something I
measured.

**A smaller thing that surprised me.** **[measured]** Daemons do not need mori
preloaded. I had assumed they would, since the unserialize hook lives in mori's
DLL, and my first version of the probe called
`everywhere(loadNamespace("mori"))`. They do not: R records the owning package
on an ALTREP class and loads that namespace itself on deserialize. The probe now
asserts this per run, checking that the daemon reports the host's own region
name back rather than a materialized copy. What a daemon does need is mori
installed in its library.

**Adoption cost worth noting.** **[measured]** mori declares
`Depends: R (>= 4.3)`. Anything taking it on either raises its own R floor or
makes mori conditional. It has no hard package dependencies otherwise, and
Windows is supported through a Win32 file mapping rather than being excluded.

**One thing I could not answer.** **[inferred]** Peak host memory. `share()`
writes the frame into a shared region, so the host transiently holds the
original plus the shared copy. The 18.9 GB to 4.23 GB figure in #1188 is a
whole-process-tree measurement, and the `mem_alloc` column in the same benchmark
moves the other way, 6.22 MB to 16.5 GB. I did not measure the host side
separately on our path and would not want to guess from that.

Finally: mori is not a scheduler, so none of this bears on the mirai versus
future question that came up on #969. I still have no measured evidence there.
