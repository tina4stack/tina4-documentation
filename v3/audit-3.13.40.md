# 3.13.40 audit batch - queued

Method for every item: audit -> fix on Python (master) -> mirror to PHP/Ruby/Node -> consistency + parity check across all 4 -> named lock-in/regression tests -> verify green. Banked into `feature/release3.13.40` (CLI: `feature/release3.8.52`).

Source: verified audit workflow (wf_e458d345, 2026-06-21) - 4 per-framework MCP deep-dives + coverage map. Full per-file findings were in /tmp (ephemeral); the load-bearing ones are captured below.

## P0 - MCP endpoint security (the headline finding, all 4 frameworks)

The v3.13.39 "localhost guard" is wired but on the WRONG signal. It is NOT a real fix.

- `is_localhost()` reads the CONFIGURED `TINA4_HOST_NAME` (default `localhost:7145`), never the real peer IP, and explicitly treats the default `0.0.0.0` bind as "localhost". So a normal `TINA4_DEBUG=true` dev box on a LAN / Docker / VM auto-enables MCP and exposes the full tool registry to any reachable, UNAUTHENTICATED caller. (Python `mcp/__init__.py:77-80`; PHP `MCP.php:689`; Ruby `mcp.rb:135-138`; Node `mcp.ts:224`.)
- No auth gate on ANY MCP surface - `/__dev` dispatch bypasses the bearer/API-key check in all 4.
- REST shim `/__dev/api/mcp/{tools,call}` is gated only by `TINA4_DEBUG`, NOT by `is_enabled()` (Python + Ruby), so `TINA4_MCP=false` and the localhost guard can be bypassed via the shim. Node auth-bypasses all `/__dev`.
- Tools reachable once exposed include `database_execute` (arbitrary INSERT/UPDATE/DELETE/DDL + commit, zero destructive-statement guard) and `file_write`/`file_patch`, which then run `.venv/bin/python3 -c "import <module>"` on the written file = remote code execution.
- `database_query` advertises "read-only SELECT" but enforces nothing (all 4).
- File sandbox uses a STRING `startswith` prefix check (Python + Node) -> sibling-prefix bug (`/srv/app` vs `/srv/app-secrets`); PHP `$safePath` never canonicalizes via `realpath()` (weaker, symlink risk).
- PHP-only bug: `database_query` drops decoded params and passes integer `10` into fetch's `$params` slot (`MCP.php:1062`). PHP `database_columns` interpolates the table name.
- Node: `migration_status`/`migration_run`/`route_test` are STUBS ("not yet implemented for Node.js") - parity gap.

Fixes (Python master first, then mirror):
1. Per-request peer-IP loopback check in EVERY handler (read `scope['client']` / `REMOTE_ADDR` / `req.socket.remoteAddress`); stop treating `0.0.0.0` as localhost.
2. Gate the REST shim on `is_enabled()` too.
3. `TINA4_MCP_REMOTE` must require an auth token (bearer/API-key) + ideally an IP allow-list - never a bare boolean handing over RCE + arbitrary SQL.
4. `database_query` enforce SELECT-only; `database_execute` allow-list / confirmation. Fix the PHP params + table-interpolation bugs.
5. Replace `startswith` with path-component containment (`is_relative_to`) + `realpath`/resolve canonicalization; reconsider the file_write -> import side-effect.
6. Node: implement the stubbed tools or remove them.

## P1 - never audited in 3.13.38/39, security-relevant
- **Auth + JWT + RBAC**: alg-confusion (alg=none, HS-vs-RS), expiry/refresh, timing-safe API-key + password compare in ALL 4 (Ruby only got timing-safe for sessions in 38), consistent RBAC/authorize primitive.
- **File uploads + streaming**: filename sanitization on save (the documented example writes `file['filename']` straight into a path = traversal), multipart part-count/size DoS limits, content-type trust.
- **Rate-limiting + CSRF + form tokens**: rate-limit key derivation behind proxies (X-Forwarded-For trust), counter store, CSRF rotation. v3.13.21 only fixed the signing secret.
- **Messenger / Mailer / SMTP / IMAP**: TLS/cert verification, STARTTLS downgrade, CRLF header-injection in mail composition, credential handling. (3.13.38 only did IMAP fail-loud + XSS child-escape.)

## P2 - functional audit + parity (user-requested)
- **Inline / xUnit testing** harness (ch18): audit + consistency + parity across all 4.
- **Swagger / OpenAPI**: proper audit "so we support everything" - params, schemas, security schemes, response types, $ref, and confirm the spec endpoint does not leak sensitive routes/schemas.
- **Localization / i18n**: locale-file loading path-traversal via user-supplied locale; parity.
- **DI Container**: edge-case + parity audit (untouched since v3.13.0 group renames).
- **Service Runner**: untouched since v3.13.1; audit lifecycle + parity.

## P3 - second-pass / lower priority
- GraphQL: query complexity/cost + alias amplification (beyond raw depth), production introspection toggle.
- WSDL: confirm DTD-reject on EVERY SOAP parse entry point, full parity tests.
- Scaffolding/init templates: generated `.env.example` must start secure-by-default (TINA4_SECRET set, CORS creds opt-in, AI host localhost, debug off) so new projects do not ship the 0.0.0.0+debug posture that opens the MCP hole.
- Rust CLI: `/__dev/api/reload` POST trust + general robustness pass.
- tina4-js: persist()/persistent-signal storage (no sensitive data), separate release1.3.0 line.
- Carry-over small items: metrics complexity-counter over-count; Redis distributed-cache follow-up; ORM callable-defaults / natural-key save (project_tina4_orm_gaps).

## Subsystem status snapshot (verified 2026-06-21)
AUDITED recently: ORM, DB contract, migrations, cache, queue, WebSocket, SSE, GraphQL, WSDL, sessions, middleware, events, htmlElement, logging, metrics, Frond, env-vars.
PARTIAL: MCP (P0), Auth/JWT/RBAC (P1), rate-limit/CSRF (P1), file uploads/streaming (P1), messenger XSS (SMTP path not).
NOT audited: Messenger/SMTP/IMAP (P1), Swagger (P2), i18n (P2), DI Container (P2), Service Runner (P2), inline testing (P2), Rust CLI (P3), tina4-js (P3), scaffolding (P3).
