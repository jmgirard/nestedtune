# RR04: An invariant resting on vctrs' experimental frame-prototype generic (M37)

- **Date:** 2026-08-31
- **Brief:** `cairn/reviews/RB04-vctrs-cbind-hook.md`
- **Reviewed against:** vctrs 0.7.3, dplyr 1.1.x, the `m037-vctrs-invariants`
  work at `R/nested-results.R` and `tests/testthat/test-vctrs-compat.R`
  (all 87 assertions in that file pass as reviewed)
- **Status:** advisory; no binding criteria were requested

Every behavioral claim below marked "measured" was reproduced during this
review on a synthetic `nested_results` (the brief's nine columns, five
attributes) with the package loaded, against vctrs 0.7.3.

## 1. Is the registration defensible, and is there another mechanism?

Defensible, yes — and no other mechanism exists. Both halves have direct
evidence.

**No other mechanism.** The dispatch chain inside `vec_cbind()` (vctrs
`src/bind.c`, `cbind_container_type()`) is: call `vec_cbind_frame_ptype()` on
each data-frame input, feed the zero-column results to `vec_ptype_common()`,
and restore the assembled output against that common container type via
`vec_restore()`. `vec_restore()` dispatches on `to`. So if the frame prototype
is a bare tibble, `vec_restore.nested_results()` is never consulted — there is
no later point on the same call where any nestedtune method runs. The
candidates the brief might have missed all fail:

- `vec_proxy()` is not consulted for the container.
- `vec_cbind()` is not an S3 generic on its first argument; there is no
  `vec_cbind.nested_results()` to write.
- Making `[.nested_results` keep the class on a zero-column subset would feed
  the container path, but it hands a zero-column classed object to every
  caller of `x[0]` through a fully public door — strictly worse than the
  internal generic, and against the M36 rule that a subset holding none of the
  record cannot answer for the run.
- A post-call patch is how dplyr itself solves this exact problem:
  `dplyr::bind_cols()` is literally `vec_cbind(!!!dots)` followed by
  `dplyr_reconstruct(out, first)` (read from dplyr 1.1.x source during this
  review). Even dplyr could not get a subclass through `vec_cbind()`'s core
  and patches afterwards. That option is unavailable to nestedtune because it
  does not own the call sites.

**Defensibility.** Three facts weigh in favor:

- The generic is honored for third-party S3 methods (verified with a toy
  class: `vec_cbind()` calls a `registerS3method`-installed method), is
  exported, and has a help page — "experimental" here is a stability label,
  not a private interface reached by `:::`.
- vctrs itself is a registrant: it ships `vec_cbind_frame_ptype.sf`
  (returning `data.frame()`), added by a commit dated 2020-03-27. The generic
  is load-bearing for vctrs' own sf accommodation and has held its exact
  contract — generic plus `x[0]` default — unchanged for over six years,
  across 0.3.x through 0.7.3, without a single NEWS.md mention. Removing it
  is coupled to vctrs building real colwise primitives and re-solving sf's
  case, not something that happens in a patch release.
- A GitHub-wide code search for `vec_cbind_frame_ptype` outside r-lib/vctrs
  returned 293 hits, every one a vendored copy of vctrs itself (renv and
  revdep libraries, the CRAN mirror). No third-party package registers a
  method. nestedtune would be the first known outside registrant — no crowd
  to stand in, but also no evidence the interface churns; the risk profile is
  "old, stable, unadvertised", not "new, moving".

## 2. Failure modes under a future vctrs, and adequacy of the test guard

Three futures, in decreasing order of likelihood of going unnoticed:

**(i) Export kept, `vec_cbind()` stops consulting the generic** (colwise
primitives arrive). The method becomes inert; the class quietly drops;
`vec_cbind()` returns a plain tibble — exactly what rsample and tune return
today. Only the AC3 test notices. One mitigation is built in: if the
replacement machinery routes columns through `vec_ptype2()`/`vec_restore()`
(the natural shape of real colwise primitives, and what the help page's
"work around the lack of colwise primitives" implies), the already-registered
`vec_restore.nested_results()` would likely keep the class with no frame
prototype involved — the inert case may self-heal.

**(ii) Export removed.** This is *not* quiet, contrary to the comment at
`R/nested-results.R:316-318`. `NAMESPACE:45` carries
`importFrom(vctrs, vec_cbind_frame_ptype)`, so `library(nestedtune)` errors on
every machine holding the new vctrs — a hard load failure, caught by
`R CMD check`, and by vctrs' own pre-release revdep checks if nestedtune is on
CRAN by then. Loud and disruptive, but impossible to miss; the cost is an
urgent patch release, not a silent regression.

**(iii) Contract change** (the dots gain a meaning, a different return is
expected). Most plausibly an error inside `vec_cbind()` on user calls — loud.
A malformed object is remote: the class is attached only inside nestedtune's
own methods, and every rowful path out of vctrs' assembly re-enters
`vec_restore.nested_results()`, whose third branch checks the record columns
and the row count before stamping. The worst token that can escape has zero
rows and zero columns and cannot acquire columns without being re-checked
(measured: `vec_cbind()` on that token with a one-column tibble returns a
bare tibble).

