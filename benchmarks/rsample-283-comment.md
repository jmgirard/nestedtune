# Draft comment for rsample#283

**Not posted.** This is a draft. A maintainer of this repository posts it to
https://github.com/tidymodels/rsample/issues/283 by hand. Every figure below
comes from `benchmarks/rsample-283-reprex.R` in this repository. Run that
script before posting if the versions have moved.

Figures re-verified against rsample 1.3.2 / R 4.6.1 on 2026-07-30; every number
below reproduced exactly, and the prose was rewritten that day for readability
without any figure changing.

Nothing outside this file depends on it, and no script here posts it.

---

The growth here is real, and it comes down to a single line.

`nested_cv()` builds each outer fold's inner resamples by materializing that
fold's analysis set, so the object ends up carrying an extra copy of your data
for every outer fold. The line is in `inside_resample()`:

```r
inside_resample <- function(src, cl, env) {
  cl <- rlang::call_modify(cl, data = as.data.frame(src))
  eval(cl, envir = env)
}
```

`as.data.frame()` on an `rsplit` hands back the analysis rows as a brand new
frame, and the inner `rset` then indexes that copy instead of the original data.
That's why the cost scales with the *outer* fold count and stays nearly flat in
the inner one — more inner folds only add index vectors. It's the same shape as
the plots above, where the lines separate by outer folds and barely move with
inner ones.

Here's everything the object holds:

| term | bytes |
|---|---|
| one shared copy of the source data | `data_bytes` |
| `v` analysis frames, each holding `(v-1)/v` of the rows | `data_bytes * (v - 1)` |
| outer analysis indices | `4 * n * (v - 1)` |
| inner analysis indices | `4 * n * (v - 1) * (inner_v - 1)` |

Only analysis indices show up because `out_id` is `NA` throughout — assessment
rows are derived as the complement rather than stored. The terms collapse to:

```
data_bytes * v + 4 * n * (v - 1) * inner_v
```

### One caveat on the 13× figure

Worth knowing before anyone sizes a fix against it: the reprex measures a 10 × 10
design, not the 5 × 2 its text describes.

`vfold_cv()` has no `times` argument. Its fold count is `v`, and `repeats` is
what repeats the scheme. `times` belongs to the Monte Carlo and bootstrap
functions — `bootstraps()` among them — and the landing-page bootstrap example
the reprex says it adapted is one of those, so it's an easy slip to make. Back in
2022 `times` fell into `...` and was dropped silently, leaving both levels at the
default `v = 10`.

The reprex's own output shows it: `obj_size(nested) / nrow(nested)` prints
`3,443,420`, which is `34,434,200 / 10`. Five outer folds would have divided by
five.

Current rsample catches this. `vfold_cv()` opens with `check_dots_empty()`, so
the original call errors outright now:

```
Error in `rsample::vfold_cv()`:
! `...` must be empty.
✖ Problematic argument:
• times = 5
```

### Measurements

Same dataset as the issue — `mlbench::LetterRecognition`, 20,000 × 17,
2,644,640 B. rsample 1.3.2, R 4.6.1, aarch64-apple-darwin25.4.0, seed 35222. I
rebuilt both schemes explicitly, since the original call no longer runs.

| scheme | outer folds | bytes | × data | model | residual |
|---|---|---|---|---|---|
| 10 × 10 (what the reprex built) | 10 | 33,715,400 | 12.749 | 12.722 | −0.20% |
| 5 × 2 (what its text describes) | 5 | 13,871,840 | 5.245 | 5.242 | −0.06% |
| 10 × 5 | 10 | 30,078,080 | 11.373 | 11.361 | −0.11% |

The model lands just under each measurement, which is what you'd want — it counts
storage and not the per-object overhead of the `rsplit` lists and tibbles.

The 12.749 is a shade under the 13.020 reported in 2022, and that gap resolves
too: 34,434,200 − 33,715,400 = 718,800 B, against 720,000 B for ten explicit
integer row-name vectors of 18,000 elements. Those frames carry compact row names
today — `.row_names_info()` returns −18,000. So it's row-name storage rather than
any change in the behaviour itself.

### Could it be leaner?

Yes, and nothing about `rsplit` requires the copy. An inner split can index the
original data directly, as long as it carries an explicit assessment index.
`out_id` can't stay `NA` in that case, because the complement of an index into
the *whole* dataset would pull in the outer fold's assessment rows. The object
then grows only with index vectors:

```
data_bytes + 4 * n * (v - 1) * (inner_v + 1)
```

That models 3.995× at 10 × 10, against the 12.749× measured above. To be clear,
3.995 is modelled and not measured — I only measured the lean form at 10 × 5,
where it came to 2.649× against 2.633× modelled, so the model runs a little under
there as well.

One thing that cost me time, in case it saves you some: building these splits
from scratch with `make_splits()` and `manual_rset()` looks like the obvious
route, and it isn't. `make_splits()` returns a bare `rsplit`, so you lose the
split subclass and the per-split `id` tibble that `labels()` and
`add_resample_id()` read, and `manual_rset()` drops `id2`. Rewriting the `data`,
`in_id` and `out_id` fields of the splits `nested_cv()` already produced keeps
all of that intact, and splits built that way come out row-identical to the
current ones.

All of this fell out of building a memory-lean nested resampling constructor on
top of rsample ([nestedtune](https://github.com/jmgirard/nestedtune)). The
11.373× above is a committed test oracle there, and the field-rewriting approach
is what it ships, so everything here is reproducible from a script in that repo
if you'd like to re-run it.

I'm posting this as a diagnosis rather than a PR because whether `nested_cv()`
should change shape is your call, and there's a backward-compatibility question
in it I can't answer from outside. Happy to put a PR together if that would help.
