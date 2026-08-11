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

## Status

ALL v3 audit owner-decisions run through and ratified 2026-08-11 (Batches 1-4 + the standing compiler
decision). Every DEC-* across the feature docs is OWNER-DECIDED.

**IMPLEMENTATION - 3.13.98 (owner target, 2026-08-11).** A single "first pass" from feature 1 to the end,
implementing every decided fix in all four frameworks with real (no-mock) tests + shared conformance
fixtures, shipped as the 3.13.98 release (feature/release3.13.98 -> v3 -> tag, per the release discipline).
"First pass" = a solid first implementation sweep, highest-value first within the walk (security cluster ->
data-loss/no-op -> parity); iterate after. Each feature doc's porting capsule + proposed fixture is the spec.
PER-FEATURE GATE (owner, 2026-08-11): after EACH feature is implemented in all four, RUN the shared
conformance fixture + the feature's tests ON THE .99 LAB BOX; a real green there (no mocks, real services) is
the gate to commit that feature and move to the next. Never self-report green, never advance on a red.
Per [[feedback_parity]] (logic AND tests in all four), [[feedback_no_mock_testing]],
[[feedback_conformance_testing]], [[feedback_run_tests_on_99]] (lab-verify before the tag),
[[feedback_no_parallel_workers_one_tree]] (never two workers in one git tree).

Remaining genuine decisions still to run (next batches): the Frond |date convention (52), ORM cascade/FK
(21), the write-result contract + field-model divergence (17/18), error-page 403 rendering + content
negotiation (42), route-group slash-normalization (32), ORM cache stale-read (25), AutoCrud validation status
(27), pagination clamp (24), migrations atomicity/auto-migrate (15), and the lexer/parser positions (48/49).
