# Release 3.13.72 - reported-issue batch

## Goal

Fix the four genuinely-new/unaddressed reported issues, at full cross-framework
parity, with real (no-mock) lock-in tests. One coordinated all-4 release.

## Context

Issue triage (2026-07-12) found most open issues are fixed-and-awaiting-close.
Four are new/unaddressed. Three scoping agents mapped the blast radius against
the real engines / a real PostgreSQL 16.14; findings below are empirical, not
guesses.

Severity order: #33 (security) first, then the Frond pair, then #57 (test +
comment only).

---

## A. nodejs #33 - malformed-path process crash (P1, SECURITY, Node-only)

`GET //` (also `///`, `/\`) crashes the Node worker in PRODUCTION: `new URL(req.url, base)`
at `tina4-nodejs/packages/core/src/request.ts:49` throws `ERR_INVALID_URL`, and it runs at
`server.ts:1051` BEFORE the dispatch try/catch (`server.ts:1136`). The `uncaughtException`
handler only registers under `TINA4_DEBUG` (`devAdmin.ts:437`), so prod has no net -
unauthenticated remote DoS (scanners send `//` routinely). Confirmed by live repro.

Python / PHP / Ruby verified SAFE: each takes the path as an opaque string (ASGI
`scope["path"]` / `$_SERVER['REQUEST_URI']` / Rack `PATH_INFO`), no throwing URL parser,
plus per-request isolation. They return a clean 404 today.

### Scope
- [ ] Node: guard `new URL(...)` at `request.ts:49` - on `ERR_INVALID_URL`, derive `path`
      from raw `req.url` (split on `?`) and build a safe fallback so routing yields a normal
      404 (or short-circuit a clean 400). Must cover `//`, `///`, `/\`.
- [ ] Node: do NOT rely on the dev-only ErrorTracker; the guard must work with `TINA4_DEBUG` unset.
- [ ] Python / PHP / Ruby: no code change (verified safe) - add a lock-in test only.

### Tests (real, no mock)
- [ ] Node: boot a real server, raw TCP `printf 'GET // HTTP/1.1\r\nHost: localhost\r\n\r\n' | nc`,
      assert 4xx AND the process still accepts a following request. Cases: `//`, `///`, `/\`.
- [ ] Python / PHP / Ruby: parity lock-in - a malformed path (`//`) returns 4xx, server survives.

### Parity
| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| crashes on `//` | safe | safe | safe | FIX |
| lock-in test | add | add | add | add |

---

## B. Frond #170 - number_format ignores decimalPoint + thousandsSep (ALL 4)

Twig signature is `number_format(decimals, decimalPoint, thousandsSep)`. All four Fronds
hardcode `.`/`,` and drop args 2 and 3, so localized formats (`1.234,50`) are impossible.
Mechanically identical everywhere; Python is master.

Locations: Python `frond/engine.py:1142` · PHP `Frond.php:2696` · Ruby `frond.rb:2174` ·
Node `packages/frond/src/engine.ts:1251` (+ helper `:1134`).

### Scope
- [ ] Python (master): `number_format(decimals=0, decimalPoint='.', thousandsSep=',')` - thread both args.
- [ ] PHP / Ruby / Node: mirror the same signature + defaults (back-compat: 1-arg unchanged).

### Tests (real render, pos + neg, all 4)
- [ ] positive: `{{ 1234.5 | number_format(2, ',', '.') }}` -> `1.234,50`
- [ ] negative/back-compat: `{{ 1234.5 | number_format(2) }}` -> `1,234.50` (unchanged)

### Parity
| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| fix | master | mirror | mirror | mirror |

---

## C. Frond #171 - `|` must bind tighter than `~` (ALL 4, two fix shapes)

`{{ amount|number_format(2) ~ ' EUR' }}` must be `(amount|number_format(2)) ~ ' EUR'`
(Twig: `|` tighter than `~`). All four render the raw value instead. NOT a clean
single-master mirror - the fix shape differs by architecture:

- **PHP** `Frond.php:1356-1362`: one-line reorder - move concat (step 8) ABOVE filter-pipe
  (step 7) in `evaluateExpression`. Its recursive evaluator already gets the parenthesized
  case right, so this is the structural exemplar for "filters resolve at any depth".
- **Python / Ruby / Node**: filters live ONLY at the output layer; `eval_expr`/`evalExpr` has
  no pipe handling. Structural fix: fold filter-pipe handling into `eval_expr` so precedence
  is correct at any nesting. This ALSO closes a second latent defect these three share -
  pipes inside parens / sub-expressions silently return empty.
  - Python: `engine.py` `_eval_var:1804` / `_eval_var_inner:1893` / `_split_on_pipe:887`; concat `:685`.
  - Ruby: `frond.rb` `eval_var:651` / `eval_var_inner:725` / `split_on_pipe:971`; concat `:1186`.
  - Node: `engine.ts` `evalVar:1951` / `evalVarInner:2036` / `parseFilterChain:932`; concat `:579`.

Expected outputs anchored to Python (the behaviour contract), even though the code change
differs per framework.

### Scope
- [ ] PHP: reorder concat above filter-pipe in `evaluateExpression`.
- [ ] Python / Ruby / Node: restructure so filter-pipe is handled inside the expression
      evaluator (fixes precedence AND pipes-in-sub-expressions).

### Tests (real render, pos + neg, all 4)
- [ ] `{{ amount|number_format(2) ~ ' EUR' }}` -> `1,234.50 EUR`
- [ ] ternary: `{{ charged ? amount|number_format(2) ~ ' EUR' : 'free' }}` -> `1,234.50 EUR`
- [ ] Python/Ruby/Node only: pipe inside parens `{{ (amount|number_format(2)) ~ ' EUR' }}` -> correct (was empty)
- [ ] negative: filter-only and concat-only expressions still correct (no regression)

### Parity
| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| fix shape | restructure | reorder | restructure | restructure |

---

## D. python #57 - silent write on bool->INTEGER (CODE ALREADY FIXED; test + comment)

Root cause = pre-3.13.38 `Database.execute()` swallowed the psycopg2 exception and returned
`False` (the reporter did not test the return, called `commit()`, got an empty table).
Verified on real PG: pre-fix (3.13.37) returns False + 0 rows (reproduces #57 exactly);
HEAD (3.13.71) re-raises `DatatypeMismatch`. Fixed in 3.13.38 (`65ca336`). All four
frameworks fail-loud at HEAD - no code change needed.

Bool is NOT coerced (psycopg2 adapts `True` -> SQL `true`; PG has no bool->int assignment cast,
so it genuinely raises). The pooling/commit-on-a-different-connection footgun is real but
SEPARATE - it only bites in strict mode (`TINA4_AUTOCOMMIT=false`) + pool>0, and did not
cause #57. Owner design call (see open question).

### Scope
- [ ] No core code change (already fixed + verified loud in all 4).
- [ ] Add the missing lock-in test: bind a `bool` to an INTEGER column on REAL PostgreSQL,
      assert `execute()` raises + table stays empty. Tie to #57. (SQLite cannot catch this -
      dynamically typed - so it must run on real PG.) Add in all 4 for parity.
- [ ] Comment on tina4-python#57: fixed in 3.13.38, upgrade to 3.13.71; explain the swallow
      and the fail-loud contract. Comment only - reporter closes (per feedback_github_issues).

### Parity
| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| fail-loud at HEAD | done | done | done | done |
| #57 lock-in test | add | add | add | add |

---

## Open question for the owner

**Strict-mode pooling footgun (mechanism c).** Under `TINA4_AUTOCOMMIT=false` + pool>0, a
standalone `execute()` and a later unpinned `commit()` can land on different pooled
connections, so the write is never committed (verified: 0 rows, lost even after `close()`).
Current documented contract: use `start_transaction()` in strict mode (which pins the
adapter). Options: (i) leave as-is (documented), (ii) warn when a standalone write is
followed by an unpinned commit in strict mode, (iii) briefly pin the adapter until the next
commit/rollback. Present all 4 identically. NOT in scope unless you want it - flagging for a
decision.

## E. Frond sandbox filter-gate bypass (self-introduced by #171 + a latent master bug) — ALL 4

Fixing #171 (fold the filter pipe into the expression evaluator so `x|f ~ y` binds
correctly) routed a filter pipe through a code path that did NOT consult the
`{% sandbox %}` filter allow-list. Empirically (real render, no mock) a non-allow-listed
filter's code RAN in sandbox mode via two vectors:

