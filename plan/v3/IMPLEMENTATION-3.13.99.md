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
- [x] 41 static assets - DONE 2026-08-11, lab-green all four (40/43/30/52; consolidated rc=0, independently re-verified). Pushed py c51c686, php c422f4b, ruby e24a3fa, node 77592ad, fixture 1978abc. realpath+separator confinement (ADR-0050) ported to py/ruby/node; symlink-escape + dotfile blocked; `TINA4_PUBLIC_DIR` honoured ruby+node; one search-dir order.
- [x] 43 request-id - DONE 2026-08-11, lab-green all four (9/9/9/11; consolidated rc=0, independently re-verified). Pushed py 1d324d5, php 1d9d607, ruby 1bfc060, node 0828904, fixture 234ec05. Honour+emit X-Request-ID; sanitize inbound (CRLF/charset/length); request-scoped storage all four (py contextvars, ruby thread-local, node AsyncLocalStorage, php per-request) - mutation-proved isolation.
- [x] 53 Frond tags - DONE 2026-08-11, lab-green all four (5/5/5/5; consolidated rc=0, independently re-verified). Pushed py f858c11, php 42a0723, ruby a1ff8af, node 22e6057, fixture bc0b9ff. One shared containment helper per language (PHP extracted `resolveTemplatePath` from 4 duplicated joins - less code); include/extends/import confined under the templates dir (lexical `..`/absolute reject + realpath containment; symlink-escape refused).
- [x] 14 Mongo SQL provider - DONE 2026-08-11, lab-green all four (7/7/7/7; consolidated rc=0, independently re-verified on real Mongo). Pushed py 3315d1c, php baf1af5, ruby d45c119, node ad62c2d, fixture 837b936. Fail-closed: unparseable/partial WHERE raises (never match-all); empty-filter delete/update rejected; one shared guard per language; `truncate()` (explicit `1=1`) unaffected. Removed dead `?:[]`/`|| {}` fallbacks (less code).
- [x] 36 security headers - DONE 2026-08-11, lab-green all four (4/4/4/5; consolidated rc=0, independently re-verified). Pushed py bfc1597, php 853c47c, ruby 6e44205, node aa73dbf, fixture 1d0bcbe. Registered secure-by-default (all four); HSTS HTTPS-guarded (`TINA4_HSTS` + secure scheme); CSP `default-src 'self'` (`TINA4_CSP` to relax); PHP class renamed `SecurityHeaders`->`SecurityHeadersMiddleware` (no alias); identical header set/values; `nginx.conf.example` de-drifted.
- [x] 129 port-takeover - DONE 2026-08-12, lab-green all four ON LINUX (5/16/5/5; consolidated rc=0, re-run by the main loop on the .99 lab after the worker's macOS-only run). Pushed py fdd7d86, php 40cd4c0, ruby 75f78ae, node ae7332d, fixture 6845b2c. Identity-check (per-port PID file) before kill - a foreign process is NEVER killed; runtime path shares the CLI guard; `TINA4_NO_TAKEOVER`/`--no-kill` opt-out; dev-gated. Duplicated takeover logic collapsed to one shared helper per language (~-100 lines each).
- [x] 126 debug overlay - DONE 2026-08-12, lab-green all four ON LINUX (22/22/22/48; consolidated rc=0, independently re-verified). Pushed py 7b460ea, php df860de, ruby 93c1e06, node f9afed3, fixture a8f93c1. DELETED dead `render_production_error` (all four) + real wired prod-no-leak test; dev overlay redacts Authorization/Cookie/Set-Cookie + secret body fields (one redact helper); frame cap (MAX_FRAMES=50); self-throw guard (overlay fail -> safe 500); gate unified on `is_debug_mode()`.
- [x] 132 inline testing - DONE 2026-08-12, lab-green all four ON LINUX (py 61 / php 8 tests-37 assertions / ruby 48 / node typecheck+49+4+6; consolidated rc=0, independently re-run on the .99 lab). Pushed py d854b9d, php e797e9b, ruby e477caf, node e4202b5, fixture ec863cf. Wired ONE surface (the `@tests`/`expect_*` descriptor model) into `tina4 test` with a real exit code + discovery all four (Ruby already ran `run_all`; Python/PHP/Node newly wired); REMOVED PHP's `eval()` RCE (literal-only arg parser) + the blanket `require_once` (discovery confined to an explicit tests dir, realpath); renamed the descriptor builders `assert_*`->`expect_*` so they no longer collide with the xUnit immediate `assert_*`; Python meta-test snapshots/restores the global registry. Shared fixture `inlinetesting_contract.json` (3 invariants / 4 cases) proven by a real-CLI no-mock suite in all four; mutation-proved (exit-fold, tests-dir confinement/eval removal/marker-only discovery, collision).

## Phase 2 - data-loss / silent no-op

- [x] 44 file upload - DONE 2026-08-12, lab-green all four ON LINUX (6/6/6/8; consolidated rc=0, independently re-verified - initial red was a `$HOME`-under-sudo harness bug in the gate script, NOT the code). Pushed py 9fd483c, php a6bb4b3, ruby dab136f, node 5a9bdbe, fixture 68b5e12. Repeated FILE field -> a list (no silent drop; files-scoped, matching Node + UP-MULTIFILE-LOSS); safe-save helper (sanitize filename + realpath-confine) all four; per-chunk running size guard brought to PHP/Ruby (413 mid-stream, not after buffering).
- [x] 47 background tasks - DONE 2026-08-12, lab-green all four ON LINUX (6/6/6/7; consolidated rc=0, independently re-verified). Pushed py 1d4fb4d, php 9f62bde, ruby 32f9539, node fe6e069, fixture 506afeb. Python starts tasks from the ASGI lifespan (was a silent no-op under uvicorn/hypercorn); PHP loud FPM/Swoole SAPI guard (never a silent drop); one handle+count surface all four (`background()` -> stop-handle + `count()`); mutation-proved.
- [x] 25 ORM cache - DONE 2026-08-12, lab-green all four ON LINUX (8/8/8/8; consolidated rc=0, independently re-verified on real SQLite). Pushed py 9329fbc, php d6fca93, ruby cdbeee3, node c472089, fixture b5040f4. `cached()` now busts on ALL writes (save/delete/force_delete/restore), tagged by every FROM/JOIN table (an unrelated-table write leaves it intact), `ttl=0`=no-cache; Node's drifted-in untagged cached() rebuilt onto the shared tag-aware QueryCache (KEPT in py/php/ruby, not dropped); removed Node dead `_queryCache` + PHP wholesale cacheClear (less code).
- [x] 16 next-id - DONE 2026-08-12, lab-green all four ON LINUX (5/5/5/5; consolidated rc=0, independently re-verified on real PG/MySQL/Mongo). Pushed py f735e6b, php 833cceb, ruby d22c507, node 3fbf63b, fixture 6a6ec65. Generic next-id is now atomic (`UPDATE ... RETURNING`, was UPDATE-then-separate-SELECT TOCTOU); Postgres draws from a real SEQUENCE; Mongo uses an atomic `findOneAndUpdate $inc` counter (Ruby/Node gained the Mongo path); mutation-proved with real duplicates under 24-48 concurrent callers.
- [ ] 7 SQL translator - literal-safe concat + bool/ilike; resolve Ruby unwiring + remove dead/dup code; BIGINT autoincrement
- [ ] 14b Mongo truncate() parity (found during 14, fix-on-discovery) - `truncate()` empties in PHP (`1=1` -> `[]` match-all) but SILENTLY NO-OPS in py/ruby/node (`1=1` -> `{"1":1}` matches nothing). Make the explicit `1=1` tautology translate to match-all so `truncate()` actually empties, all four, with a real-Mongo regression (seed N -> truncate -> count 0). Does NOT weaken 14 (`1=1` is explicit, not unparseable).

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
- 25 (ORM cache) LATENT: the underlying cache `ttl<=0` semantics DIVERGE - Python core `Cache` treats `ttl<=0` as never-expire; PHP/Ruby/Node `QueryCache` treat `ttl=0` as immediate-expiry. Feature 25's explicit `ttl<=0` gate in `cached()` neutralises it there (never reaches `set()` with ttl<=0), but the backend divergence could bite other cache callers. Low-pri: unify with the caching features (59/72).
- 44 (file upload, UP-DEC-01 - pre-existing, NOT fixed): `tina4-php/Tina4/Request.php:296` docblock still says `content => string (base64)` but the code returns raw bytes - a false docblock governed by UP-DEC-01 (descriptor-key/base64 correction), out of feature-44 scope. Fold into UP-DEC-01.
- 44 scoping note: the repeated-field->list fix is FILES-only (repeated TEXT fields stay last-wins, matching Node + the UP-MULTIFILE-LOSS finding); repeated text-field semantics are governed separately by REQ-DEC-01 (feature 29).
- LAB GATE HARNESS: `lab-fileupload.sh` used `$HOME/rel-3.13.99`, which breaks under `sudo` (HOME=/root) - the main loop's re-run showed "MISSING clone" rc=1 until run with `sudo HOME=/home/andre`. Gate scripts MUST hardcode `BASE=/home/andre/rel-3.13.99`, never `$HOME` (the other gates already do).
- SKILL DRIFT - DONE 2026-08-12 (report-a-skill issue #49): removed the `render_production_error` "Production error" row from `references/subsystems.md` in all four repos' tina4-maintainer skill (the fn was deleted in feature 126). Applied right after 132 landed (had been the fix-on-discovery live-collision defer).
- 37 (CSRF): form-token TTL env var name diverges - Python reads `TINA4_TOKEN_EXPIRES_IN`, PHP/Ruby/Node read `TINA4_TOKEN_LIMIT`. Unify in a later env-uniformity pass (or with feature 64 JWT).
- 37 (CSRF): Ruby's blank-secret hard-fail also rejects writes in RS256 mode (blank `TINA4_SECRET` + `.keys/` present + `TINA4_CSRF=true`) - kept fail-closed-uniform for parity (auto-attach is new, no existing app regresses); revisit if RS256-defer is wanted.
- 57/42 (SECURITY - Frond auto-escape parity): Ruby's Frond/TwigEngine does NOT auto-escape `{{ }}` by default, while Python and PHP Frond DO (you opt out via `{% autoescape false %}`). This surfaced a reflected XSS in Ruby's 404 error page (raw path reflected) - patched acutely in 127 (`ab06e5c`, escape at `handle_404`). ROOT fix is feature 57 (auto-escaping): make Ruby auto-escape by default at parity + confirm Node's default. Feature 42 (error pages) must also verify no 404/403/500 template reflects raw request data unescaped in any framework. Assessed 2026-08-11: Python/PHP/Node error templates show NO raw-path reflection, so this is a Ruby-centric parity gap, NOT a live 4-way vuln.

## Breaking changes (for the 3.13.99 changelog)

Compiled as features land; each is a security/parity fix, not an accidental break. Migration detail in each feature doc.
- 37 (CSRF): 403 body unified to `{error, code, message, status}` (Ruby/Node changed from `{error: "CSRF_INVALID"}`); `TINA4_CSRF=true` now ATTACHES the middleware (was inert); a blank `TINA4_SECRET` now fails closed (no forgeable public-default token).
- 127 (dev-admin): dev server binds `127.0.0.1` by default (set `TINA4_HOST=0.0.0.0` to expose); cross-origin `/__dev` mutations refused; `.env` never served via the file endpoints.
- 41 (static): a symlink whose realpath escapes the public dir is refused; dotfiles (`.env`, `.git`) return 404; Ruby drops the `src/assets`/`assets` search dirs; PHP app-dir order is `public` before `src/public`; `TINA4_PUBLIC_DIR` now honoured in Ruby + Node.
- 43 (request-id): a hostile inbound `X-Request-ID` (CRLF / illegal charset / over-long) is now sanitized to a fresh id instead of echoed raw (response-header + log-injection fix); a well-formed id passes through unchanged. Storage moved to request-scoped (contextvars / thread-local / AsyncLocalStorage) - internal, no API change.
- 53 (Frond tags): `{% include %}`/`{% extends %}`/`{% import %}` are now confined to the templates dir - a template that referenced a path outside it (`..`, absolute, or a symlink escaping the dir) now raises instead of reading the file. Legit in-dir includes unaffected.
- 14 (Mongo SQL): an unparseable/unsupported WHERE now RAISES instead of silently matching all documents (was a mass-delete/update data-loss footgun); a DELETE/UPDATE with no WHERE is rejected. Code relying on the old silent match-all must add an explicit WHERE (or use `truncate()`).
- 36 (security headers): security headers now emit by DEFAULT (secure-by-default) in all four - notably `Content-Security-Policy: default-src 'self'`, which blocks inline scripts and third-party CDNs. Relax it with `TINA4_CSP`. HSTS emits only on HTTPS when `TINA4_HSTS` is set.
- 129 (port takeover): `tina4 serve` on a busy port no longer kills whatever holds it - it reclaims only a port held by an identifiable Tina4 dev server (per-port PID file), refuses on a foreign holder, is dev-gated, and honours `TINA4_NO_TAKEOVER`/`--no-kill`. Anyone relying on serve force-killing an arbitrary process must free the port themselves.
- 126 (debug overlay): the dead `render_production_error`/`renderProductionError` public function is removed in all four (nothing invoked it; the real prod 500 renders `500.twig`) - a stale caller must use the template path. The dev overlay now redacts `Authorization`/`Cookie`/`Set-Cookie` + secret body fields and caps the rendered stack at 50 frames.
- 44 (file upload): a repeated multipart FILE field name now yields a LIST (was last-wins silent drop) - code reading `request.files['x']` for a single upload should handle a list when multiple files are sent under one name. The new safe-save helper rejects `..`/absolute filenames. PHP/Ruby now 413 an over-limit upload mid-stream (per-chunk), not after buffering the whole body.
- 47 (background tasks): PHP `App::background()` now returns a `Tina4\BackgroundTask` handle instead of `$this` (was fluent) - split a chained `->background(a)->background(b)` into two calls. Node `handle.stop()` now returns a boolean (was void).
- 16 (next-id): PHP's MongoDB next-id now RAISES on error instead of silently returning `1` (which produced duplicate ids) - handle the exception where you call it. The generic next-id relies on an atomic `UPDATE ... RETURNING` on a sequence row (internal; concurrent callers no longer collide).
- 132 (inline testing): the inline `@tests` DESCRIPTOR builders are renamed `assert_*` -> `expect_*` (Python `expect_equal`/`expect_raises`/`expect_true`/`expect_false`, PHP `Testing::expectEqual`/..., Ruby `Tina4::Testing.expect_equal`/..., Node `expectEqual`/...). Code using the descriptor surface must rename its calls; the xUnit IMMEDIATE `assert_*` (`tina4_python.test` / `Tina4Test` / Ruby `TestContext`) is unchanged. `tina4 <lang> test` now DISCOVERS + RUNS the inline surface with a real exit code, so a previously-"green" run that executed zero of a developer's inline tests may now actually run (and possibly fail) them. PHP `Testing::discover()` now scans only an EXPLICIT tests directory and parses `@tests` args as literals (no `eval`): a `@tests` docblock in a source file OUTSIDE the tests dir, or one whose argument is not a literal, is no longer discovered/executed.

## Close

- [ ] All ~53 features lab-green in all four; 1-133 green for dev
- [ ] Merge feature/release3.13.99 -> v3; tag 3.13.99; update release notes + the book
