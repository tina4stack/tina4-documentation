# Implementation pass - 3.13.99 (first pass, re-numbered from 3.13.98 - the skills release took the .98 slot)

Every ratified fix, implemented in all four frameworks, one feature fully finished before the next.
Decisions: `OWNER-DECISIONS.md` (Batches 1-5 + standing compiler). Spec per feature = its doc's porting
capsule + proposed fixture.

## Execution model (owner, 2026-08-11) - read before any code

- **NO BASELINE RUN.** Owner: "No baseline run" / "everytime we do this we lose parity." No up-front
  full-suite run. Each feature is proven by ITS OWN real tests + the shared fixture, green in all four.
- **ONE FEATURE FULLY COMPLETED BEFORE THE NEXT.** Implement in ALL FOUR, write real (no-mock) tests +
  the shared conformance fixture, lab-validate GREEN in all four, commit, THEN the next feature. No
  batching, no parallel features. This is what holds parity.
- **GREEN FOR DEV, 1-133.** The dev gate is every feature 1-133 green. The ~53 below get fixed; the rest
  stay green and must not regress.
- **MAINTAINABILITY LENS.** Maintainability = less code. Each feature also deletes the dead/duplicated
  code its finding names, prefers deleting to adding, adds ZERO new runtime deps (reuse ladder). Bigger
  simplifications become their own checkbox here, never a silent detour.

**Per-feature definition of done:** logic in all four -> real tests + shared fixture (positive AND
negative, no mocks) -> dead/dup code removed -> run the fixture + the feature's tests ON THE .99 LAB BOX
-> real GREEN in all four -> commit. Never self-report, never advance on red. Markers: `[ ]` todo /
`[~]` in progress / `[L]` lab-green all four / `[x]` committed.

## Phase 0 - setup (branch only, NO baseline)

- [x] Cut `feature/release3.13.99` off v3 in each repo (renamed from feature/release3.13.98 when the skills release claimed .98); version bumped to 3.13.99 (manifest + lock)
- [ ] Carry the two audit HEADs into v3 as part of feature 37/127: feature/csrf-fail-closed (py) +
      feature/mcp-call-gate (php/ruby/node). No standalone baseline - they land with their features.

## Phase 1 - security cluster (highest value first)

- [x] 37 CSRF - DONE 2026-08-11, lab-green all four (py 59 / php 56 / ruby 44 / node 46; consolidated rc=0, independently re-verified). Pushed py 3249495, php 001f966a, ruby dbcd6a2, node cc6642a, fixture doc 3dd9608. Removed PHP default-secret + `$_ENV` mutation; aligned Node gen/validator; `TINA4_CSRF` attaches; session-bind + type=form; SEC-01 ported all four; 403 body unified to `{error,code,message,status}`.
- [x] 127 dev-admin - DONE 2026-08-11, lab-green all four (9/9/9/9; consolidated rc=0, independently re-verified). Pushed py 41b3aeb, php 698e6a6, ruby ab06e5c, node 97d4f22, fixture fc42718. Same-origin gate + `.env` denylist + localhost-default bind + mcp/call gate (ADDED to Python) + toolbar escape. Fixed in passing: PHP DEC-02 landed in a dead App::run path (real fix in `bin/tina4php resolveHostPort`); Ruby 404 error-page reflected the raw path (XSS) - audit had marked Ruby n/a for DEC-04, it was NOT (correct the 127 doc).
- [ ] 41 static assets - realpath+sep confinement to py/ruby/node; block dotfiles; honour `TINA4_PUBLIC_DIR` ruby+node
- [ ] 43 request-id - build in all 4 (honour inbound + response header + log correlation); sanitize inbound; Python -> contextvars
- [ ] 53 Frond tags - confine include/extends under templates dir (realpath + reject `..`/absolute)
- [ ] 14 Mongo SQL provider - fail-closed on unparseable WHERE; reject empty-filter delete/update; real-Mongo fixture
- [ ] 36 security headers - REGISTER by default; HTTPS-guard HSTS; rename PHP class; wire tests; CSP migration note
- [ ] 129 port-takeover - Tina4-identity check before kill; guard the runtime path; `TINA4_NO_TAKEOVER`/`--no-kill` opt-out; dev-gate
- [ ] 126 debug overlay - DELETE dead `render_production_error` + wired-path no-leak test; redact Authorization/Cookie/Set-Cookie; guard render + frame cap
- [ ] 132 inline testing - wire ONE surface (`tina4 test` real exit code + discovery); REMOVE PHP `eval`/blanket require; fix collision; de-couple registry

