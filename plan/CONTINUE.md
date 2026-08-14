# CONTINUE — session handoff (2026-08-14)

Pick-up notes for the next Tina4 maintainer session. Read `.claude/skills/tina4-maintainer`
first. Branch model: `feature/release<ver>` -> `v3` (the active release mainline) -> tag.

---

## 1. 3.13.99 — SHIPPED (done, do not redo)

Published to PyPI / Packagist / RubyGems / npm. Tags `3.13.99` (bare, no `v`) on all 4 repos'
`v3`. GitHub CI green on all 4 (Tests + Docker). Docs pushed (`.98` + `.99` release notes live).
Skills installer on `tina4/main` pins `3.13.99`.

Final shipped v3 SHAs (for reference): py `af13de7` / php `b451fb1e` / rb `1ca5ce1` / node `8c33e4e`
(then tags were cut). 3.13.99 = Phases 1-5 (~30 breaking parity/security fixes + logger & adapter
conformance grids). Frond Phase 6 was deferred to 3.13.100.

**Notable .99 late fixes worth remembering:** example app was importing feature-132's renamed
`assert_*` test descriptors (broke the Docker image); node `tina4_migration` table used ANSI
double-quotes MySQL parses as a string literal (failed on fresh MySQL); node docs reflection
re-walk blew CI's time budget; GitHub CI had no ODBC/Firebird-in-main provisioning (fixed in each
repo's `.github/workflows/test.yml`).

---

## 2. install_skills 503 — root cause + status (a live user issue)

`curl tina4.com/install-skills.sh | sh` (and `tina4 ai`) hit `curl: (56) ... 503`. **Not a missing
file** (503 != 404 — every 3.13.99 skill file returns 200). Cause: `raw.githubusercontent.com`
503s intermittently under load — a freshly cut tag is "cold" on GitHub's CDN for minutes, and the
lab/dev machine's IP was rate-limited from many test runs. Transient; clears within ~an hour.

**Fix deployed:** `tina4/install-skills.sh` + `.ps1` now retry (`--retry 3 --retry-delay 2` /
`-MaximumRetryCount 3 -RetryIntervalSec 2`) — committed + pushed to `tina4/main` (`20fc6a1`), served
live via the tina4.com shim. (An earlier `retry 8 x 5s` was reverted — 40s hang was worse UX.)

---

## 3. 3.13.100 — IN PROGRESS (branch `feature/release3.13.100` in all 4, NOTHING pushed/tagged)

Owner cut this session: "open Frond bugs first" (compiler deferred within .100).

### Done + independently verified (main loop re-ran the tests, not just worker green)
| Item | py | php | rb | node | Commits |
|---|---|---|---|---|---|
| install_skills 503 retry + real local-socket test | ✅ | ✅ | ✅ | ✅ | py `09dd6b8`; php `aaeba4fc`+`45730d7f`; rb `386dfa8`; node `b859bcf` |
| Frond: 2nd `{% extends %}` raises + tests | ✅ | ✅ | ✅ | ✅ | py `9bb7279`; php `c7739aa0`; rb `6bed111`; node `831bd57` |
| Frond: cache bound + TTL-sweep (template + `{% cache %}` fragment + expr memos) | ✅ | ✅ | ✅ | ✅ | py `82e02de`; php `236dbabc`; rb `5f49e32`; node `d1e6b42` |
| Frond: ruby multi-level `{% extends %}` recursion (+depth-aware extract_blocks) | — | — | ✅ | — | rb `914bc16` |
| version bump -> 3.13.100 | ✅ | ✅ | ✅ | ✅ | in each repo |

Branch HEADs at handoff: py `82e02de` / php `236dbabc` / rb `5f49e32` / node `d1e6b42`.
(Transitive cache invalidation was RE-MEASURED and found already-fixed — parents always re-read
from disk; the old audit note was stale. No change made.)

