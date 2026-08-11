# Feature 37: CSRF protection

## Identity and status

- Matrix identity: 37 - CSRF protection
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language source. SECURITY-CRITICAL - the SEC-01 no-default-secret
  hardening is complete + locked ONLY in Python; PHP ships a LIVE default-secret bypass, Node ships a
  generator/validator secret split. Python `core/middleware.py:503` + `auth/__init__.py:191` (`46007c1`); PHP
  `Tina4/Middleware/CsrfMiddleware.php:32` + `Tina4/Frond.php:3420` (`ab871934`); Ruby
  `lib/tina4/middleware.rb:582` (`f549923`); Node `packages/core/src/middleware.ts:874` +
  `packages/frond/src/engine.ts:1590` (`1319cf3`).
- Dependencies: Auth (token signing, feature family), the Frond form-token helper, the request (29).
- Dependants: every state-changing form/route.
- Existing ADRs: SEC-01 (no default-secret fallback).

- Catalog phase: Routing and middleware

## Why this feature exists

CSRF protection stops a third-party site from forcing a state-changing request with the user's cookies. Tina4
uses a signed `formToken` (a JWT) delivered in the form/header and validated on writes. The audit questions:
is the secret fail-closed, is the middleware on, and is the token forgeable. Python is fail-closed; PHP and
Node are forgeable when `TINA4_SECRET` is unset; and the middleware is opt-in (off) in all four.

## Existing implementation evidence

Measured, all four:

- A `CsrfMiddleware` (`before_csrf`/`beforeCsrf`) exists in all four: skips GET/HEAD/OPTIONS, gates
  POST/PUT/PATCH/DELETE, reads `formToken` from the body then the `X-Form-Token` header, REJECTS a
  query-string token (403), compares timing-safe, and returns 403 `CSRF_INVALID` on a missing/invalid token.
  `@noauth`/`.noAuth` routes and a valid Bearer are exempt. Consistent + correct across the four.
- IT IS OPT-IN (OFF) in all four: the middleware is never auto-attached; `TINA4_CSRF` is read only for the
  enabled/disabled flag AFTER attachment - NOTHING reads it to attach the middleware. So `TINA4_CSRF=true`
  alone does nothing, and a default app has NO CSRF protection unless the developer registers the middleware.
- SECRET RESOLUTION diverges (the security crux): Python signs + validates with a BLANK secret when
  `TINA4_SECRET` is unset (warn, dev auto-mints - `auth/__init__.py:191`); Ruby same (blank + warn); PHP signs
  AND validates with the PUBLIC constant `'tina4-default-secret'` (`Frond.php:3421`, `CsrfMiddleware.php:118`)
  AND mutates `$_ENV['TINA4_SECRET']` as a side effect (`Frond.php:3420`); Node's GENERATOR signs with
  `'tina4-default-secret'` (`engine.ts:1590`) while the VALIDATOR uses `''` (`auth.ts:424`) - they disagree.
- The form token doubles as a WRITE-ROUTE AUTH credential (the auth gate accepts a valid `formToken` as
  satisfying auth - PHP `Router.php:1497`), so a forgeable form token is also an auth bypass.
- The SEC-01 behavioral regression (a token forged with `'tina4-default-secret'` is rejected) exists ONLY in
  Python (`test_csrf_middleware.py:490`).

## Public surface contract

`Router.use(CsrfMiddleware)` gates writes on a valid signed `formToken`; `{{ form_token() }}` delivers it.
The contract SHOULD be: the token is unforgeable (secret fail-closed) and the middleware is enable-able by
config. Neither holds uniformly.

## Inputs and outputs

- Input: a write request + `formToken` (body/header) + `TINA4_SECRET`. Output: pass, or 403 `CSRF_INVALID`.

## Lifecycle and operation graph

1. Render `{{ form_token() }}` -> a signed JWT. 2. The client posts it. 3. `CsrfMiddleware` (if attached)
validates it on a write -> pass or 403.

## Configuration and precedence

- `TINA4_SECRET` (signing key), `TINA4_CSRF` (enable flag, only after attachment), `TINA4_TOKEN_EXPIRES_IN`.
  The middleware must be attached in code.

## Failures, side effects and security

- SECURITY (critical, see the register): with `TINA4_SECRET` unset, PHP and Node form tokens are forgeable
  with a key that is PUBLIC in the source - a CSRF bypass and (since the token doubles as auth) a write-route
  auth bypass. PHP additionally poisons the whole process's JWT secret via a `$_ENV` mutation. The middleware
  is off by default in all four, so an app is unprotected unless it opts in.

## Wire and persistence contract

The `formToken` JWT (body/header); a 403 `CSRF_INVALID` on failure. No persisted state (not session-bound by
default).

## Providers and substitutability