## Phase 2 - data-loss / silent no-op

- [ ] 44 file upload - repeated field -> LIST all 4 (no silent drop); running per-chunk size counter php/ruby; safe-save helper
- [ ] 47 background tasks - run under production ASGI (py) + guard FPM/Swoole (php); one surface (handle+count) all 4
- [ ] 25 ORM cache - fix `cached()` invalidation (bust on all writes, tag by table, ttl=0=no-cache); add `cached()` to Node
- [ ] 16 next-id - fix generic TOCTOU (lock/atomic); fix Mongo no-increment
- [ ] 7 SQL translator - literal-safe concat + bool/ilike; resolve Ruby unwiring + remove dead/dup code; BIGINT autoincrement

## Phase 3 - DB providers / write-path correctness

- [ ] 9 PostgreSQL - adapter-contract test asserts BEHAVIOUR (PG as oracle), all 4
- [ ] 10 MySQL - real-PK RETURNING emulation (non-`id` regression); parameterize DESCRIBE; de-dup batch-id
- [ ] 11 MSSQL - safe param handling (Ruby unknown-type, Node Buffer->VarBinary); real-PK RETURNING; one pagination
- [ ] 12 Firebird - replace Ruby no-mock VIOLATION with a real reconnect test; generator last-id + real affected-count ruby/node; blob + SRP; fix CI-gate claim
- [ ] 13 ODBC - provision a real ODBC source in CI + run the shared fixture; PK catalog query; remove Python `@@IDENTITY`/creds bug; add Node string-WHERE + owns-guard; fail-loud fetch

## Phase 4 - ORM / validation / correctness (feature order)

- [ ] 17 ORM base - remove vestigial state (Node `_exists`, PHP `tableFilter`, dead locals)
- [ ] 18 ORM fields - reconcile the field model behaviour-by-behaviour (ADR-0004); real-engine DDL tests; PHP callable defaults
- [ ] 19 input validation - real tests for the untested validators; Ruby richer ORM validation; Node AutoCrud PUT validation; unify messages
- [ ] 20 soft delete - PHP restore/with_trashed tests; correct the force-delete record; `create_table` injects `is_deleted`
- [ ] 21 relationships - read-side-only; drop Python's no-op `on_delete`
- [ ] 22 imperative rels - Node serialize-orphan; DE-DUP PHP parallel impl; unify Python cap; Ruby stays declarative-at-runtime
- [ ] 23 scopes - fix PHP global-registry collision
- [ ] 24 pagination - clamp page>=1 (py/ruby/node); cap max per-page
- [ ] 26 loading - stop Python re-enforcing write constraints on read; unify Ruby's two read paths; pin scalar read-coercion
- [ ] 27 AutoCrud - invalid create -> 422 with field errors, all 4
- [ ] 28 seeder - fix PHP `seed_table` backtick quoting; REMOVE the inert `seed_table(seed=)` param
- [ ] 29 request model - route params SEPARATE from query (breaking py/ruby); add Python `request.user`
- [ ] 15 migrations - fix `migrate:status` (py+php); Node CLI uses the real migrator; auto-migrate default-ON + `TINA4_AUTO_MIGRATE=false` opt-out

## Phase 5 - HTTP / dev-tooling parity

- [ ] 40 compression/ETag - build gzip + dynamic ETag php/ruby/node; 304 preserves validators; one static ETag `W/"<size>-<mtime>"`
- [ ] 42 error pages - content-negotiate JSON vs HTML (resolves the 403 split); Ruby JSON error path; 404 request_id
- [ ] 45 swagger - Node live-routes snapshot (not boot); add `/__feedback` to exclusion; Python documents 401 on secured ops
- [ ] 32 route groups - converge slash-normalization on PHP's grammar
- [ ] 46 landing page - RATIFY dev-only; unify suppression conditions (remove Ruby dead branch)
- [ ] 128 dual test port - port Node's real dual-port test to py/php/ruby; single-source Ruby base port; align PHP default
- [ ] 130 version - single-resolver convergence php+node; cross-source drift test; ADD `Tina4/<version>` User-Agent all 4
- [ ] 131 test client - route Node's TestClient through the real dispatch; preserve duplicate headers all 4
- [ ] 133 carbonah - `CARBONAH.md` GENERATED (JSON + suite counts + SCI); align the 4 harnesses' workload set + parity check