- **concat-pipe** `{{ x|f ~ ' y' }}` — the #171 path (Ruby `eval_filter_pipe`->`eval_var_raw`,
  Node `applyFilters`). Self-introduced regression: pre-#171 this went through the gated
  output loop.
- **ternary condition** `{{ x|f ? 'a' : 'b' }}` — pre-existing ungated path
  (Python `_eval_var_raw`, Ruby `eval_var_raw`, Node `evalVarRaw`). The lock-in test
  caught this in **Python (master)** too — the summary's "Python safe" was wrong on this
  vector. Fixed Python first (master), then confirmed the mirror.

### Fix (one-line allow-list gate in each ungated filter loop, matching the existing
`_apply_filters`/`evalVarInner` gate — semantic: silently skip the blocked filter)
- [x] Python master: gate `_eval_var_raw` (engine.py) — FOUND + FIXED a real master bug.
- [x] Ruby: gate `eval_var_raw` (frond.rb).
- [x] Node: gate `applyFilters` AND `evalVarRaw` (engine.ts).
- [x] PHP: already safe (recursive evaluator funnels every filter through the single gate
      at Frond.php:2359) — parity lock-in test only.

### Tests (real render, pos + neg, all 4) — a real `spy` filter records each invocation;
assertion is the security property (did the blocked filter's code run?), valid across all
four regardless of the blocked-filter output convention (see open question below).
- [x] negative: blocked filter in `x|spy ~ ' end'` — `spy` never runs (fails pre-fix on Ruby/Node/Python-ternary).
- [x] negative: blocked filter in `x|spy ? 'a' : 'b'` — `spy` never runs.
- [x] positive: allowed filter in concat-pipe -> `HI! end` (identical all 4) + spy ran once.
- [x] positive: allowed filter in ternary condition -> ran.

### Open question for the owner (blocked-filter OUTPUT convention drift — pre-existing)
PHP returns `''` (fail-closed) for a blocked filter; Python/Ruby/Node let the value pass
through unfiltered (skip). Both are secure (the blocked filter's code never runs) and both
are locked into existing per-framework tests. NOT unified in this batch (would change
established, test-locked behavior in PHP or the other three). Flagging for a parity decision:
converge on skip-passthrough (Python master) or fail-closed-empty (PHP)?

## Cross-cutting / release mechanics (WAVE at the end)
- [ ] Version bump 3.13.72 (Python pyproject, Ruby version.rb, Node 6x package.json, PHP CLAUDE.md) + CLAUDE docs.
- [ ] Release notes: docs/<lang>/36-releases.md x4 + book x4 (content-writer, ASCII).
- [ ] Independent verification: re-run full suites myself at HEAD (no mocks); re-read diffs.
- [ ] Merge local to v3 x4, tag 3.13.72, publish, verify registries live, push docs + book.
- [ ] Comment on #33 / #170 / #171 / #57 (reporters close). install-skills NOT bumped (no skill change).

## Status: SHIPPED 3.13.72 (2026-07-12)

Tagged + published live on all 4 registries: PyPI tina4-python 3.13.72, npm
tina4-nodejs 3.13.72, RubyGems tina4 3.13.72, Packagist tina4stack/tina4php 3.13.72.
Final no-mock verification at HEAD: Python 3552/0, PHP 2878/0, Ruby 3877/0, Node 5384
pass + 9 infra-only (Valkey/PG absent). Commented (not closed) on nodejs#33, php#170,
php#171, python#57 - reporters close. Throwaway PG container torn down. Item E (sandbox
bypass) found + fixed a real PYTHON MASTER bug; PHP converged on the master (Breaking,
owner-directed). Docs + book release notes delegated to a build-gated tina4-dev worker
(pnpm docs:build + audit-truth --strict must be green before push). install-skills NOT
bumped (no skill change).
