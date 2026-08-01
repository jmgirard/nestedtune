# M26: The wire figure survives re-derivation

**Status:** done (2026-08-01, PR #27 https://github.com/jmgirard/nestedtune/pull/27)

**Goal:** The per-fold wire comparison between the current dispatch and a
mori-shaped one, measured as mirai actually serializes it (one stream), in the
installed state, with the probe asserting its own headline.

**Outcome:** `benchmarks/mori-wire-manifest.json` — 9 figures, each with fixture,
install-dependence flag and two asserted oracles: lean ~941.7 kB / 1 copy vs
modelled mori ~103.1 kB / 0 copies, **9.13x**; gap ~838.6 kB, data-dominated;
worker closure 524 B installed vs 291 kB dev (all prior 3.87x figures were
`load_all()` artifacts). `assert_oracle()` registry refuses unbacked oracle
strings. Cross-process totals move with the pid's serialized hex length;
`reproducibility` field bounds drift checks at ~20 B. No `R/` changes.

**Decisions:** none milestone-local; maintainer decisions at the unblock gate —
finish mechanically, M29 downscoped to internal-note-only (port context, M28).

**Review:** five passes, four returns (thrash triggers fired; one re-cut; parked
`blocked` once). Pass 5: 32 findings, 20 >= 80, 19 fixed (registry, marginal
invariance oracle, publishing-value AC1 guard, document corrections), G26
rejected with reason. Lessons harvested: srcref/install-state artifact,
cross-process byte-instability, top-level `on.exit()` in Rscript.
