# Feature 131: In-process HTTP test client (TestClient)

## Identity and status

- Matrix identity: 131 - In-process HTTP test client (`tina4_python/test_client/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, strong on three, a lower-fidelity re-implementation on one. Measured
  2026-08-11 from shipped source by four parallel readers (batched with 132). Python
  `tina4_python/test_client/__init__.py` (210 lines, `feature/csrf-fail-closed` HEAD `ebbab30`); PHP
  `Tina4/TestClient.php` (182 lines, `feature/mcp-call-gate` HEAD `6faabac5`); Ruby
  `lib/tina4/test_client.rb` (`feature/mcp-call-gate` HEAD `6d5b1de`); Node
  `packages/core/src/testClient.ts` (281 lines, `feature/mcp-call-gate` HEAD `27cf0f4`).
- Dependencies: the framework's dispatch entry point (the ASGI `app` / `Router::dispatch` / `RackApp#call` /
  the dispatch stages), the auth gate, and the request/response wrappers.
- Dependants: the framework's own test suites (dogfooding) and the scaffolded secure-by-default gate tests
  emitted by `generate`. The xUnit inline-testing class (feature 132) uses it for HTTP.
- Existing ADRs: ADR-0012 (auth gate before route middleware) is the order the client must honour.

- Catalog phase: developer experience (testing)

## Why this feature exists

A test that stands up a real socket server is slow and flaky; a test that calls a handler function directly
skips everything that makes the request real - routing, middleware, the auth gate, sessions. The TestClient
is the middle path: it drives a request through the SAME dispatch the live server runs, in-process, with no
socket. Its whole value is fidelity - a `client.post(...)` must hit exactly what a real POST hits, or the
test proves nothing about production.

## Boundary

This packet owns the client: the verb methods, the request construction, the response object, and the call
into dispatch. It does NOT own the dispatch pipeline itself (it invokes it) or the auth gate (it must run
it, not reimplement it).

## Existing implementation evidence

Fidelity parity table (the question that decides the feature's worth):

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Entry into dispatch | the real ASGI `app()` | `Router::dispatch` | `RackApp#call` | a RE-IMPLEMENTATION of dispatch |
| Runs the real front controller | YES | YES | YES | NO (parallel dispatch) |
| Session stage runs | YES | YES | YES | NO (skipped) |
| Auth gate runs | YES (`_check_auth`) | YES (`enforceRouteAuth`) | YES (`route_auth_gate`) | YES (shared `enforceRouteAuth`) |
| Gate-vs-route-middleware order matches live | YES | YES | YES | NO (inverted, ADR-0012) |
| Verbs | get/post/put/patch/delete | same | same | same |
| Cookie jar / session replay | NO | NO | NO | NO |
| Dogfooding | WIDE (16 modules) | narrow (2/318) | wide (~13/266) + live-socket oracle | light (6/281) |

- Python, PHP, and Ruby each route through the REAL dispatch entry point. Python's `_dispatch` imports and
  drives `core.server.app` - the identical callable uvicorn/hypercorn/the dev server invoke - so `handle()`
  walks every stage (`_PRE_MATCH` -> `_POST_MATCH` with the auth gate -> `_FALLBACK` -> `_RESPONSE`),
  including session start/save. PHP funnels through `Router::dispatch`, the universal front controller the
  built-in server and `App` also use. Ruby calls `RackApp#call` on `RackApp.current` (or a lazily-built
  one), walking the real `REQUEST_STAGES`/`ROUTE_STAGES`. In all three, NO stage is bypassed, and the old
  shortcut (calling `Router.match` directly and fabricating a 404) was deliberately removed and is regressed
  against.
- Node is the outlier. Its TestClient builds a disconnected socket to satisfy `IncomingMessage` and then
  RE-IMPLEMENTS the dispatch order rather than calling the server's `dispatchPipeline` stage-walker. It
  shares the real auth gate (`enforceRouteAuth`, the same function `server.ts` uses) - so Bearer-header and
  body-`formToken` auth ARE exercised - but it skips several stages the live server runs (see the findings).
- The response object is consistent: `{status, body, headers, contentType, json(), text()}`. None of the
  four has a cookie jar - a `Set-Cookie` is not replayed as a `Cookie` on the next call; multi-request
  session flows must thread the header manually.
- Dogfooding varies widely: Python (16 test modules) and Ruby (~13 spec files, plus a live-socket
  `Net::HTTP` oracle test that asserts the TestClient response equals a real socket request to the same app)
  lean on it heavily; PHP uses it in only its own 2 self-tests (the suite calls `Router::dispatch` directly
  elsewhere); Node uses it in 6 files.

## Public surface contract

`client.get/post/put/patch/delete(path, {headers, json, body})` -> a `TestResponse` with
`status/body/headers/contentType/json()/text()`. Contract: the request is dispatched through the real
pipeline, exercising routing, middleware, sessions, and the auth gate exactly as a live request would.

## Inputs and outputs

- Input: method, path, optional headers/json/body. Output: a `TestResponse` built from the real dispatch's
  status, headers, and body.

## Lifecycle and operation graph

1. Build the request (body bytes, content-type/length, query split, headers).
2. Construct the framework's request object and invoke the REAL dispatch entry point (Python/PHP/Ruby) or a
   re-implementation of it (Node).
3. Collect the response (status, headers, body) into a `TestResponse`.

## Configuration and precedence

- No configuration. The client uses the global router/app (or an injected one). The peer is hardcoded
  loopback (correct for the trusted-proxy tests that inject `X-Forwarded-For`).

## Failures, side effects and security

- No security surface (a test tool). The risk is FIDELITY: a client that skips a stage lets a test pass
  that the live server would fail. Node's re-implementation realises that risk (session-auth unreachable;
  gate/middleware order inverted). Python's header-dict collapse loses duplicate headers. See the register.

