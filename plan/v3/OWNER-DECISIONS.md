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

## Pending batches

Remaining genuine decisions still to run (next batches): the Frond |date convention (52), ORM cascade/FK
(21), the write-result contract + field-model divergence (17/18), error-page 403 rendering + content
negotiation (42), route-group slash-normalization (32), ORM cache stale-read (25), AutoCrud validation status
(27), pagination clamp (24), migrations atomicity/auto-migrate (15), and the lexer/parser positions (48/49).
