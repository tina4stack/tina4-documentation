# Feature 036: Security headers middleware

## Identity and status

- Matrix identity: 36 - Security headers middleware
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (PHP `Middleware/SecurityHeaders.php`,
  Python/Ruby/Node in their middleware modules). No framework code changed.
- Dependencies: Feature 33 middleware pipeline (this is a before-hook), Feature 30 response
  model (it sets headers), Feature 29 request (to detect HTTPS for HSTS)
- Dependants: every response; the CORS and CSP posture; browser security behaviour
- Existing ADRs: the routing-surface security intent (ADR-0019); the env-uniformity rule
- Shared fixtures: `security_headers_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

A browser trusts the headers a response carries. One middleware sets the security headers -
frame options, content-type sniffing, HSTS, CSP, referrer and permissions policy - the same way
in all four languages, so an application is protected by default rather than by remembering to
set each header on every route.

## Boundary

This feature owns the security-header set, its defaults, and the environment variables that
tune it. It DELEGATES header writing to Feature 30, the before-hook wiring to Feature 33, and
the HTTPS detection (for HSTS) to Feature 29. It does not own CORS (Feature 34) or CSRF
(Feature 37), which are separate middlewares.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Location | `core/middleware.py` | dedicated `SecurityHeaders` class | `middleware.rb` | `middleware.ts` |
| X-Frame-Options | SAMEORIGIN | SAMEORIGIN | SAMEORIGIN | SAMEORIGIN |
| X-Content-Type-Options | nosniff | nosniff | nosniff | nosniff |
| X-XSS-Protection | `0` | `0` | `0` | `0` |
| Content-Security-Policy | `default-src 'self'` | same | same | same |
| Referrer-Policy | strict-origin-when-cross-origin | same | same | same |
| Permissions-Policy | camera=(), microphone=(), geolocation=() | same | same | same |
| HSTS | opt-in via TINA4_HSTS | same | default "" = off | same |
| Env config | TINA4_FRAME_OPTIONS/HSTS/CSP/REFERRER_POLICY/PERMISSIONS_POLICY | same | same | same |

This is one of the most converged features in the matrix: the same seven headers, the same
defaults, the same five environment variables, and the same modern `X-XSS-Protection: 0` (which
DISABLES the deprecated, vulnerability-prone XSS auditor rather than the old `1; mode=block`).
The one structural difference is that PHP carries a dedicated `SecurityHeaders` class with a
`beforeSecurity` hook, while Python, Ruby and Node keep the logic inside their general
middleware module.

## Public surface contract

The middleware runs as a before-hook and sets, on every response: `X-Frame-Options`
(SAMEORIGIN), `X-Content-Type-Options` (nosniff), `X-XSS-Protection` (0), `Content-Security-Policy`
(`default-src 'self'`), `Referrer-Policy` (strict-origin-when-cross-origin), and
`Permissions-Policy` (camera=(), microphone=(), geolocation=()). `Strict-Transport-Security` is
added only when `TINA4_HSTS` is set AND the request is HTTPS. Each header's value is overridable
by its environment variable.

## Inputs and outputs

- Input: the environment variables (or their defaults) and the request (for the HTTPS check).
- Output: the six always-on security headers on every response, plus HSTS when configured and
  over HTTPS.
- An overriding environment variable replaces the default value verbatim.
- The header names and default values are identical across the four.

## Lifecycle and operation graph

1. The before-hook reads each header's env var or default.
2. It sets the six always-on headers on the response.
3. If `TINA4_HSTS` is set and the request is HTTPS, it adds `Strict-Transport-Security` with
   the configured max-age and `includeSubDomains`.
4. The response proceeds through the rest of the pipeline; a later handler may override a
   header, but the secure defaults are present unless deliberately changed.

## Configuration and precedence

- `TINA4_FRAME_OPTIONS`, `TINA4_HSTS`, `TINA4_CSP`, `TINA4_REFERRER_POLICY`,
  `TINA4_PERMISSIONS_POLICY` override the defaults; an unset variable uses the secure default.
- HSTS is OFF by default (empty `TINA4_HSTS`) and is sent only over HTTPS, because HSTS over
  plain HTTP is meaningless and a wrong max-age can lock users out.
- The enable mechanism (on-by-default versus opt-in) must be identical across the four -- a
  security default that is on in three languages and off in one is the dangerous case.

## Failures, side effects and security

- These headers ARE the security posture; the audit's job is to guarantee they are set
  identically, so an app is not protected on PHP and exposed on Node.
- HSTS is HTTPS-only and opt-in: sending it over HTTP is ignored by browsers, and a careless
  default max-age can pin a bad certificate, so it stays deliberate.
- `X-XSS-Protection: 0` is intentional and modern; reverting to `1; mode=block` would
  reintroduce the auditor-based vulnerabilities and is a regression, not a hardening.
- A per-route override is allowed (a route may loosen CSP for an embed) but the DEFAULT is
  strict; loosening is explicit, never the baseline.

## Wire and persistence contract

There is no persistence; the wire output is the response header set. The exact header names and
default values are the contract and are byte-identical across the four. A consumer (a browser)
sees the same protection regardless of which language served the response.

## Providers and substitutability

The middleware is transport-level and engine-agnostic. A future runtime sets the same seven
headers with the same defaults and the same env overrides, and applies the same HSTS
HTTPS-only opt-in.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SEC-01 | The enable mechanism (on-by-default vs opt-in) is not proven identical across the four; a security default on in three and off in one is dangerous. | Pin ONE enable mechanism (recommend on-by-default with secure values) identical in all four; gate that the headers are present by default. |
| SEC-02 | HSTS must be opt-in AND HTTPS-only; the HTTPS guard is not gated as parity. | Gate that HSTS is absent by default, absent over HTTP even when configured, and present over HTTPS when configured, in all four. |
| SEC-03 | Structural divergence: PHP has a dedicated `SecurityHeaders` class; the others inline it. | Converge on one entry-point name/shape so the middleware is registered and named the same way. |
| SEC-04 | The seven-header set and defaults are converged but not gated; a drift (a changed default, a missing header) would be silent. | Gate the full header set and every default (including `X-XSS-Protection: 0`) in all four. |
| SEC-05 | No shared fixture exists. | Add `security_headers_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The canonical set is the seven headers with the measured defaults, identical in all four:
   X-Frame-Options SAMEORIGIN, X-Content-Type-Options nosniff, X-XSS-Protection 0, CSP
   `default-src 'self'`, Referrer-Policy strict-origin-when-cross-origin, Permissions-Policy
   camera=()/microphone=()/geolocation=(), and HSTS opt-in.