## Phase 6 - Frond

- [ ] 48/49 lexer/parser - add source positions + EOF; parser/AST stage for ruby+node
- [ ] 50 Frond compiler - BUILD the AOT compiler for Ruby + Node (BIG; depends on 48/49; byte-identical to interpreter; sandbox-disabled). CONFIRM in-scope for .98 vs fast-follow before starting - it is the single largest item in the pass.
- [ ] 52 Frond filters - `|date` strftime everywhere; `|join` default ", "; `|default` keeps false
- [ ] 54 Frond tests - even/odd require a real integer (no PHP int-cast)
- [ ] 55 Frond functions - add `range()` py/ruby/node; camelCase `formToken` alias; Ruby dotted-call resolution
- [ ] 56 Frond extensibility - instance-local registration (no class-registry leak)
- [ ] 57 auto-escaping - `|tojson` \u-escape model everywhere; escaped charset `& < > " '` identical
- [ ] 58 sandboxing - denied filter RAISES (not pass-through); disable the new compilers under sandbox
- [ ] 59 template caching - bound Python's caches (256); compare mtime in prod
- [ ] 60 fragment caching - bound the store; namespace keys (no cross-block collision)

## Maintainability lens (less-code items, done WITH their feature)

These are the dead/duplicated-code removals the audit already found. They are not a separate phase -
each is deleted as part of its feature so the diff nets DOWN, not up:

- 7 remove the dead/duplicated SQL-translator code + resolve the Ruby unwiring
- 17 remove Node `_exists`, PHP `tableFilter`, dead locals
- 21 drop Python's no-op `on_delete` param (phantom API)
- 22 de-duplicate PHP's parallel imperative-relationship impl
- 28 remove the inert `seed_table(seed=)` param
- 46 remove Ruby's dead landing-suppression branch
- 126 delete the dead `render_production_error` in all four + its misleading docstring
- 130 collapse PHP's three version sources + Node's four package.json readers to one resolver each
- 133 replace the hand-maintained `CARBONAH.md` with a generator

## Follow-ups surfaced during the pass

Small, orthogonal items found while implementing a feature - fold into the named later feature; do NOT expand the current feature to chase them:
- 37 (CSRF): form-token TTL env var name diverges - Python reads `TINA4_TOKEN_EXPIRES_IN`, PHP/Ruby/Node read `TINA4_TOKEN_LIMIT`. Unify in a later env-uniformity pass (or with feature 64 JWT).
- 37 (CSRF): Ruby's blank-secret hard-fail also rejects writes in RS256 mode (blank `TINA4_SECRET` + `.keys/` present + `TINA4_CSRF=true`) - kept fail-closed-uniform for parity (auto-attach is new, no existing app regresses); revisit if RS256-defer is wanted.
- 57/42 (SECURITY - Frond auto-escape parity): Ruby's Frond/TwigEngine does NOT auto-escape `{{ }}` by default, while Python and PHP Frond DO (you opt out via `{% autoescape false %}`). This surfaced a reflected XSS in Ruby's 404 error page (raw path reflected) - patched acutely in 127 (`ab06e5c`, escape at `handle_404`). ROOT fix is feature 57 (auto-escaping): make Ruby auto-escape by default at parity + confirm Node's default. Feature 42 (error pages) must also verify no 404/403/500 template reflects raw request data unescaped in any framework. Assessed 2026-08-11: Python/PHP/Node error templates show NO raw-path reflection, so this is a Ruby-centric parity gap, NOT a live 4-way vuln.

## Close

- [ ] All ~53 features lab-green in all four; 1-133 green for dev
- [ ] Merge feature/release3.13.99 -> v3; tag 3.13.99; update release notes + the book
