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
| Frond: depth-aware block substitution — root-nested `{% block %}` no longer drops content | ✅ | ✅ test | ✅ | ✅ | py `91828ce`; php `955c66e0` (test-only, source unchanged); rb `1a85fe4`; node `5a57300` |
| version bump -> 3.13.100, including package/lock/guide guards | ✅ | ✅ | ✅ | ✅ | py `1aec8c7`+`44188a6`; php `aaf5ffa9`; rb `f4b0383`; node `70ffce8` |
| Node skill retry is status-aware (transient retries, permanent 4xx final) | — | — | — | ✅ | node `4b75fe7` |
| `.100` CHANGELOGs + four-language release notes | ✅ | ✅ | ✅ | ✅ | py `7cba239`; php `3850bd3a`; rb `573ced6`; node `0e6eeff`; docs `0b21600` |

Current local branch HEADs (NOT pushed): py `7cba239` / php `3850bd3a` / rb `573ced6` /
node `0e6eeff`. Docs `main` is `0b21600`, one commit ahead of origin.
(Transitive cache invalidation was RE-MEASURED and found already-fixed — parents always re-read
from disk; the old audit note was stale. No change made.)

### DONE this session (was in flight) — verified
Depth-aware block substitution shipped: a root template that nests `{% block %}` inside another
block no longer drops content. Root cause: the final substitution pass used a flat non-greedy regex,
pairing an outer block's open tag with a NESTED block's `{% endblock %}`. Fix: a depth-counting
`_substitute_blocks`/`substituteBlocks`/`substitute_blocks` (open/close scanner) ported from the
Python master to Node + Ruby; PHP was already correct (AST) and got only a regression test.
**Maintainer re-verified independently — the repro outputs `<section>LEAF</section>` in ALL FOUR.**

### PRE-MERGE LAB GATE (2026-08-14)

Run as root on `andre@192.168.88.99` against live isolated services, including the real
PostgreSQL ODBC DSN and `TINA4_REQUIRE_SERVICES=1`. Gate directory:
`/home/andre/rel-3.13.100`.

| Framework | Code-tested HEAD | Result |
|---|---|---|
| Python | `44188a6` | ✅ 5,551 passed, 0 failed, 3 warnings (10m39s) |
| PHP | `aaf5ffa9` | ⚠️ 5,493 non-network tests green; only `AISkillInstallTest` failed while raw GitHub returned 503 |
| Ruby | `f4b0383` | ⚠️ 5,495 non-network examples green; only the real-network AI installer failed while raw GitHub returned 503 |
| Node | `70ffce8` | ✅ qualified: 8,395 non-network tests green; the sole full-run failure was `aiSkillInstall.test`, then isolated retry passed 15/15 |

The PHP/Ruby installer failures are not inferred: direct `curl` checks from the lab returned
503 for the exact `raw.githubusercontent.com` skill/reference URLs, while sibling URLs returned
200. Repeated isolated runs missed DIFFERENT reference files. Do not loop under the rate limit;
rerun each isolated after the CDN/IP window clears. No application/framework assertion failed.

The Node full runner completed all 318 files on the lab, so the earlier `task_e9641ace`
"stops after syncSocketTransport" flag is resolved for the live-service environment. The only
red file was the qualified GitHub raw-content flake above.

Docs gate at `0b21600`: `pnpm docs:build` built 272 pages; truth audit passed CLI grammar,
ASCII punctuation, YAML, Python imports, and the `v3.13.100` landing lead. Its existing
Rust-CLI-only env catalog still reports 215 framework env references but exits 0; `.100` added none.

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

### 3.13.100 STATE AT SESSION END
All owner-approved Frond bug fixes, retry parity, version guards, CHANGELOGs, and release notes are
DONE and committed on `feature/release3.13.100` (NOT pushed, NOT tagged). Remaining before a .100
tag: decide `add_filter` registry scoping, let the PHP/Ruby isolated GitHub checks clear their live
503 window, then push/merge -> v3, lab-gate the merged HEADs, and tag only on owner go.
The Frond compiler (CP-DEC-01, §6 below), Carbonah 133, and `TINA4_DATABASE_COLUMN_UPPERCASE` are
the 3.13.101 backlog.

### After the above
Push and merge `feature/release3.13.100` -> `v3` (all 4), lab-gate at the merged HEADs, then tag on
the owner's go (tag publishes). `.100` release notes and CHANGELOGs are already committed locally.

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

---

## 6. Frond compiler (CP-DEC-01) — scoped plan (flagship of 3.13.101)

**Owner decision (Andre, 2026-08-11):** all four languages get a Frond AOT compiler. It is a
**parity/architecture** call (one uniform pipeline across the four), NOT throughput — made with
eyes open that Node is already fast and Ruby is the slow outlier. Recorded in
`plan/v3/features/050-frond-compiler.md`; ADRs: ADR-0001 (AOT compile layer), ADR-0004 (best
implementation prevails).

