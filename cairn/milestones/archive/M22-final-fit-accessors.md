# M22: What selection saw has a name

**Status:** done (2026-07-30, PR #23 https://github.com/jmgirard/nestedtune/pull/23)

**Goal:** Give `nested_final_fit` named accessors for the tuning run its parameters were
selected from and the candidates that run scored, replacing an undocumented list slot.

**Outcome:** `extract_tune_results()` returns `x$tuning` unreduced;
`extract_scored_candidates()` delegates to `scored_candidates()`, so its table is
shape-identical to a fold's `.grid`, `.config` included. Both are S3 generics this package
OWNS — its first, forced because neither tune 2.1.0 nor hardhat defines either name — each
with a `.default` aborting as classed `nestedtune_no_extract_method` via a shared
`abort_no_extract_method()`; `rlang::current_env()` and not `caller_env()` there, the former
rendering the generic's own call. `print.nested_final_fit()` names both doors with the bias
caution beside the tuning-run one, RR02 BC4's no-number constraint holding unmodified.

**Decisions:** D-023 (names, generic shape, `.config` retained; four alternatives rejected);
none milestone-local. The gate also declined a `nested_results` method for either generic —
`.grid` is that object's per-fold surface and pooling it asserts a menu M21 measured false.

**Review:** three lenses, 15 findings (diff-bug 15, blame 0, prior-review 0). Actioned: P1 (82)
`@return` cross-referenced a `.notes` column this class lacks, repointed at
`tune::collect_notes()`; T3 (80) an agreement test comparing `names()` only, which could not
fail. Thirteen logged, T2/T1/T7 (78/76/74) surfaced at the gate. A plan-time [O] criteria
audit had already caught a vacuous AC5 and a false AC2. M09's lesson extended; none retired.
