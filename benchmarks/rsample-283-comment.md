# Draft comment for rsample#283

**Not posted.** This is a draft. A maintainer of this repository posts it to
https://github.com/tidymodels/rsample/issues/283 by hand. Every figure below
comes from `benchmarks/rsample-283-reprex.R` in this repository. Run that
script before posting if the versions have moved.

Nothing outside this file depends on it, and no script here posts it.

---

The 13× in this issue is real, and the cause is one line of code. But the
scheme it belongs to is not the one the text describes. It is worth separating
the two, because the fix only makes sense once the shape of the growth is
clear.

### What the reprex measured

The reprex reads as an outer 5-fold with an inner 2-fold. But `vfold_cv()` has
no `times` argument. Its fold count is `v`, and `repeats` is what repeats the
scheme. `times` is the matching argument on several of the Monte-Carlo and
bootstrap functions, including `bootstraps()`. The landing-page bootstrap
example that this reprex says it adapted is one of those, so the slip is an
easy one to make. In 2022 the argument fell into `...` and was silently
discarded, and both levels took the default `v = 10`.

The reprex's own output shows this. `obj_size(nested) / nrow(nested)` gives
`3,443,420`, which is `34,434,200 / 10`. A 5-fold outer scheme would have
divided by 5.

So the 13× belongs to a 10 × 10 design rather than a 5 × 2 one. Current
rsample no longer allows the ambiguity. `vfold_cv()` opens with
`check_dots_empty()`, so the original call now fails right away.

```
Error in `rsample::vfold_cv()`:
! `...` must be empty.
✖ Problematic argument:
• times = 5
```

### The cause

`nested_cv()` maps the inner specification over each outer split with
`inside_resample()`:

```r
inside_resample <- function(src, cl, env) {
  cl <- rlang::call_modify(cl, data = as.data.frame(src))
  eval(cl, envir = env)
}
```

`as.data.frame()` on an `rsplit` materializes that fold's analysis set. The
inner `rset` then points at a fresh copy of `n(v-1)/v` rows instead of the
original data, so the object holds **`v - 1` extra copies of the dataset** on
top of the index vectors. That is why the cost tracks the *outer* fold count
and stays nearly flat in the inner one. The inner count only adds index
vectors.

Everything a `nested_cv` object holds, term by term:

| term | bytes |
|---|---|
| one shared copy of the source data | `data_bytes` |
| `v` materialized analysis frames | `data_bytes * (v - 1)` |
| outer analysis indices (`out_id` is `NA`) | `4 * n * (v - 1)` |
| inner analysis indices (`out_id` is `NA`) | `4 * n * (v - 1) * (inner_v - 1)` |

Those terms collapse to `data_bytes * v + 4 * n * (v - 1) * inner_v`.

### Measurements

The dataset is `mlbench::LetterRecognition` (20,000 × 17, 2,644,640 B), the one
this issue uses. Versions are rsample 1.3.2, R 4.6.1,
aarch64-apple-darwin25.4.0, seed 35222. Both schemes are built explicitly,
since the original call no longer runs:

| scheme | outer folds | bytes | × data | model | residual |
|---|---|---|---|---|---|
| 10 × 10 (what the reprex built) | 10 | 33,715,400 | 12.749 | 12.722 | −0.20% |
| 5 × 2 (what the text describes) | 5 | 13,871,840 | 5.245 | 5.242 | −0.06% |
| 10 × 5 | 10 | 30,078,080 | 11.373 | 11.361 | −0.11% |

The model sits just under each measurement, which is what it should do. It
accounts for storage and not for the per-object overhead of the `rsplit` lists
and tibbles themselves.

The 12.749 here is a little below the 13.020 reported in 2022, and that gap has
an explanation too. 34,434,200 − 33,715,400 = 718,800 B, against 720,000 B for
ten explicit integer row-name vectors of 18,000 elements. Today those
materialized frames carry compact row names, and `.row_names_info()` returns
−18,000. So the difference is row-name storage rather than a change in the
phenomenon.

### Whether a leaner form is possible

The behaviour is not inherent to `rsplit`. An inner split can index the
original data directly instead of a materialized copy, as long as it carries an
explicit assessment index. `out_id` cannot stay `NA` in that case, because the
complement of an index into the *whole* data would sweep in the outer fold's
assessment rows. The object then grows only with index vectors:
`data_bytes + 4 * n * (v - 1) * (inner_v + 1)`. That model gives 3.995 × at
10 × 10, against the 12.749 × measured above. Note that 3.995 is a modelled
figure and not a measured one. The leaner form was measured only at 10 × 5,
where it came to 2.649 × against 2.633 × modelled, so the model runs a little
under.

One caveat on how such splits are built, learned the hard way. Building them
from scratch with `make_splits()` and `manual_rset()` looks like the obvious
route, and it is not. `make_splits()` returns a bare `rsplit`, so the result
loses the split subclass and the per-split `id` tibble that `labels()` and
`add_resample_id()` read, and `manual_rset()` drops `id2`. Rewriting the
`data`, `in_id`, and `out_id` fields of the splits that `nested_cv()` already
produced keeps all of that intact. Splits built that way are row-identical to
the current ones, and that is the form that is actually tested downstream.

A note on where this comes from. The diagnosis fell out of building a
memory-lean nested-resampling constructor on top of rsample
([nestedtune](https://github.com/jmgirard/nestedtune)). The 11.373 × figure
above is a committed oracle there, and the field-rewriting approach above is
what it ships. I am posting this as a diagnosis rather than a pull request on
purpose. Whether `nested_cv()` should change shape is yours to decide, and
there is a backward-compatibility question in it that I can't answer from
outside.