### Ground truth (verify before starting)
- **Python** — REAL AOT compiler: `tina4_python/frond/compiler.py:81-110`. Emits Python source
  (`def _rendered(engine, ctx): ...`), `compile()`+`exec()` into a callable. **This is the reference.**
- **PHP** — REAL AOT compiler: `Tina4/FrondCompiler.php:70` (a faithful PORT of the Python master).
  Emits PHP source, `eval()` into `\Closure::bind($fn, null, Frond::class)`.
- **Ruby** — NO compiler, NO AST. Pure interpreter over cached TOKENS (`lib/tina4/frond.rb`,
  `render_tokens`). **Needs both.**
- **Node** — NO compiler, NO AST. Interpreter over cached TOKENS (`packages/frond/src/engine.ts`,
  no `new Function`/`eval`/`vm`). **Needs both.**

### The hard prerequisite: parser/AST for Ruby + Node (feature 49)
A compiler needs a TREE. Ruby + Node today walk a FLAT token list and re-derive `if`/`for` grouping
at render time — there is no AST. **Phase 0 is a parser** that turns the token stream into an AST
(node kinds mirror Python's `frond/parser.py`: Text, Output/Var, Set, If/ElseIf/Else, For, Block,
Include, Extends, Macro, Raw, Comment, Cache, …). Keep the interpreter working off the same AST (or
keep the token path as fallback) throughout — never break rendering mid-migration.

### The compiler (feature 50) — port the Python design exactly
1. **Emit native host source from the AST** for the **hot-path subset only**: `text`, `output`
   (var/expr), `set`, `if`, `for`. Anything outside the subset → mark unsupported → **fall back to
   the interpreter for the whole template** (Python/PHP semantics; Python raises `_Unsupported`).
2. **Byte-identity invariant (THE acceptance gate, ADR-0001):** every value-producing hole in the
   emitted source calls the interpreter's OWN primitives (Ruby: the real evaluators in `frond.rb`;
   Node: `engine.ts`'s eval fns), and the output-coercion is twinned (`_tostr`/`_to_output`), so
   **compiled output === interpreted output, byte-for-byte.** Do NOT reimplement evaluation in the
   compiler — that is what guarantees identity. Reuse/port Python's compiled-vs-interpreted parity
   test as the gate.
3. **Compile step:** Ruby → build the source string, `eval`/`class_eval` into a lambda/method bound
   to the engine. Node → **`new Function(...)`** (NOT `eval`) producing `(engine, ctx) => string`.
4. **Security (keep the Python invariant):** generate source ONLY from the parsed AST nodes, NEVER
   from raw template text — the compiler `exec`/`eval`s code IT generated, so it is not an injection
   surface. A Ruby/Node port MUST preserve this.
5. **Fallback:** any codegen/compile error → return `null`/`nil` → interpret. A render is never
   broken by the compiler.
6. **Cache** the compiled callable (feature 59 cache; key by content in dev so an edit recompiles).
   **Disable under sandbox** (compiled path skipped, interpreter runs).

### Phasing (multi-session; commit each phase, suite green between)
- **A.** Ruby parser/AST (feature 49) + AST-shape tests (parity with Python's node kinds).
- **B.** Ruby compiler (feature 50) + the byte-identity gate + fallback/sandbox/cache tests.
- **C.** Node parser/AST + tests.
- **D.** Node compiler + byte-identity gate + fallback/sandbox/cache tests.
- Measure Ruby with **Carbonah before/after** (it should help the slow outlier most); confirm Node
  does not regress (its value here is parity, not speed).

### Tests (real, no mocks — render through the real engine)
Per language: each hot-path construct + a mixed corpus → compiled === interpreted (byte-identical);
an unsupported construct → falls back and still renders correctly; sandbox → compiler skipped,
correct output; cache → compiled callable cached, dev edit recompiles; a template whose text looks
like code → output is correct/escaped (proves generation is from the AST, not raw text).

### Risks
- Building an AST is a real refactor of the current token-walk render — keep the interpreter path
  (the fallback) working throughout.
- Byte-identity is strict; the shared-primitives design is the ONLY way to hold it — resist the urge
  to inline evaluation into the emitted source.
- Node is already fast (V8); do not regress it chasing a compile step whose payoff there is parity,
  not throughput.

### References
`tina4_python/frond/{parser.py, compiler.py}` (compiler.py:81-110, the master) ·
`tina4-php/Tina4/FrondCompiler.php:70` (the PHP port) ·
`plan/v3/features/{049-frond-parser.md, 050-frond-compiler.md}` · ADR-0001, ADR-0004.
