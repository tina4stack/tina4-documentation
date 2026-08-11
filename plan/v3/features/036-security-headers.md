# Feature 36: Security headers middleware

## Identity and status

- Matrix identity: 36 - Security headers middleware
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language source (correcting a stub that claimed "protected by
  default" and an "HTTPS guard" - both FALSE). The middleware EXISTS in all four with byte-identical good
  defaults, but is OFF BY DEFAULT in all four (never registered). Python `core/middleware.py:455` (`46007c1`);
  PHP `Tina4/Middleware/SecurityHeaders.php:26` (`ab871934`); Ruby `lib/tina4/middleware.rb:685` (`f549923`);
  Node `packages/core/src/middleware.ts:816` (`1319cf3`).
- Dependencies: the middleware pipeline (feature 7), the response builder, env config.
- Dependants: every response's security posture.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

Security headers (X-Frame-Options, X-Content-Type-Options, HSTS, CSP, Referrer-Policy, X-XSS-Protection,
Permissions-Policy) defend against clickjacking, MIME-sniffing, and downgrade attacks. The audit questions:
are the headers and defaults the same, is the middleware ON by default, and is HSTS HTTPS-guarded. The header
set and defaults are byte-identical and sensible, but the middleware is OFF by default in all four and HSTS
has no HTTPS guard.

## Existing implementation evidence

Measured, all four:

- A `SecurityHeadersMiddleware` (PHP: `SecurityHeaders`) with a `before_security`/`beforeSecurity` hook exists
  in all four and sets 7 headers with BYTE-IDENTICAL defaults: `X-Frame-Options: SAMEORIGIN`,
  `X-Content-Type-Options: nosniff`, `Strict-Transport-Security: max-age=<TINA4_HSTS>; includeSubDomains` (only
  when `TINA4_HSTS` set), `Content-Security-Policy: default-src 'self'`, `Referrer-Policy:
  strict-origin-when-cross-origin`, `X-XSS-Protection: 0` (the modern value), `Permissions-Policy: camera=(),
  microphone=(), geolocation=()`. Five are env-overridable; `X-Content-Type-Options` and `X-XSS-Protection`
  are hardcoded.
- OFF BY DEFAULT in ALL FOUR: the class is NEVER registered in any framework's default middleware chain (the
  default chain wires CORS + rate-limit + logger; Node `server.ts:1648-1650`). So by default NO response
  carries any of these headers. An app must opt in with `Router.use(SecurityHeadersMiddleware)`.
- HSTS has NO HTTPS guard in any language (`if hsts:` / `if ($hsts !== '')` / `unless hsts.empty?` / `if
  (hsts)` - no scheme check), so it would be emitted on plain HTTP too when `TINA4_HSTS` is set.
- ZERO test coverage in all four (no test references the class or any header name). No shared fixture.
- Divergences: PHP's class is `SecurityHeaders` (not `SecurityHeadersMiddleware`); Python emits lowercase
  header names (cosmetic - HTTP is case-insensitive); PHP `nginx.conf.example` ships the DEPRECATED
  `X-XSS-Protection: 1; mode=block`, contradicting the framework's modern `0`.

## Public surface contract

`Router.use(SecurityHeadersMiddleware)` attaches the 7 headers to responses; env vars tune 5 of them. Today it
is opt-in, so the default contract is "no security headers".

## Inputs and outputs

- Input: the response + env (`TINA4_FRAME_OPTIONS`/`TINA4_HSTS`/`TINA4_CSP`/`TINA4_REFERRER_POLICY`/
  `TINA4_PERMISSIONS_POLICY`). Output: the 7 headers on the response (only if registered).

## Lifecycle and operation graph

1. The app registers the middleware (today: manually). 2. A `before` hook sets the 7 headers on each routed
response. Not registered -> no headers.

## Configuration and precedence

- 5 headers env-overridable; 2 hardcoded. `TINA4_HSTS` blank by default (HSTS off). No env to enable the
  middleware itself - it is code-registration only.

## Failures, side effects and security

- SECURITY (the crux): the framework SHIPS a good security-headers middleware but leaves it OFF, so a default
  Tina4 app has NO clickjacking/MIME/CSP protection unless the developer knows to register it. And HSTS, once
  enabled, is emitted on any scheme (no HTTPS guard). See the register.

## Wire and persistence contract

The 7 response headers (when registered). No persisted state. The default wire contract today is "none of
them".

## Providers and substitutability

