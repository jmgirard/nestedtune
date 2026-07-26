# M05: The final model is its own object

**Status:** done (2026-07-26, PR #5 https://github.com/jmgirard/nestedtune/pull/5)

**Goal:** Ship `nested_final_fit()`, which re-runs the tuning procedure on the
complete dataset and hands back the resulting model as its own object.

**Outcome:** `nested_final_fit(object, resamples, grid, metrics)` re-evaluates
the design's stored `inside` call against every row, tunes, selects, finalizes,
and fits; `final_fit_worker()` holds the body after the seed draw.
`new_nested_final_fit()` carries workflow, selection, tuning run, and both
seeds; `extract_workflow()` is the door and is re-exported.
`print.nested_final_fit()` shows no number from the tuning run and points at
`.selected`. `check_inside_spec()`/`eval_inside_spec()` refuse a design that
cannot be re-run. `nested_tune_grid()`'s print and docs now name it.

**Decisions:** D-014 (shape and naming), D-015 (IP1's middle clause narrowed),
D-016 (tuning seed's scope covers building the resamples). RB02/RR02 archived;
BC1–BC6 became AC7–AC12 with one recorded deviation (BC6's ambient-kind clause
asserted at the worker, since the entry seed draw is itself kind-dependent).

**Review:** Two lenses clean; [O] diff-bug found 6. Two scored >=80, both fixed:
F5 (90) five shared abort branches unfired through the new export, F4 (87) four
RNG tests on the deterministic engine where AC3 says ranger. F1 (78), F2 (65),
F3 (52), F6 (48) logged; F1 became a candidate row. Nothing retired.
