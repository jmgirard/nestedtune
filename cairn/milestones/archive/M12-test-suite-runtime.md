# M12: Fitting time only where an assertion needs it

**Status:** done (2026-07-27, PR #12 https://github.com/jmgirard/nestedtune/pull/12)

**Goal:** No test fits a model whose result no assertion reads, and no CI job
runs longer than an answer is worth waiting for.

**Outcome:** Suite 327.3 s → 125.6 s (38.4%), 1207 pass / 0 fail / 0 skip.
`memoised()` in `helper-orchestration.R` caches a `nested_tune_grid()` /
`nested_final_fit()` call, keyed by `fixture_key()` on the canonical form of the
callee, the arguments, the caller-scoped names the design's `inside` spec
resolves, and the RNG state; `canonical_form()` expands environments and cuts
cycles. A hit is `identical()` and replays every condition. Six files converted
(22 fixtures, 78 requests); `benchmarks/` gains a profiler, a baseline and a
mutation harness; both CI jobs cap at 20 min.

**Decisions:** Canonical-value hash over a caller-declared label, on measured
`rlang::hash()` instability for workflows and metric sets. Report rows group by
what was built, not call text. AC3 amended and ratified at the merge gate: no
skip added to a *pre-existing* test.

**Review:** Three lenses, 10 findings. Actioned A(90) key by function value not
deparsed name, B(93) key the caller names the spec resolves, C(92) replay all
conditions, E(82), H(82) restore M11 F1's dropped clause, I(80) fix the cap's
claim. Logged F(78), D(75) — fixed anyway; J(60) ratified; G(45) rejected.