**Is the package-suite test adequate?** Yes, because of a failure-direction
asymmetry the brief's question understates. Keeping the class requires
nestedtune code to run; no vctrs change can make the class *appear* where the
rule would refuse it. The only thing an unnoticed regression can do is shed
the class where it used to be kept — i.e., return what upstream returns, with
no untrue record on it. IP4 cannot be violated by this dependency failing;
what is at stake is door parity, a convenience the documentation promises,
not the inviolable principle. A guard that fires late therefore costs a
temporary reversion to upstream behavior, not a lie. That said, the window
between a vctrs release and the maintainer's next test run is cheap to close:
a CI job running the suite against development vctrs (r-universe binary or
`r-lib/vctrs` remote) turns "when the maintainer happens to run the suite"
into "within a day of vctrs main moving", which is standard tidyverse
reverse-dependency hygiene. On a user's machine nothing needs to fire,
because nothing false can reach a user there.

## 3. Disposition

**Recommend (a): keep the method**, with two supplements (the dev-vctrs CI
job from Q2, and correcting the comment about the removal failure mode).

The weighing that decides it: option (b) is the *failure mode* of option (a).
Removing the method buys, with certainty and today, exactly the state that
keeping it merely risks reverting to during the window between a vctrs
behavior change and the next nestedtune release — and the test names that
window out loud when it opens. When one option's worst case is the other
option's certain case, and the guard is already written, (a) dominates. The
divergence from rsample and tune is already a recorded, deliberate choice
(D-032) resting on the plan-gate reasoning that the invariant is documented
without qualification by entry point; nothing found in this review undermines
that reasoning, and the `bind_cols()` finding above strengthens it — the two
doors are the same vctrs core, differing only in a patch dplyr applies
afterwards, so "which door" is even less visible to a caller than the brief
assumed.