## Wire and persistence contract

No persisted state. The response contract is `{status, headers, body}`; the fidelity contract is "same
stages as the live server".

## Providers and substitutability

No provider abstraction. The only substitution is the injected router/app.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| TC-NODE-REIMPL | Node's TestClient RE-IMPLEMENTS dispatch instead of calling the server's `dispatchPipeline` stage-walker, and skips stages the live server runs: (a) the SESSION stage - `sessionAutoStart` is never called and `req.session` is never attached, so the auth gate's session-token path is STRUCTURALLY UNREACHABLE and session-auth regressions cannot be caught; (b) the gate-vs-route-middleware ORDER is inverted (route middleware before the gate; live is gate before middleware, ADR-0012), so the client runs middleware on a request the live server would already have 401'd; (c) the global-middleware pre/post-match partition, template-route rendering, and static/landing fallbacks are not reproduced. Python/PHP/Ruby have none of these - they call the real front controller. | Make Node's TestClient call the server's real dispatch (the `dispatchPipeline` stage-walker) the way Python/PHP/Ruby call `app()`/`Router::dispatch`/`RackApp#call`, so no stage is skipped and the order matches. At minimum, run the session stage and fix the gate/middleware order. |
| TC-HEADER-COLLAPSE | Python's `TestResponse` collapses the ASGI header LIST into a last-wins DICT, so multiple same-name response headers (e.g. two `Set-Cookie`, or `Vary`) reduce to only the LAST value - a test cannot assert on more than one. (Confirm the PHP/Ruby/Node response objects preserve duplicates.) | Preserve the raw header list (or a multi-map) on `TestResponse` so duplicate headers are assertable; verify parity across the four. |
| TC-NO-COOKIE-JAR | None of the four has a cookie jar: a `Set-Cookie` from one response is not replayed as a `Cookie` on the next call, so a login-then-authenticated-request flow must thread the cookie by hand. Combined with TC-HEADER-COLLAPSE (Python), even reading multiple issued cookies is lossy. | Optional: add an opt-in cookie jar (carry `Set-Cookie` into subsequent requests) so stateful session/CSRF flows are testable without manual threading. |
| TC-DOGFOOD-THIN | PHP uses the TestClient only in its own 2 self-tests (2/318) while the suite exercises the pipeline via `Router::dispatch` directly; Node uses it in 6/281. So the client's fidelity is under-relied-upon exactly where it would catch pipeline regressions. | Increase dogfooding (route real request-path tests through the TestClient) so the client is the tested path, not a bypassed convenience - especially after TC-NODE-REIMPL is fixed. |

## Owner decisions

- TC-DEC-01 (proposed): make Node's TestClient dispatch through the real pipeline (TC-NODE-REIMPL) - the
  highest-value fix, since a low-fidelity client silently weakens every test that uses it.
- TC-DEC-02 (proposed): preserve duplicate headers on `TestResponse` (TC-HEADER-COLLAPSE) and confirm parity;
  optionally add a cookie jar (TC-NO-COOKIE-JAR).

## Proposed conformance fixture

A shared per-language test (Ruby's live-socket oracle is the model): assert the TestClient response for a
route EQUALS a real socket request to the same app (status, body, headers) - this alone would have caught
Node's stage skips. Plus: a secured route with attached middleware returns 401 via the TestClient WITHOUT
running that middleware (locks the gate-before-middleware order); a session-cookie login then an
authenticated request succeeds via the TestClient (locks the session stage + would need TC-NO-COOKIE-JAR or
manual threading); a response with two `Set-Cookie` headers exposes both (locks TC-HEADER-COLLAPSE).

## Integration map

- Dispatch entry: `core.server.app` (Python) / `Router::dispatch` (PHP) / `RackApp#call` (Ruby) / a
  re-implementation (Node).
- Consumers: the framework test suites, the scaffolded gate tests from `generate`, and the xUnit
  inline-testing class (feature 132) which delegates its HTTP to this client.

## Breaking changes and migration

- Fixing Node's client to use the real pipeline changes some test outcomes (a middleware that used to run on
  a would-be-401 request no longer does) - that is the correctness fix; document it. Preserving duplicate
  headers and adding a cookie jar are additive.

## Implementation backlog

1. TC-DEC-01: route Node's TestClient through the real dispatch (session stage + gate/middleware order +
   template/static/fallback), with the oracle test.
2. TC-DEC-02: preserve duplicate headers (all four), confirm parity; optional cookie jar.
3. TC-DOGFOOD-THIN: raise PHP/Node dogfooding once the client is high-fidelity.

## Porting capsule

A clean-room reimplementation must dispatch through the framework's REAL entry point (the same callable the
live server invokes) - never a parallel re-implementation of the dispatch order - so every stage (session,
CORS, rate-limit, global + per-route middleware, the auth gate IN THE LIVE ORDER, template rendering,
fallbacks, HEAD-strip) runs exactly as in production. Expose `get/post/put/patch/delete` returning
`{status, headers (duplicates preserved), body, json(), text()}`; consider a cookie jar for stateful flows.
Prove fidelity with a live-socket oracle test that asserts the in-process response equals a real socket
request to the same app - the one test that catches a skipped stage.

## Audit closure checklist

- [x] Boundary and public surface complete (verbs + response x four).
- [x] Lifecycle and every producer/consumer edge complete (build -> real dispatch -> collect).
- [x] Configuration, failure (fidelity), side-effect and security rules complete.
- [x] Wire/storage (response contract) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (Node re-implementation, Python header collapse,
  dogfooding spread).
- [x] Owner ambiguities decided and recorded (TC-DEC-01/02 proposed).
- [x] Proposed conformance fixture (oracle, order, session, duplicate headers) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
