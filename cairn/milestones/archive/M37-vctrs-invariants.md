# M37: The vctrs half, so `rbind()` stops claiming a design it never ran

**Status:** done (2026-08-31, PR #46 https://github.com/tidymodels/nestedtune/pull/46)

**Goal:** Register the vctrs compatibility methods tune ships beside its dplyr ones, so operations reaching `nested_results` through vctrs obey the same invariants, and close `rbind()`, which reaches neither.

**Outcome:** `vec_restore.nested_results()` carries the rule M36 built. Five `vec_ptype2` and five `vec_cast` pairs among `nested_results`, `tbl_df` and `data.frame` return the union of both sides' columns and reconcile every cast. `vec_cbind_frame_ptype.nested_results()` is what makes a column add keep the class, and only where the results object leads; the prototype carriers travel the run's description plus private `nestedtune_template_rows` and `nestedtune_template_record` rather than fold counts. `rbind.nested_results()` and `names<-.nested_results()` close the two doors reaching no generic, so `rbind(x, x)` and a `rename()` moving a record column hand back bare tibbles where rsample and tune both keep theirs. `stamp_results()` and `copy_results_attributes()` split out of `reconstruct_results()`. `vctrs (>= 0.6.1)` joins Imports, `tibble` Suggests. Closes #32.

**Decisions:** D-032 (dependency, the `rbind`/`rename` divergences), D-033 (resting on vctrs' experimental frame-prototype generic, on RB04/RR04), D-034 (`tibble` in Suggests), D-035 (argument-order rule, column-reconciling common type). Milestone-local: RR04's Q1–Q5 answers.

**Review:** Two rounds, three lenses each. Round one returned the milestone on two confirmed defects — the casts ignoring the other side's columns, and `vec_cbind()` keeping the class after name repair moved a record column — repaired by T6 and T7. Round two: all seven criteria fresh-green, `check()` OK, eleven findings. Fixed at the gate: D-035 written inside the template comment block, a false frame-prototype comment, the help page's "one rule" claim (single-argument `vec_rbind()` sheds where `bind_rows()` keeps), the NEWS argument-order line, and `air` formatting. Seven findings deferred to a candidate row.
