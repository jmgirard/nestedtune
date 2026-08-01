# Draft reply to topepo on tune#969 (second)

Drafted 2026-07-31. **Not posted.** Posting is the maintainer's call.

Replies to his 2026-07-31 comment: he accepts landing the outer loop in tune
(D-024 clause 1 now probable, not yet settled), opens the resampling object
itself to redesign, raises mori (tune#1188), and proposes a call in the third
week of August.

Written without em dashes, per request.

---

Third week of August works well, thanks. Ping me whenever suits and I will make
the time.

Between now and then I am happy to chip away at whatever is most useful. Three
things I could look at, in the order I would guess is most helpful:

1. **What the outer loop needs from the resampling object.** Since you are open
to a new object rather than `nested_cv()`, I can write up what the driver
actually reads from it, what it has to reconstruct because the current shape
does not carry it, and where the current class boundaries get in the way. Your
reindexing idea, keeping one `data` and reindexing the inner splits, is the same
conclusion I reached from the memory side, so I can bring measurements for that
rather than just an opinion.

2. **mori.** I have not evaluated it. I can read #1188 and check it against the
reproducibility behavior I measured on the mirai path, since seeding the outer
loop cleanly depends on how the backend hands streams to workers. If mori
changes that story, better to know before the design settles than after.

3. **The port itself.** I can separate what is genuinely outer-loop logic from
what is only glue around tune's current surface, so we have a concrete list to
talk through rather than a package to translate wholesale.

Happy to do all three, one of them, or none if you would rather scope it live in
August. Just tell me which is least useful so I do not spend time on it.
