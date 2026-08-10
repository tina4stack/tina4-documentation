# Feature 037: CSRF protection

## Identity and status

- Matrix identity: 37 - CSRF protection
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (`CsrfMiddleware` in each
  framework, plus the Frond `formToken`/`form_token` helper). No framework code changed.
- Dependencies: Feature 33 middleware pipeline (runs AFTER routing), Feature 31 router (reads
  matched-route metadata for exemptions), sessions (the token is session-bound), Frond (emits
  the token)
- Dependants: any cookie-session form POST; the Frond templates that render forms
- Existing ADRs: the routing-surface security intent (ADR-0019); the middleware ordering rule
- Shared fixtures: `csrf_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

A browser sends a user's session cookie on every request, including one a malicious site
triggers. CSRF protection makes a state-changing request prove it came from the application's
own form, by carrying a session-bound token that a cross-site page cannot forge - the same way
in all four languages.

## Boundary

This feature owns `CsrfMiddleware`: the token validation on state-changing requests, the
exemption rules, and the error contract. It DELEGATES token GENERATION to Frond
(`formToken`/`form_token`), the session binding to the session store, the pipeline ordering to
Feature 33, and the route metadata (for `@noauth` exemption) to Feature 31.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Class | `CsrfMiddleware` | `CsrfMiddleware` | `CsrfMiddleware` | `CsrfMiddleware` |
| Default | OFF | OFF | OFF | OFF |
| Enable | `TINA4_CSRF=true` or `Router.use(CsrfMiddleware)` | same | same | same |
| Validated methods | state-changing (POST/PUT/PATCH/DELETE) | same | same | same |
| Skips safe methods | GET/HEAD/OPTIONS | GET/HEAD/OPTIONS | same | same |
| Skips `@noauth` routes | yes | yes | yes | yes |
| Skips Bearer-auth requests | yes | yes | yes | yes |
| Token lookup | body `formToken` then `X-Form-Token` | same | same | same |
| Token binding | session_id in payload, matched to session | same | same | same |
| Failure | 403 `CSRF_INVALID` | 403 `CSRF_INVALID` | 403 `CSRF_INVALID` | 403 `CSRF_INVALID` |
| Runs | AFTER routing | AFTER routing | AFTER routing | AFTER routing |

CSRF is strongly converged: the same `CsrfMiddleware` class, off by default, enabled by
`TINA4_CSRF=true` or `Router.use`, validating only state-changing methods, skipping safe
methods, `@noauth` routes and Bearer-authenticated requests, reading `formToken` from the body
then `X-Form-Token` from headers, verifying a session-bound token, and returning 403
`CSRF_INVALID` on failure. Frond's `formToken`/`form_token` generates the token bound to the
session_id, so a token a template emits validates against the request's session.

## Public surface contract

`CsrfMiddleware` is registered via `Router.use(CsrfMiddleware)` or activated by `TINA4_CSRF=true`.
On a state-changing request it reads the token from `body["formToken"]` then
`headers["X-Form-Token"]`, verifies the token and its embedded session_id against the current
session, and returns 403 `CSRF_INVALID` when the token is missing, malformed or session-mismatched.
It skips GET/HEAD/OPTIONS, `@noauth` routes and requests carrying a valid Bearer token. Frond's
`formToken()`/`form_token()` emits the matching token for a template form.

## Inputs and outputs

- Input: a request (method, matched route, session, and the `formToken` body field or
  `X-Form-Token` header) and the `TINA4_CSRF` toggle.
- Output: the request proceeds when the token is valid or the request is exempt; otherwise a
  403 with error code `CSRF_INVALID`.
- The token is session-bound: its payload carries the session_id and is verified against the
  request's session, so a token from another session is rejected.
- Frond emits a token that this middleware accepts (generation and validation agree).

## Lifecycle and operation graph

1. The middleware runs AFTER routing (so it can read the matched route's `@noauth` flag).
2. It exits immediately for a safe method (GET/HEAD/OPTIONS), a `@noauth` route, or a request
   with a valid Bearer token.
3. For a state-changing, cookie-session request it reads `formToken` from the body, else
   `X-Form-Token` from headers.
4. It verifies the token and matches its embedded session_id to the current session.
5. A valid token continues the pipeline; an invalid or missing one returns 403 `CSRF_INVALID`.

## Configuration and precedence

- `TINA4_CSRF=true` enables the middleware globally; `Router.use(CsrfMiddleware)` enables it
  explicitly. It is OFF by default (opt-in, because it requires session-backed forms).
- The exemption set is fixed and security-critical: safe methods, `@noauth` routes, and
  Bearer-auth requests. It is neither broadened (which would open a bypass) nor narrowed (which
  would break API clients).

## Failures, side effects and security

- A missing, malformed or session-mismatched token on a protected request returns 403
  `CSRF_INVALID`; it NEVER falls through to the handler.
- Bearer-auth requests are exempt BY DESIGN: a Bearer token is not ambient (a cross-site page
  cannot set it), so it is not a CSRF vector; requiring a form token there would break API
  clients for no security gain.
- The token is session-bound, so a valid token stolen from another session does not authorize a
  request; this is why the payload carries session_id.
- The exemption set is the security surface: an over-broad exemption (for example skipping all
  POSTs to `/api`) would be a bypass, so the exact set must be identical across the four and
  gated.
- CSRF runs AFTER routing deliberately, so it can honor `@noauth`; running it before would
  either miss the route metadata or protect routes that opted out.

## Wire and persistence contract

There is no new persistence beyond the session. The wire contract is the token transport
(`formToken` body field, `X-Form-Token` header) and the failure shape (403 with error code
`CSRF_INVALID`), identical across the four. The token payload format (carrying session_id) must
be the same so Frond generation and middleware validation interoperate within a language.

## Providers and substitutability

CSRF is transport-level and engine-agnostic; it depends only on the session store and the
router metadata. A future runtime implements the same `CsrfMiddleware` with the same off-by-
default, the same exemptions, the same token transport and the same 403 `CSRF_INVALID`.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| CSRF-01 | The exemption set (safe methods, `@noauth`, Bearer-auth) is security-critical; a divergence would open a bypass or break API clients. It is not gated as parity. | Gate the exact exemption set in all four -- each exemption present, and no extra one. |
| CSRF-02 | The session-bound token (session_id in payload, matched to session) must be identical so Frond generation and middleware validation interoperate. | Gate that a Frond-emitted token validates and a foreign-session token is rejected, in all four. |
| CSRF-03 | The token transport (`formToken` body then `X-Form-Token` header) and the 403 `CSRF_INVALID` shape are converged but not gated. | Gate both transports and the failure shape in all four. |
| CSRF-04 | The off-by-default + enable mechanism (`TINA4_CSRF`/`Router.use`) is converged but not gated. | Gate that CSRF is off by default and on via either mechanism, in all four. |
| CSRF-05 | The after-routing ordering is required for `@noauth` to work; not gated. | Gate that CSRF runs after routing (a `@noauth` route is exempt) in all four. |
| CSRF-06 | No shared fixture exists. | Add `csrf_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The strategy is a SESSION-BOUND form token (payload carries session_id, verified against the
   current session), NOT a stateless double-submit cookie; this is the shipped design in all
   four and is kept.
