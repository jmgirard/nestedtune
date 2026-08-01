# Draft reply to topepo on tune#969

Drafted 2026-07-31. **Not posted.** Posting is the maintainer's call.

Grounded in D-024 (the posture decision) and the measured results behind
D-005, D-011, D-012, D-018 and RR01/RR03. His stated bandwidth opens after
2026-08-14, so there is no reason to send this before then.

Two things deliberately NOT in this draft, per D-024's recorded rejections:
it does not ask tune for a supported pass-through for forcing inner tuning
sequential (an API commitment, declined as too much to ask), and it does not
propose keeping nestedtune for the pieces tune may not want.

---

Thanks, that's really useful, and there's no rush on the timing.

Some context on where I'm coming from. I've been building `nestedtune`, a small
package that drives the outer loop and delegates the inner tuning to tune. It
exists because of the gap you already know about: tune aborts on a top-level
`nested_cv` object, so nothing in the ecosystem runs the whole loop, and the
canonical how-to article ends up bypassing parsnip. What makes a wrapper
possible is that each `inner_resamples` element is an ordinary `rset`, which
tune accepts. So the wrapper can call `tune_grid()` per outer fold, select, fit
on the outer analysis set, and score on the outer assessment set.

The main thing I want to say: **if you want the outer loop in tune, I would much
rather help you land it there than maintain a second implementation of it.** I'm
happy to port what I have onto the `nested` branch, in whatever shape suits
tune's internals, and to retire nestedtune afterwards if it becomes redundant.
Two implementations of one loop is the outcome I would least like. That is also
why I have not submitted anything to CRAN while this is open.

If the outer loop turns out not to be something tune wants to own, nestedtune
can carry on as a companion. The only thing it would need from tune is that the
`nested_cv` refusal stays a *top-level* refusal, with inner `rset`s still
accepted as ordinary rsets. That is already exactly what tune does, so it asks
nothing new of you. I mention it only so it does not get tightened by accident.

A few things I have measured that might save you time either way.

**RNG.** Verified by execution against tune 2.1.0. tune >= 2.0.0 derives its own
per-resample L'Ecuyer substreams even under `control_grid(allow_par = FALSE)`,
and it leaves the caller's `.Random.seed` and `RNGkind()` exactly as it found
them. `last_fit()` is the one step that consumes the ambient stream. An outer
fold's whole stochastic outcome is therefore a function of just two RNG states,
which makes seeding the outer loop tractable: draw `2 * n_folds` seeds up front,
assign them by fold position, and pin the generator kind per fold. That kind pin
is load-bearing rather than precautionary. mirai starts every daemon on its own
L'Ecuyer-CMRG stream, so without the pin a worker draws from a different
generator than the serial run does. With it, results are `identical()` to serial
at every worker count.

**rsample memory.** `nested_cv()`'s helper `inside_resample()` calls
`as.data.frame(src)` on each outer fold, so memory scales with the number of
outer folds instead of staying near one copy of the data. A lean equivalent is
buildable from public rsample API (`make_splits()` plus `manual_rset()`), with
no fork and no compiled code. I wrote the diagnosis up on rsample#283.

**Multi-level parallelism**, since you raised it. nestedtune parallelizes only
the outer loop, one fold per mirai task, and runs the inner tuning sequentially.
That leaves one scheduler rather than two competing for the same cores. It
sidesteps the interesting question rather than answering it, and it is the part
I would most value your view on. I do not have measured evidence on mirai versus
future for nested scheduling specifically. What I can say is that mirai's
per-daemon RNG streams are what made the reproducibility story above work out
cleanly.

Happy to open a PR against the `nested` branch, write the design up first, or
just answer questions, whichever is least work for you. And if the answer is
"not now", that is genuinely fine.