A future runtime must ship the same header set + defaults, decide the on-by-default posture, and HTTPS-guard
HSTS.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SECHDR-OFF-BY-DEFAULT | The `SecurityHeadersMiddleware` exists in all four with byte-identical GOOD defaults, but is NEVER registered in any framework's default chain (the default chain is CORS + rate-limit + logger; `server.ts:1648`). So a default Tina4 app ships with NO security headers - the stub's "protected by default" is FALSE. The middleware is effectively dead code until an app opts in. | Decide (SECHDR-DEC-01): REGISTER it in the default chain (secure-by-default - a Tina4 app then ships with security headers) or keep it opt-in and document it loudly. This is the security-posture call. |
| SECHDR-HSTS-NO-HTTPS-GUARD | HSTS is emitted on ANY scheme when `TINA4_HSTS` is set (no HTTPS check) in all four - the stub's "added only when the request is HTTPS" is FALSE. Inert on HTTP (browsers ignore it) but the HTTPS-only contract does not exist, and a bad `max-age` would be sent on every scheme. | Add a scheme guard: emit HSTS only on an HTTPS request, in all four. |
| SECHDR-ZERO-TESTS | ZERO tests assert the headers on a real response in any language. | Add a wire test (register the middleware, assert the 7 headers + defaults) in all four. |
| SECHDR-PARTIAL-OVERRIDE | `X-Content-Type-Options` and `X-XSS-Protection` are HARDCODED (not env-overridable) - the stub's "each header overridable by its env var" is false (5 of 7). | Document which are fixed vs env-tunable (or make all overridable). |
| SECHDR-CLASS-NAME-DIVERGE | PHP's class is `SecurityHeaders`; the other three are `SecurityHeadersMiddleware`. A cross-language surface divergence. | Rename PHP to `SecurityHeadersMiddleware` for parity (or agree the name). |
| SECHDR-NGINX-DRIFT | PHP's `nginx.conf.example` ships the DEPRECATED `X-XSS-Protection: 1; mode=block`, contradicting the framework's modern `0` (and omitting CSP/Referrer/Permissions/HSTS). | Align the nginx example with the framework's header set + modern `0`. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- SECHDR-DEC-01 (proposed, THE call): decide the on-by-default posture (SECHDR-OFF-BY-DEFAULT). Registering the
  middleware in the default chain makes a Tina4 app secure-by-default (the headers + defaults are already
  good); keeping it opt-in requires loud documentation. Today it ships off in all four - a security-posture
  gap.
- SECHDR-DEC-02 (proposed): HTTPS-guard HSTS (SECHDR-HSTS-NO-HTTPS-GUARD); rename PHP's class
  (SECHDR-CLASS-NAME-DIVERGE); add wire tests (SECHDR-ZERO-TESTS); fix the nginx example (SECHDR-NGINX-DRIFT).

## Proposed conformance fixture

A shared fixture (real server): with the middleware registered, a response carries all 7 headers with the
agreed defaults, identical across the four; HSTS appears ONLY on an HTTPS request (catches
SECHDR-HSTS-NO-HTTPS-GUARD); and (after SECHDR-DEC-01) a default app either does or does not carry them per the
decided posture.

## Integration map

- Consumers: every response. Composes: the middleware pipeline (7), the response builder, env config. Related:
  CORS (33), CSRF (37).

## Breaking changes and migration

- Registering by default (if chosen) changes every app's response headers - a `Breaking:`/behaviour note (CSP
  `default-src 'self'` can break inline scripts; document the migration). HTTPS-guarding HSTS is a correctness
  fix.

## Porting capsule

Ship a security-headers middleware with the 7 headers + sensible defaults (SAMEORIGIN, nosniff, CSP
`default-src 'self'`, strict-origin-when-cross-origin, `X-XSS-Protection: 0`, a locked Permissions-Policy, HSTS
via env). Decide the on-by-default posture up front (secure-by-default beats a shipped-but-off middleware -
the current gap in all four). HTTPS-GUARD HSTS (never emit it on plain HTTP). Wire-test the headers on a real
response. Keep the class name and header set identical across languages.

## Audit closure checklist

- [x] Boundary and public surface complete (7 headers + middleware x four).
- [x] Lifecycle and producer/consumer edges complete (register -> before-hook -> headers).
- [x] Configuration (env overrides), failure and SECURITY (off-by-default, HSTS-no-guard) rules complete.
- [x] Wire (7 headers) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (identical defaults; OFF by default all four; no HTTPS guard).
- [x] Owner ambiguities decided (SECHDR-DEC-01 posture, SECHDR-DEC-02 HSTS/tests/name).
- [x] Conformance fixture (headers + HTTPS-only HSTS) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