**Is (b)'s hazard genuine or theoretical?** Genuine but low-frequency. A
realistic sequence: a user validates
`bind_cols(res, fold_notes) |> collect_metrics()` interactively, then moves
the column-add into code that reaches `vctrs::vec_cbind()` instead — their
own vctrs-style helper, or a dependency that calls `vec_cbind()` on the
object it was handed (any package doing so reproduces `bind_cols()` minus
dplyr's patch). Under (b) the result silently becomes a plain tibble; the
user's downstream `inherits(x, "nested_results")` branch, or S3 dispatch on
`collect_metrics()` and `print()`, silently takes the not-a-results-object
path. No error marks the point of divergence, which is what makes it
misleading rather than merely inconvenient. The frequency is low — end users
rarely call `vec_cbind()` by hand — so (b) is livable and upstream lives with
it; but (a) is available at the cost already analyzed.

**(c) third shapes considered and set aside.** A load-time or `.onLoad`
self-check (cbind a tiny synthetic, warn if the class dropped) reports a
condition to users who cannot act on it and taxes every session's startup;
the CI job delivers the same signal to the one person who can act. Wrapping
or masking `vec_cbind()` is out of bounds per the brief's constraints and
would not reach direct `vctrs::vec_cbind()` calls anyway.

**The upstream ask** (in bounds, worth making): on the #32 thread or a fresh
r-lib/vctrs issue, ask for either (i) `vec_cbind()` finishing with a restore
against the first data-frame input's full type — the behavior
`dplyr::bind_cols()` hand-patches in, promoted into the core — or (ii)
`vec_cbind_frame_ptype()` stabilized out of `[Experimental]`, on the evidence
that vctrs' own sf method has depended on its unchanged contract since
March 2020. Either lands this package on supported ground; (ii) costs
upstream nothing but a label.

## 4. The empty-container branch

Sound, with one leak that is real but inconsequential.

**No rowful exploit exists.** The branch fires only when `x` has no columns
and no rows and `to` has no columns; its output therefore has no columns. To
convert that token into an object whose record is untrue of rows it holds, a
caller must give it columns or rows, and every door that can is re-checked:
`vec_cbind(token, tibble(a = integer()))` returns a bare tibble (measured),
any `[` subset sheds through `reconstruct_results()`, `vec_rbind()` and
`vec_c()` route through `vec_restore()`'s checked branches. I found no
sequence of public calls producing a `nested_results` with rows and a false
record through this branch.

**The leak.** A caller *can* hold the zero-column token itself, because the
generic nestedtune registers on is exported from vctrs:
`vctrs::vec_cbind_frame_ptype(res)` returns, directly to the caller, a frame
with 0 rows, 0 columns, class `nested_results`, and `folds_attempted = 3`
(measured); `vctrs::vec_restore(tibble::tibble(.rows = 0), that_token)`
returns the same object through the branch under review. Two rough edges on
the token: `print()` errors on it (`invalid argument type` — the print method
assumes the record columns), and `collect_metrics()` aborts with "All 0 outer
folds failed", a refusal whose wording is untrue of a token but is at least a
refusal, not a fabricated estimate. Severity: negligible — the route requires
deliberately calling a vctrs function marked internal — and the Q5 change
below would make even a leaked token claim nothing false. Not worth a guard
of its own.

## 5. The prototype carrying `folds_attempted`

**A violation in letter, not in substance — and the letter is cheap to
satisfy if wanted.**

Measured first: through every supported door, no caller receives the
record-bearing prototype. Exported `vctrs::vec_ptype()` and
`vctrs::vec_ptype2()` on a `nested_results` both return a bare tibble
carrying none of the five attributes (measured; AC5's test correctly asserts
only "a data frame, 0 rows"). The classed, counted prototype exists inside
vctrs' assembly and on the internal-marked surfaces named in Q4, nowhere
else.

On substance: IP4 governs what the package presents to a caller as a record
of a run. A prototype is the run's description *in transit* — it plays
exactly the role the `template` argument plays in `reconstruct_results()`,
and a count read off a function's template argument is a claim about the
operation's source, not about the argument's own rows. Nobody holds the
token as a results object through a supported door, so I judge it outside
what IP4 governs in substance. Flagging per the brief's constraint: this is
an interpretation of IP4's scope, not a trade against it — if the maintainer
reads IP4 as governing every object wearing the class anywhere, then the
prototype violates it and the fix below applies.

**What would carry the count instead.** The two counts are the only
attributes on a prototype that assert something about rows; `grid`,
`metrics` and `outer_label` describe the run and are true of any object from
it. So: have the prototype carriers (`nested_results_ptype()`, the frame
prototype method, via `copy_results_attributes()`) write `grid`, `metrics`,
`outer_label` and one private attribute — say `nestedtune_template_rows` —
holding the source's row count, and omit `folds_attempted` and
`folds_completed` entirely. `vec_restore()`'s third branch reads the private
attribute for its row-count check; `bare_results()` strips it alongside the
five. Restored objects lose nothing because `stamp_results()` already
recomputes both counts from the rows rather than copying them. The change is
roughly ten lines across four functions and does not touch D-031's one-rule
constraint — it changes how the template's row count travels, not the rule.
It also blanks Q4's leak: a token obtained through vctrs' internal surface
would then carry no count at all.

## Beyond the brief

- **`dplyr::bind_cols()` is `vec_cbind()` plus `dplyr_reconstruct()`.** The
  parity AC3 asserts is between two calls sharing the same vctrs core; the
  entire difference is dplyr's post-hoc patch. This reframes the method under
  review as making the shared core produce what dplyr patches in by hand —
  and it means a caller has even less ability to predict the door than the
  plan gate assumed, since the "dplyr door" *is* the vctrs door plus a fixup.
- **The in-code comment overstates graceful degradation.**
  `R/nested-results.R:316-318` says that if the generic moves, `vec_cbind()`
  falls back to the default and the AC3 test says so. True only for the
  stops-being-called case; if the export is removed, the `importFrom` at
  `NAMESPACE:45` makes the package fail to load. The comment should name both
  modes.
- **`nested_results_ptype()`'s comment describes the internal lattice, not
  the exported answer.** "The common type of a `nested_results` with a table
  is the `nested_results` prototype" holds inside `vec_cbind()`'s assembly,
  but the exported `vec_ptype2()` hands the caller a bare tibble (measured).
  Nothing is wrong; one clarifying sentence would stop a future reader from
  "fixing" the apparent mismatch.

## Recommendations

1. **Apply — keep `vec_cbind_frame_ptype.nested_results()`** (disposition a),
   with the AC3 test as written. The dependency's failure direction is the
   honest one; the generic is six years stable and load-bearing inside vctrs
   for sf; no alternative mechanism exists.
2. **Apply — correct the comment at `R/nested-results.R:316-318`** to name
   both failure modes: generic no longer consulted → quiet fallback to a bare
   tibble, caught by AC3; export removed → load-time failure via the
   `importFrom`, caught immediately everywhere.
3. **Apply — add a CI job running the test suite against development vctrs**
   (r-universe or `r-lib/vctrs@main`), so a change in either direction
   surfaces within a day of upstream moving rather than at the next local
   test run.
4. **Consider — move the fold counts off the prototype carriers** onto a
   private row-count attribute read by `vec_restore()`'s third branch and
   stripped by `bare_results()` (Q5). Satisfies IP4's letter on type tokens
   and empties Q4's leak; ~10 lines; no user-visible change through any
   supported door.
5. **Consider — raise the upstream ask on r-lib/vctrs**: stabilize
   `vec_cbind_frame_ptype()` (citing vctrs' own sf method, unchanged since
   2020-03-27) or restore `vec_cbind()` output against the first data-frame
   input's full type, as `dplyr::bind_cols()` already patches in.
6. **Reject — a load-time or runtime self-check** that probes whether
   `vec_cbind()` still keeps the class: it warns users who cannot act, taxes
   every session, and duplicates what recommendation 3 delivers to the person
   who can act.
7. **Reject — disposition (b), removing the method**: (b) is (a)'s failure
   mode, purchased with certainty instead of risked behind a named test; the
   door-dependence it accepts is a genuine (if low-frequency) silent
   wrong-branch hazard, and D-032 has already paid the documentation cost of
   the divergence in the other direction.