2. The exemption set is exactly: safe methods (GET/HEAD/OPTIONS), `@noauth` routes, and
   Bearer-authenticated requests. Identical in all four, neither broadened nor narrowed.
3. The token is read from `body["formToken"]` then `headers["X-Form-Token"]`; failure is 403
   with error code `CSRF_INVALID`.
4. CSRF is OFF by default and enabled by `TINA4_CSRF=true` or `Router.use(CsrfMiddleware)`.
5. Frond's `formToken`/`form_token` is the token source; a token it emits must validate against
   the same session.

## Proposed conformance fixture

Add `csrf_contract.json` with stable ids for: a state-changing request WITHOUT a token returning
403 `CSRF_INVALID`; a valid Frond-emitted token passing (both via `formToken` body and via
`X-Form-Token` header); a token from a DIFFERENT session rejected; each exemption exercised (a
GET passes, a `@noauth` POST passes, a Bearer-auth POST passes); CSRF OFF by default (a POST
without a token passes when disabled); and CSRF ON via both `TINA4_CSRF` and `Router.use`. Every
case runs against a real request through the real middleware with a real session; no mock can
claim conformance (a mocked session would not prove the session binding).

## Integration map

- Feature 33 wires the middleware after routing; Feature 31 supplies the `@noauth` metadata;
  the session store binds the token; Frond emits it.
- The Bearer-auth exemption ties to the auth layer; the `@noauth` exemption ties to the router.
- Central fixtures, four runners, the CI matrix and the security/Frond docs update together.

## Breaking changes and migration

- No change to the shipped contract (converged); the audit gates it. If any framework's
  exemption set is found to differ under test, aligning it is a security correction, noted in
  the release note.
- CSRF stays off by default; no application is newly gated without opting in.

## Implementation backlog

1. Add `csrf_contract.json` and wire four runners against real requests and sessions.
2. Gate the exemption set (CSRF-01) and the session-bound token interop with Frond (CSRF-02).
3. Gate the token transports and the 403 `CSRF_INVALID` shape (CSRF-03).
4. Gate off-by-default + both enable mechanisms (CSRF-04) and the after-routing ordering
   (CSRF-05).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `CsrfMiddleware`, off by default, enabled by `TINA4_CSRF=true` or `Router.use`. Run it
AFTER routing. Skip GET/HEAD/OPTIONS, `@noauth` routes, and Bearer-authenticated requests. On a
protected request, read `formToken` from the body then `X-Form-Token` from headers, verify the
token and match its embedded session_id to the current session, and return 403 `CSRF_INVALID`
on any failure. Pair it with a Frond `formToken`/`form_token` helper that emits a session-bound
token this middleware accepts. Prove the port with a missing-token 403, a valid-token pass, a
foreign-session rejection, and each exemption.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (CSRF-01..06).
- [x] Owner ambiguities recorded (5 proposed; the exemption-set parity is the key security one).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