A future runtime must sign+validate with a fail-closed secret (no shipped named default), attach controllably,
and bind the token to the session.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CSRF-PHP-DEFAULT-SECRET | SECURITY (critical, LIVE): PHP signs AND validates the form token with the PUBLIC constant `'tina4-default-secret'` when `TINA4_SECRET` is unset (`Frond.php:3421`, `CsrfMiddleware.php:76,118`). An attacker forges a `formToken` with this source-public key -> CSRF bypass AND write-route AUTH bypass (the token doubles as an auth credential, `Router.php:1497`). Worse, `Frond.php:3420` MUTATES `$_ENV['TINA4_SECRET']`, so ONE `{{ form_token() }}` render degrades the entire process's JWT signing to the public default. This is the exact SEC-01 hole Python closed; unguarded (no regression test). | Remove the `'tina4-default-secret'` fallback (both generation and validation) and the `$_ENV` mutation in PHP; fail-closed like Python; add the SEC-01 regression test. |
| CSRF-NODE-SECRET-SPLIT | SECURITY/BUG: Node's GENERATOR signs with `'tina4-default-secret'` (`engine.ts:1590`) but the VALIDATOR uses `''` (`auth.ts:424`) - they disagree. With `TINA4_SECRET` unset: a legitimately-rendered form token is REJECTED (self-inflicted 403 for real users) AND a `''`-forged token is ACCEPTED (bypass). Node's SEC-01 fix reached `auth.ts` but NOT the Frond generator. | Align the Frond generator to the same secret resolution as the validator (fail-closed); add the SEC-01 regression test. |
| CSRF-NOT-AUTOWIRED | UNIVERSAL: `CsrfMiddleware` is opt-in and NEVER auto-attached in any framework; `TINA4_CSRF` is read only AFTER attachment, so `TINA4_CSRF=true` alone does nothing, and a default app has NO CSRF protection. The docstrings ("off by default - active when TINA4_CSRF=true") are misleading (nothing reads it to attach; once attached it is ON by default). | Decide: make `TINA4_CSRF=true` actually ATTACH the middleware (env-controllable), or document loudly that CSRF is opt-in-by-registration. Correct the docstrings. |
| CSRF-NO-SEC01-TEST-3OF4 | The behavioral SEC-01 no-default-secret regression exists ONLY in Python (`test_csrf_middleware.py:490`). PHP's live vuln is untested; Node's split is untested; Ruby is clean-by-construction but has no behavioral CSRF SEC-01 test (only a session source-grep). | Port the Python SEC-01 regression (a `'tina4-default-secret'`/`''`-forged token is rejected) to PHP/Node/Ruby. |
| CSRF-BLANK-NOT-RAISE | HONEST QUALIFIER (all four): NONE raise on a blank secret. "Fail closed" here = no shipped named default (py/ruby) + a loud warning + dev auto-mint - NOT an unforgeable state. A prod deploy that ignores the warning and runs `TINA4_SECRET` blank is STILL forgeable (an empty-string HMAC key is publicly reproducible). PHP/Node still ship the named public key on at least one side. | Consider RAISING (refusing to sign/validate) on a blank secret in production, in all four - the strongest fail-closed. |
| CSRF-NOT-SESSION-BOUND | UNIVERSAL: the form token is NOT session-bound by default (a `session_id` is added only if a session is active) - it is an app-wide signed nonce, so protection rests entirely on secret secrecy. And the `type:"form"` claim is not enforced (any valid JWT is accepted in the `formToken` slot). | Bind the token to the session by default; enforce `type == "form"`. |

## Owner decisions

- CSRF-DEC-01 (proposed, SECURITY - highest priority in the audit): remove PHP's `'tina4-default-secret'`
  fallback + `$_ENV` mutation (CSRF-PHP-DEFAULT-SECRET) and fix Node's generator/validator secret split
  (CSRF-NODE-SECRET-SPLIT) - both are live token-forgery -> CSRF + write-auth bypass. Port the Python SEC-01
  regression test to PHP/Node/Ruby (CSRF-NO-SEC01-TEST-3OF4). Consider RAISING on a blank prod secret
  (CSRF-BLANK-NOT-RAISE).
- CSRF-DEC-02 (proposed): decide the auto-wire posture (CSRF-NOT-AUTOWIRED) - make `TINA4_CSRF` attach the
  middleware or document opt-in loudly and fix the docstrings; bind the token to the session + enforce
  `type=="form"` (CSRF-NOT-SESSION-BOUND).

## Proposed conformance fixture

A shared fixture (real dispatch, no mocks): a token forged with `'tina4-default-secret'` (and with `''`) is
REJECTED 403 in all four (catches CSRF-PHP-DEFAULT-SECRET + CSRF-NODE-SECRET-SPLIT); a legitimately-rendered
token with `TINA4_SECRET` unset behaves consistently (not the Node self-reject); a query-string token is 403;
a valid token passes; a write without a token is 403.

## Integration map

- Consumers: every state-changing route/form. Composes: Auth (token signing), the Frond form-token helper,
  the request (29), the write-auth gate (the token doubles as auth). Related: SECHDR (36).

## Breaking changes and migration

- Removing the default-secret fallback makes previously-accepted (forged) tokens fail - a security fix; note
  it. Making `TINA4_CSRF` attach the middleware changes default behaviour - document it.

## Porting capsule

CSRF uses a signed `formToken` (JWT) validated on writes. Sign AND validate with a FAIL-CLOSED secret - NEVER
a shipped named default (`'tina4-default-secret'` is a CSRF + auth bypass), the generator and validator MUST
use the SAME resolution (Node's split is a live bug), and never mutate the global secret as a side effect (the
PHP `$_ENV` poisoning). Reject a query-string token, compare timing-safe, return 403 on missing/invalid. Bind
the token to the session and enforce `type=="form"`. Decide whether the middleware auto-attaches via env or is
opt-in - but never claim protection that a default app does not have.

## Audit closure checklist

- [x] Boundary and public surface complete (CsrfMiddleware + formToken x four).
- [x] Lifecycle and producer/consumer edges complete (render -> post -> validate).
- [x] Configuration (secret/enable), failure and SECURITY (default-secret, split, off-by-default) rules complete.
- [x] Wire (formToken JWT, 403) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (Python fail-closed; PHP default-secret; Node split; all off).
- [x] Owner ambiguities decided (CSRF-DEC-01 secret security, CSRF-DEC-02 auto-wire/session-bind).
- [x] Conformance fixture (forged-token rejection + off-by-default) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
