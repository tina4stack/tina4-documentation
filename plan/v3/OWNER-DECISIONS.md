# Owner decisions log (v3 audit)

The running record of DEC-* ratifications. Andre (owner) decides; each entry marks the feature doc's DEC-*
as OWNER-DECIDED. Status: FIX = a security/correctness fix (not a choice, ratified); DECIDED = a genuine
either/or the owner chose. Implementation follows in all four frameworks with real tests (no mocks); this log
is the authoritative "what was decided", the feature docs carry the detail.

## Standing (pre-run)

- Frond compiler (50, CP-DEC-01) - DECIDED 2026-08-11: ALL FOUR languages get a Frond compiler (Ruby + Node
  build one matching Python/PHP; requires a parser/AST stage first). Parity/architecture call.

## Batch 1 - 2026-08-11

### Ratified fixes (vulns/correctness - not choices)

- CSRF secret (37, CSRF-DEC-01) - FIX: remove PHP's public `'tina4-default-secret'` fallback + the `$_ENV`
  mutation; fix Node's generator/validator secret split; make Python/Ruby's fail-closed the reference; port
  the Python SEC-01 regression test to PHP/Node/Ruby. (Highest-priority security fix in the audit.)
- Static asset symlink escape (41, ST-DEC-01) - FIX: adopt PHP's `realpath`+separator confinement as the
  reference (ADR-0050) and port it to Python/Ruby/Node; block dotfiles.
- Request-id injection (43, RID-DEC-02) - FIX: sanitize the inbound `x-request-id` in Python (allow-list
  charset, cap length, strip CR/LF); move request-id storage from `threading.local` to `contextvars`.
- Frond include/extends traversal (53, TAG-DEC-01) - FIX: confine `{% include %}`/`{% extends %}` paths under
  the templates dir (realpath + containment; reject `..`/absolute), all four.
- MongoDB unparseable-WHERE mass-delete (14, MONGO-DEC-01) - FIX: fail-closed - an unparseable/unsupported
  WHERE raises; reject an empty-filter delete/update; add a real-Mongo fixture.

### Decided (genuine either/or)

- Security headers (36, SECHDR-DEC-01) - DECIDED: REGISTER the SecurityHeadersMiddleware in the default chain
  (secure-by-default). Ship a migration note for CSP `default-src 'self'` (breaks inline scripts/CDNs).
  HTTPS-guard HSTS. Rename PHP's class to `SecurityHeadersMiddleware`; add wire tests.
- CSRF wiring (37, CSRF-DEC-02) - DECIDED: `TINA4_CSRF=true` ATTACHES the middleware (env-controllable), so
  the flag is no longer inert. (The secret FIX above is independent and mandatory.)