### IN FLIGHT — verify when it lands
Worker `ab0076f37a2c7faaa` (tina4-dev): **depth-aware block substitution** — fixes a CONFIRMED
content-loss bug where a ROOT template with a `{% block %}` nested inside another block drops
content. Live outputs of the repro (root nests `inner` inside `body`, leaf overrides `inner`):
Python `<section></section>`, Node `<section></section>`, Ruby `<section></section>` = **WRONG**;
PHP `<section>LEAF</section>` = **CORRECT** (AST-based, depth-aware). **Owner approved fixing now.**
Fix lands in py/node/ruby (make the final block substitution depth-aware, matching PHP). PHP is the
reference for correct behaviour — do NOT change PHP. When the worker reports: re-run the repro in
all 4 yourself; all must output `<section>LEAF</section>`; run each full frond suite.

### PENDING OWNER DECISION (do not change without the owner)
- **`add_filter`/`add_global`/`add_test` registry scoping.** Calling these on an INSTANCE also
  writes the shared CLASS registry (documented dual-call parity, identical in all 4). Test-isolation
  risk (only Python's test fixture resets between tests). Keep global (current) or make
  instance-scoped (breaking)? Owner has not decided.

### NOT STARTED (remaining .100 backlog)
- **Frond compiler (CP-DEC-01)** — the flagship, deferred. Owner decision: ALL 4 get a Frond
  compiler. Python + PHP have a real AOT compiler; **Ruby + Node have none** and have **no AST** —
  they must build a parser/AST FIRST, then the compiler (emit native host source reusing the
  interpreter primitives per hole; hot-path subset text/output/set/if/for + interpreter fallback;
  cached; sandbox-disabled; generated from the parsed tree). Recorded as CP-DEC-01 in
  `plan/v3/features/050-frond-compiler.md`. Large, multi-session.
- **Carbonah 133** benchmarks (deferred from .99).
- **`TINA4_DATABASE_COLUMN_UPPERCASE`** switch, all 4 (deferred from .99). Owner wants a switch so
  Firebird/PHP lowercase field results can be forced uppercase across all frameworks.
- **Node retry status-awareness** (small): node's install_skills retry fires on ANY failure incl a
  permanent 404 (one wasted request, no backoff); py/php/ruby correctly skip a genuine 4xx. Align it.

### After the above
Merge `feature/release3.13.100` -> `v3` (all 4), lab-gate at the merged HEADs, then tag on the
owner's go (tag publishes). Update `.100` release notes (docs `36-releases.md` all 4 + landing
`docs/index.md`) and the CHANGELOGs BEFORE the tag.

---

## 4. Environment recipe (lab + CI)

- **Lab:** `ssh andre@192.168.88.99` (Ubuntu, passwordless sudo). Full live services. Full-suite env:
  `set -a; source /root/tina4-lab/lab-env-for.sh <py|php|rb|node>; set +a` + ODBC DSN (NOT set by
  lab-env-for.sh) + `TINA4_REQUIRE_SERVICES=1`. Release dir `~/rel-3.13.99/<repo>` (reusable; rename
  or reuse for .100). Parallel gate script: scratchpad `lab-fullsuite-v3.sh` (fetches origin,
  checks out the SHA, runs 4 langs concurrently). NOTE the AI skill-install test flakes under
  4-parallel GitHub load (GitHub-raw rate-limit) — a lone skill-install failure is that flake;
  re-verify it isolated (it passes one-at-a-time). Python provisioning on lab: `/snap/bin/uv sync
  --extra test`. Ruby: `bundle config set --local with "databases:firebird:odbc"`. Node:
  `npm run build --workspaces` then `npx tsx test/run-all.ts`.
- **GitHub CI** now provisions ODBC + Firebird + MySQL-over-TCP in each repo's `test.yml` (fixed
  this session). MySQL host MUST be `127.0.0.1` not `localhost` (localhost = unix socket).
- **docs:** `cd tina4-documentation && python3 scripts/audit-truth.py --strict` (CI gate) +
  `pnpm docs:build` must be green before pushing docs. ASCII only, no em dashes.

## 5. Discipline reminders (this session's lessons)
- Verify, don't trust: a worker's "premise" can be wrong — worker a2115b03 caught that Python's
  claimed `<section>LEAF</section>` was actually `<section></section>` (a real shared py/node bug).
  Always re-run the repro yourself.
- One writer per tree: don't commit into a repo a worker is editing.
- Frameworks tags are BARE (`3.13.100`); the tina4 CLI repo uses `v`-tags.
- Commit trailers: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` +
  `Co-Authored-By: Tina4 <82961293+tina4stack@users.noreply.github.com>`.
