# Lessons

_Durable "how this repo behaves" notes — build quirks, testing tricks,
toolchain gotchas. Captured at milestone end, harvested at plan time._

_One lesson per line. Current knowledge, not history: a lesson proven false
is **corrected in place** and marked (`(M07, corrected M11)`); git holds the
original. A lesson is **retired** — leaving no line behind — once a test
fails on the mistake it warns about, another tracking file's slot owns the
content, or a matured family graduates whole into a doctrine module._

_Hard cap: 50 lines._

## Lessons

- `cairn/references/INDEX.md` entries must be bullet lines (`- page.md — what it covers`); the references check matches only that form, so a table-formatted index reads as empty and every page reports "no INDEX.md line". (design interview, 2026-07-25)