- Request param model (29, REQ-DEC-01) - DECIDED: keep route params and query SEPARATE (the PHP/Node model) -
  `request.params` is route-only, `request.query` is client-only. Closes the param-pollution surface.
  BREAKING for Python/Ruby apps that read query values via `params` (and Ruby's body-into-params) - needs a
  `Breaking:` changelog entry + migration note. Also add Python's missing `request.user` field.
- Python-only features (40 CE-DEC-01, 43 RID-DEC-01) - DECIDED: BUILD IN ALL FOUR. Port gzip compression + the
  dynamic content-hash ETag (40) and the real request-id (honour inbound, emit response header, log
  correlation) (43) to PHP/Ruby/Node. Parity is the v3 goal.

## Batch 2 - 2026-08-11 (all DECIDED)

- Frond |date convention (52, FILT-DEC-01) - DECIDED: `|date` uses strftime `%`-codes (the cross-language
  standard, Python/Ruby/Node already). PHP switches its `|date` from native `date()` codes to strftime, so a
  `{{ d|date(fmt) }}` arg is portable.
- ORM relationships cascade (21, REL-DEC-01) - DECIDED: relationships are READ-SIDE-ONLY. Referential
  integrity is the migrations/DB's job (consistent with the no-FK Firebird rule). DROP Python's `on_delete=`
  param that silently no-ops (a phantom API - do not ship a param that does nothing).
- AutoCrud invalid-create status (27, CRUD-DEC-01) - DECIDED: return 422 Unprocessable Entity with the FIELD
  errors, consistent across all four (fixes PHP/Ruby's buggy 500 and Python's 400).
- ORM result caching (25, CACHE-DEC-01) - DECIDED (owner overrode the drop-it recommendation): KEEP the
  explicit `Model.cached()` but FIX its invalidation - bust on ALL writes (save AND delete/force_delete/
  restore), tag a cached query by every table it touches, treat `ttl=0` as no-cache (not infinite) - and ADD
  `cached()` to Node for parity (Node has only the adapter auto-cache today).

## Batch 3 - 2026-08-11 (all DECIDED)

- ORM field model (18, FIELD-DEC-01) - DECIDED (owner overrode the Python-master default): reconcile the
  field model BEHAVIOUR-BY-BEHAVIOUR (ADR-0004 best-implementation-prevails), not a single language as master.
  Pick the best per behaviour; do not inherit any one language's quirk wholesale.
- Frond lexer/parser positions (48/49, LEX-DEC-01 + PARSE-DEC-02) - DECIDED: ADD source positions (line/col)
  + an EOF token to Frond tokens in all four, so lexical/parse/runtime errors are POSITIONED. Foundation for
  the owner-decided compiler (50) and real template diagnostics. Ruby+Node also gain a parser/AST stage.
- Error-page rendering (42, ERR-DEC-01 + ERR-DEC-02) - DECIDED: content-NEGOTIATE - a JSON error body for a
  JSON/API request, the HTML `errors/{code}.twig` page for a browser - uniformly across the four (this also
  resolves the 4-way 403 split; Ruby gains a JSON error path).
- Frond extensibility scope (56, EX-DEC-01) - DECIDED: an INSTANCE registration is instance-LOCAL (does not
  write the class registry); class-level `add_filter` is the process-wide one. Clean test isolation.
  Breaking for the rare code relying on the current global leak.

## Batch 4 - 2026-08-11 (owner delegated "pick the best" - ratified with principled defaults)

Ratified fixes: 24 clamp page>=1 + cap max per-page; 40 the 304 preserves ETag/Last-Modified + pin ONE weak
static ETag `W/"<size>-<mtime>"`; 41 honour `TINA4_PUBLIC_DIR` in Ruby+Node + one search-dir order; 28 fix
PHP's `seed_table` backtick quoting (breaks PG/MSSQL/Firebird + the dev-admin seed); 15 fix `migrate:status`
(py+php crash) + make the Node CLI use the real migrator + keep auto-migrate default-ON with
`TINA4_AUTO_MIGRATE=false` prod opt-out; 16 fix the generic next-id TOCTOU (lock/atomic) + the Mongo
no-increment; 22 fix Node's serialize-orphan + de-dup PHP's parallel impl + unify Python's cap; 23 fix PHP's
scope global-registry collision; 26 stop Python re-enforcing write constraints on READ + unify Ruby's two
read paths; 44 repeated field name -> a LIST in all four (no silent drop) + a safe-save helper + a running
per-chunk size counter in PHP/Ruby; 47 make Python run under production ASGI + guard PHP under FPM/Swoole; 45
fix Node's swagger boot-snapshot + add `/__feedback` to the exclusion list; 55 add Ruby's dotted
`obj.method()` call resolution; 58 disable the new Ruby/Node compilers under sandbox; 59/60 bound Python's
unbounded template caches + the fragment cache + compare mtime in prod.

Decided defaults: 47 background surface = a stop-handle + a `count()` in all four; 45 secured swagger ops
document a `401` (Python adds it); 52 `|join` default separator `", "` and `|default` keeps boolean `false`
(both 3-of-4 majority); 54 `even`/`odd` require a real integer (no PHP int-cast); 55 add `range()` as a global
in py/ruby/node + register the camelCase `formToken` alias everywhere; 57 `|tojson` uses the `\u`-escape model
everywhere + escaped charset `& < > " '` identical; 58 a denied filter RAISES (not PHP's silent pass-through);
59 template cache bound 256 insertion-order everywhere; 60 fragment cache within-instance-only but bounded +
keys namespaced (no network backend for now); 32 converge slash-normalization on PHP's grammar; 28 remove the
inert `seed_table(seed=)` param (same principle as the no-op `on_delete`); 22 imperative relationships are a
per-language idiom (do NOT force Ruby to add a distinct API - Ruby's is the declarative method invoked at
runtime).

## Batch 5 - 2026-08-11 (DB/ORM providers + dev-tooling/security - the last open findings)

### Decided (genuine either/or - owner)

- ODBC provider (13, ODBC-DEC-01) - DECIDED: ODBC is FIRST-CLASS. Provision a real ODBC source in CI
  (unixODBC + a SQLite/PostgreSQL ODBC driver) and run the shared write-path fixture through it - NOT
  "mark it experimental". This converts every latent ODBC finding into a caught bug. ODBC-DEC-02 (PK
  catalog query, remove Python `@@IDENTITY`/ignored-credentials, add the Node string-WHERE branch +
  owns-guard, fail-loud fetch) rides the fixture as fixes.
- Dev server bind (127, DEVADMIN-DEC-02) - DECIDED: BIND THE DEV SERVER TO LOCALHOST BY DEFAULT (not
  `0.0.0.0`), reusing the MCP loopback check for the REST surface. Defense-in-depth so a debug-on box is
  not a network-exposed RCE. The rest of the dev-admin package is ratified as fixes (below).
- HTTP client User-Agent (130, VERSION-DEC-03) - DECIDED: ADD a `Tina4/<version>` User-Agent to the
  outbound HTTP client in all four (outbound version visibility). VERSION-DEC-01 (single-resolver
  convergence in PHP + Node) and VERSION-DEC-02 (cross-source drift test) ride as fixes.
- Inline testing (132, INLINE-DEC-01) - DECIDED: wire ONE inline-testing surface per framework (the
  decorator/`@tests` model) so `tina4 test` actually discovers and runs the advertised tests with a
  real exit code, and fix the CLAUDE.md/docstring claims to match. INLINE-DEC-02 rides: resolve the
  assertion name collision, REMOVE PHP's `eval`/blanket `require_once` (arbitrary code execution), and
  de-couple the global registry in tests.

### Ratified fixes (vulns/correctness - not choices; principled defaults, ADR-0004 best-impl-prevails)

- Dev-admin security package (127, DEVADMIN-DEC-01/03/04/05/06) - FIX: fail-closed same-origin gate on
  the mutation surface (closes drive-by RCE); dotfile/secret denylist on the file endpoints (stop
  serving `.env`); escape the toolbar path in Python + Node (XSS); MERGE both the MCP-02 gate and these
  dev-admin fixes into v3 (the shipping branch currently exposes an ungated `mcp/call`); add
  real-dispatch conformance tests (no mocked req/resp).
- SQL translator (7, SQLTRANS-DEC-01/02/03) - FIX: literal-safe concat + bool/ilike rewrite
  (full-statement regressions); resolve the Ruby unwiring + remove the dead/duplicated code; BIGINT
  autoincrement + document the UPSERT/date-time omission.
- PostgreSQL as write-path oracle (9, PG-DEC-01) - FIX: make the adapter-contract test assert BEHAVIOUR
  with PostgreSQL as the model, all four.
- MySQL (10, MYSQL-DEC-01/02) - FIX: real-PK RETURNING emulation (not hardcoded `id`) with a non-`id`-PK
  regression; parameterize the DESCRIBE introspection; de-duplicate the batch-id math.
- MSSQL (11, MSSQL-DEC-01/02) - FIX: safe parameter handling (Ruby unknown-type bareword, Node
  Buffer->VarBinary); real-PK RETURNING; one pagination strategy.
- Firebird (12, FB-DEC-01/02/03) - FIX: replace the Ruby no-mock VIOLATION with a real reconnect test
  (non-negotiable per the project rule); generator last-id + real affected-count in Ruby/Node; verify
  blob + SRP-login handling; fix the CI-gate/CLAUDE.md claim; document the case trap.
- ORM base (17, ORM17-DEC-01) - FIX + MAINTAINABILITY: remove the vestigial state (Node `_exists`, PHP
  `tableFilter`, dead locals) - a less-code cleanup.
- ORM fields (18, FIELD-DEC-02) - FIX (the field MODEL itself is Batch 3, FIELD-DEC-01): convert the
  Python engine-DDL test to real engines; Ruby decimal precision; PHP datetime heuristic; Ruby FK name;
  PHP callable defaults.
- Input validation (19, VALID-DEC-01/02) - FIX: replace Python's placeholder validator tests with real
  ones; close Ruby's null-only ORM validation + Node's AutoCrud PUT validation gaps; unify the message
  vocabulary.
- Soft delete (20, SOFTDEL-DEC-01/02) - FIX: correct the force-delete record (it was PHP-only - a doc
  fix, no code change) + add PHP restore/with_trashed tests; make `create_table()` inject `is_deleted`
  for soft-delete models.
- Instance loading (26, LOAD-DEC-02) - FIX (LOAD-DEC-01 is Batch 4): pin the scalar read-coercion
  contract (JSON-only today) and make Node's read path consistent.
- Default landing page (46, LAND-DEC-01/02) - DECIDED dev-only (RATIFY - the code already suppresses in
  prod, which prevents an info-leak) + MAINTAINABILITY: unify the suppression conditions (remove Ruby's
  dead branch).
- Debug overlay (126, OVERLAY-DEC-01/02/03/04) - FIX + MAINTAINABILITY: DELETE the dead
  `render_production_error` in all four + its misleading docstring (a real production-no-leak test on
  the WIRED path replaces the unit test that only exercised a dead sibling); redact
  Authorization/Cookie/Set-Cookie in the dev overlay; guard the overlay render + cap the frame count;
  unify the debug gate.
- Dual test port (128, DUALPORT-DEC-01/02) - FIX: port Node's real dual-port test to Python/PHP/Ruby;
  single-source Ruby's base-port resolution; align PHP's constructor default.
- Port takeover (129, TAKEOVER-DEC-01/02/03) - FIX: add a Tina4-identity check before killing (PID file
  or `/__dev` probe) so it never kills a foreign process; bring the runtime path up to the CLI path's
  guards; add an opt-out (`TINA4_NO_TAKEOVER`/`--no-kill`) and gate takeover to dev.
- Test client (131, TC-DEC-01/02) - FIX: route Node's TestClient through the real dispatch pipeline
  (session stage + gate/middleware order); preserve duplicate headers on `TestResponse`, all four.
- Carbonah benchmarks (133, CARBON-DEC-01/02) - FIX: make `CARBONAH.md` a GENERATED artifact (from the
  benchmark JSONs + real suite counts + SCI); align the workload set across the four harnesses + add a
  workload-parity check.

## Status - DECISIONS COMPLETE

ALL v3 audit owner-decisions are ratified 2026-08-11 (Batches 1-5 + the standing compiler decision).
Every DEC-* across the 133 in-scope feature docs is OWNER-DECIDED. About 53 features carry at least one
ratified fix; the remaining features in 1-133 are already green and must STAY green.

**IMPLEMENTATION - 3.13.99 (owner target; re-numbered from 3.13.98 on 2026-08-11 - the skills release
took the .98 slot). Execution model REVISED by the owner 2026-08-11 - read this before any code:**

1. NO BASELINE RUN. The owner is explicit: "No baseline run" and "I am not comfortable with a base line
   run on python - everytime we do this we lose parity." We do NOT run the full suites up front to chase
   a green. Each feature is validated by ITS OWN real tests + the shared fixture, green in all four, on
   the lab.
2. ONE FEATURE FULLY COMPLETED BEFORE THE NEXT. "I want each feature to be fully completed before the
   next is tackled." A feature is done only when it is implemented in ALL FOUR frameworks, with real
   (no-mock) tests + the shared conformance fixture, and lab-validated GREEN in all four. Then commit,
   then the next feature. No batching across features, no parallel features - this is what protects
   parity (all four move together, one feature at a time).
3. GREEN FOR DEV, 1-133. The dev-release gate is: every feature in 1-133 is green. The ~53 with a
   ratified fix get implemented; the rest stay green (a feature's fix must never regress another).
4. MAINTAINABILITY LENS (owner: "optimize and make the code more maintainable"). Maintainability = LESS
   code. Each feature's definition-of-done also REMOVES the dead/duplicated code its finding names (7
   Ruby unwiring, 17 vestigial state, 22 PHP parallel impl, 28 inert param, 21 no-op on_delete, 46 Ruby
   dead branch, 126 dead `render_production_error`), prefers deleting to adding, and adds ZERO new
   runtime dependencies (the reuse ladder). A larger cross-cutting simplification becomes its own
   tracked item in the tracker - never a silent detour.

PER-FEATURE GATE (owner): implement in all four -> run the shared fixture + the feature's tests ON THE
.99 LAB BOX (real services, no mocks) -> a real GREEN in all four is the gate to commit + advance. Never
self-report green, never advance on a red. Branch discipline: feature/release3.13.99 -> v3 -> tag.
Per [[feedback_parity]], [[feedback_no_mock_testing]], [[feedback_conformance_testing]],
[[feedback_run_tests_on_99]], [[feedback_independent_verification]],
[[feedback_no_parallel_workers_one_tree]], [[feedback_maintainability_means_less_code]].
Tracker: `IMPLEMENTATION-3.13.99.md`.
