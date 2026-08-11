# Implementation pass - 3.13.98 (first pass)

Single pass, feature 1 -> end, every decided fix in all four frameworks. Order below is roughly feature-number
("beginning to end") with the SECURITY items pulled to the front (highest value first, owner's call).

**Per-feature gate:** implement in all four -> run the shared fixture + the feature's tests ON THE .99 LAB BOX
(real services, no mocks) -> GREEN is the gate to commit + advance. Never self-report, never advance on red.
Branch `feature/release3.13.98` off v3 (after merging feature/csrf-fail-closed + feature/mcp-call-gate to v3);
`feature/release3.13.98` -> v3 -> tag at the end. Decisions: `OWNER-DECISIONS.md`; spec per feature = its doc's
porting capsule + proposed fixture. `[ ]` todo / `[~]` in-progress / `[L]` lab-green / `[x]` committed.

## Phase 0 - setup
- [ ] Merge feature/csrf-fail-closed (py) + feature/mcp-call-gate (php/ruby/node) to v3, lab-verify green
- [ ] Cut `feature/release3.13.98` off v3 in each repo; bump version to 3.13.98

## Phase 1 - security cluster (first)
- [ ] 37 CSRF - remove PHP public default-secret + $_ENV mutation; fix Node gen/validator split; TINA4_CSRF attaches; port SEC-01 test to php/ruby/node
- [ ] 41 static assets - PHP realpath+sep confinement ported to py/ruby/node; block dotfiles; honour TINA4_PUBLIC_DIR ruby+node
- [ ] 43 request-id - build in all 4 (honour inbound + emit response header + log correlation); sanitize inbound; Python -> contextvars
- [ ] 53 Frond tags - confine include/extends paths under templates dir (realpath + reject ../absolute)
- [ ] 14 Mongo SQL provider - fail-closed on unparseable WHERE; reject empty-filter delete/update; real-Mongo fixture
- [ ] 36 security headers - REGISTER by default (secure-by-default); HTTPS-guard HSTS; rename PHP class; wire tests; CSP migration note

## Phase 2 - data-loss / silent no-op
- [ ] 44 file upload - repeated field -> LIST all 4 (no silent drop); running per-chunk size counter php/ruby; safe-save helper
- [ ] 47 background tasks - run under production ASGI (py) + guard FPM/Swoole (php); one surface (handle+count) all 4
- [ ] 25 ORM cache - fix cached() invalidation (bust on all writes, tag by table, ttl=0=no-cache); add cached() to Node
- [ ] 16 next-id - fix generic TOCTOU (lock/atomic); fix Mongo no-increment

## Phase 3 - parity / correctness (feature order)
- [ ] 15 migrations - fix migrate:status (py+php); Node CLI uses the real migrator
- [ ] 18 ORM fields - reconcile the field model behaviour-by-behaviour (ADR-0004)
- [ ] 21 relationships - read-side-only; drop Python's no-op on_delete
- [ ] 22 imperative rels - Node serialize-orphan; de-dup PHP; unify Python cap; Ruby stays declarative-at-runtime
- [ ] 23 scopes - fix PHP global-registry collision
- [ ] 24 pagination - clamp page>=1 (py/ruby/node); cap max per-page
- [ ] 26 loading - stop Python re-enforcing write constraints on read; unify Ruby's two read paths
- [ ] 27 AutoCrud - invalid create -> 422 with field errors, all 4
- [ ] 28 seeder - fix PHP seed_table backtick quoting; remove the inert seed_table(seed=) param
- [ ] 29 request model - route params SEPARATE from query (breaking py/ruby); add Python request.user
- [ ] 32 route groups - converge slash-normalization on PHP's grammar
- [ ] 40 compression/ETag - build gzip + dynamic ETag in php/ruby/node; 304 preserves validators; one static ETag format
- [ ] 42 error pages - content-negotiate JSON vs HTML (resolves the 403 split); Ruby gains a JSON error path; 404 request_id
- [ ] 45 swagger - fix Node boot-snapshot (live routes); add /__feedback to exclusion; Python documents 401 on secured ops
- [ ] 48/49 Frond lexer/parser - add source positions + EOF; parser/AST stage for ruby+node
- [ ] 50 Frond compiler - build the AOT compiler for Ruby + Node (BIG; depends on 48/49); byte-identical to interpreter; sandbox-disabled
- [ ] 52 Frond filters - |date strftime everywhere; |join default ", "; |default keeps false
- [ ] 54 Frond tests - even/odd require a real integer (no PHP int-cast)
- [ ] 55 Frond functions - add range() global py/ruby/node; camelCase formToken alias; Ruby dotted-call resolution
- [ ] 56 Frond extensibility - instance-local registration (no class-registry leak)
- [ ] 57 auto-escaping - |tojson \u-escape model everywhere; escaped charset & < > " ' identical
- [ ] 58 sandboxing - denied filter RAISES (not pass-through); disable the new compilers under sandbox
- [ ] 59 template caching - bound Python's caches (256); compare mtime in prod
- [ ] 60 fragment caching - bound the store; namespace keys (no cross-block collision)

## Close
- [ ] All features lab-green; run the full suites on .99 (all 4) one final time
- [ ] Merge feature/release3.13.98 -> v3; tag 3.13.98; update release notes + the book