2. One enable mechanism across the four (recommend on-by-default with the secure values so an
   app is protected without ceremony); an app loosens a header explicitly.
3. HSTS is opt-in via `TINA4_HSTS` and HTTPS-only; it is never sent over plain HTTP.
4. `X-XSS-Protection` stays `0` (modern); it is not reverted to the deprecated auditor value.
5. One entry-point name/shape (PHP's dedicated middleware is the reference); the others expose
   the same registration.

## Proposed conformance fixture

Add `security_headers_contract.json` with stable ids for: the six always-on headers present
with their exact default values on a plain response; each env override replacing its default;
HSTS ABSENT by default; HSTS absent over HTTP even when `TINA4_HSTS` is set; HSTS present with
`includeSubDomains` over HTTPS when set; `X-XSS-Protection` exactly `0`; and the same enable
mechanism producing the headers by default. Every case inspects a real response from a real
request through the real middleware; no mock can claim conformance.

## Integration map

- Feature 33 wires the before-hook; Feature 30 writes the headers; Feature 29 supplies the
  HTTPS signal; Feature 34 (CORS) and Feature 37 (CSRF) are sibling middlewares.
- The env variables follow the env-uniformity rule; the docs list them once.
- Central fixtures, four runners, the CI matrix and the security docs update together.

## Breaking changes and migration

- If the enable mechanism is unified to on-by-default where a language was opt-in, that
  language's apps gain the headers; state it in the release note (it is a hardening).
- No change to the header values (already converged). Converging the entry-point name is
  internal.

## Implementation backlog

1. Add `security_headers_contract.json` and wire four runners against real responses.
2. Pin and gate the enable mechanism (SEC-01) and the HSTS HTTPS-only opt-in (SEC-02).
3. Gate the full header set and defaults including `X-XSS-Protection: 0` (SEC-04).
4. Converge the entry-point name/shape (SEC-03).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a before-hook that sets the six always-on security headers with the measured defaults
and adds HSTS only when `TINA4_HSTS` is set and the request is HTTPS. Read each value from its
`TINA4_*` env var with the secure default as fallback. Keep `X-XSS-Protection: 0`. Register it
with the same name/shape as the others and on by default. Prove the port against a real
response, including HSTS absent over HTTP and present over HTTPS.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (SEC-01..05).
- [x] Owner ambiguities recorded (5 proposed; the enable-mechanism and HSTS calls are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
