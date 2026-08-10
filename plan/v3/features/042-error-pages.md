# Feature 042: Configurable error pages

## Identity and status

- Matrix identity: 42 - Configurable error pages
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (`renderError` and the debug/
  production split in each router/server). No framework code changed.
- Dependencies: Feature 31 router (raises the 404/405/500), Feature 30 response model, Frond
  (renders the error template), Feature 2 (`TINA4_DEBUG` governs the debug/production split),
  Feature 43 (the request id in a production error)
- Dependants: every unmatched path, forbidden request, wrong method or handler exception; an
  application shipping custom error templates; error reporters (Sentry)
- Existing ADRs: the production/development split (Feature 2); the response-model contract
  (ADR-0050)
- Shared fixtures: `error_pages_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

When a request 404s, hits a forbidden route, uses the wrong method, or a handler throws, the
framework returns a clean, optionally app-branded error page - and CRUCIALLY, it shows a
developer the stack trace in debug mode but NEVER leaks it in production. This is the same
contract in all four languages.

## Boundary

This feature owns `renderError` (code, message, path): the error-page render for 403/404/405/500,
the user-template override, the JSON fallback, the debug-overlay-versus-production split, and the
error-reporter isolation. It DELEGATES the template render to Frond, the response to Feature 30,
the debug signal to `TINA4_DEBUG` (Feature 2), and the request id to Feature 43.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Entry | render error | `renderError($response, $code, $message, $path)` | render error | render error |
| Codes | 403/404/405/500 | 403/404/405/500 | same | same |
| User template override | yes (app ships one) | yes ("a user template if the app ships one") | yes | built-in templates dir + override |
| Fallback | JSON | Frond template then JSON | JSON | JSON |
| Debug mode | rich overlay (stack trace) | `ErrorOverlay::renderErrorOverlay` | overlay | overlay |
| Production body | generic page + request id, NO stack trace | same (CWE-209 comment) | same | same |
| Reporters (Sentry) | before render, isolated | before render, isolated | isolated | isolated |
| Governed by | `TINA4_DEBUG` | `TINA4_DEBUG` | `TINA4_DEBUG` | `TINA4_DEBUG` |

The error-page system is converged and the source calls it "the same contract across all four
frameworks." Every error (403/404/405/500) renders through one `renderError` path: it uses the
app's Frond template if one is shipped, falls back to the built-in template, and falls back
again to JSON for a non-HTML client. Under `TINA4_DEBUG` it renders a rich overlay carrying the
exception and stack trace; in production it renders a generic page plus a request id, and the
PHP source states the security rule outright (CWE-209): the production body must NOT carry the
stack trace. Error reporters fire BEFORE the render and are isolated so a broken reporter cannot
break the error page.

## Public surface contract

`renderError(code, message, path)` produces an error response for 403/404/405/500. It renders
the app's Frond error template if present, else the built-in template, else JSON for a non-HTML
client. In debug mode it includes the exception overlay (stack trace); in production it includes
a generic message and a request id and NEVER the stack trace. An error reporter registered by
the app runs before the render and cannot break it.

## Inputs and outputs

- Input: the status code, a message, the request path, the `TINA4_DEBUG` signal, and any app
  error template or registered reporter.
- Output: an HTML error page (app template, else built-in) or a JSON error body, with the
  correct status code.
- In debug: the body carries the exception and stack trace. In production: the body carries a
  generic message and a request id, and no stack trace, path internals or class names that leak
  implementation.
- The request id in production correlates the response to the server log (Feature 43).

## Lifecycle and operation graph

1. The router raises an error (404 unmatched, 403 forbidden, 405 wrong method, or 500 from a
   thrown handler).
2. Registered error reporters fire FIRST, each isolated so a failing reporter (or a log failure)
   cannot block or corrupt the error render.
3. `renderError` selects the body: the app's Frond template, else the built-in, else JSON by
   content negotiation.
4. If `TINA4_DEBUG` is on, the debug overlay (exception + stack trace) renders; otherwise the
   generic production page renders with a request id and no stack trace.
5. The response is sent with the error status code.

## Configuration and precedence

- `TINA4_DEBUG` governs the split: on -> overlay with stack trace; off -> generic page, request
  id, no trace. Same across all four (Feature 2).
- An app error template overrides the built-in; the built-in overrides the JSON fallback; a
  non-HTML client (Accept: application/json) gets JSON regardless.
- Error reporters are registered by the app and run before the render.

## Failures, side effects and security

- SECURITY (CWE-209): the production error body MUST NOT carry the stack trace, exception class,
  or internal paths. Leaking them is the exact vulnerability this split prevents; a production
  page shows a generic message and a request id only.
- A broken error reporter or a log failure must NEVER break the error render; reporters are
  isolated and run before the render.
- The error page itself must not throw: a template failure falls back to the built-in, then to
  JSON, so an error never becomes a blank 200 or an unhandled second exception.
- The debug overlay is only rendered when `TINA4_DEBUG` is on, so a misconfigured production
  server that forgot to disable debug is the risk the audit's fixture must catch.

## Wire and persistence contract

There is no persistence; the wire contract is the error status code, the body (HTML template or
JSON), and - in production - the presence of a request id and the ABSENCE of a stack trace. The
JSON error shape follows the response model (ADR-0050). These are identical across the four for
the same error and the same `TINA4_DEBUG` state.

## Providers and substitutability

Error rendering is engine-agnostic. A future runtime renders the same 403/404/405/500 through the
same template-then-JSON fallback, the same debug/production split with the CWE-209 guarantee, and
the same reporter isolation.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| ERR-01 | The CWE-209 production guarantee (no stack trace) is stated in PHP but not gated as parity; a leak in one language is a real vulnerability. | Gate that a production 500 body carries NO stack trace/class/internal path in ALL four, and that a debug 500 DOES. |
| ERR-02 | The fallback chain (app template -> built-in -> JSON) is converged but not gated. | Gate the override, the built-in, and the JSON fallback in all four. |
| ERR-03 | The code set (403/404/405/500) and the per-code message are not gated as parity. | Gate each code rendering the right page/status in all four. |
| ERR-04 | Content negotiation (HTML vs JSON by Accept) is not gated. | Gate that an `Accept: application/json` client gets JSON and a browser gets HTML. |
| ERR-05 | Reporter isolation (a broken reporter cannot break the render) is not gated. | Gate that a throwing reporter still yields the error page in all four. |
| ERR-06 | The production request id (correlation) ties to Feature 43 but is not gated here. | Gate that a production error carries a request id in all four. |
| ERR-07 | No shared fixture exists. | Add `error_pages_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The debug/production split is governed by `TINA4_DEBUG` and the CWE-209 guarantee is
   absolute: a production error body carries a generic message and a request id and NEVER a
   stack trace, exception class, or internal path. Debug shows the full overlay. Identical in
   all four.
2. The fallback chain is app Frond template -> built-in template -> JSON (by content
   negotiation), identical in all four.
3. `renderError` handles 403/404/405/500 with the correct status and message.
4. Error reporters run before the render and are isolated; a broken reporter or a log failure
   never breaks the error page.
5. A production error carries a request id (Feature 43) for log correlation.

## Proposed conformance fixture

Add `error_pages_contract.json` with stable ids for: each of 403/404/405/500 rendering the right
status and page; a production 500 body containing NO stack trace/class/path and a debug 500
containing the overlay; an app template overriding the built-in; a JSON body for
`Accept: application/json`; a throwing error reporter still yielding the error page; and a
production error carrying a request id. Every case runs a real error through the real router; no
mock can claim conformance (the CWE-209 guarantee must be proven on real rendered output).

## Integration map

- Feature 31 raises the errors; Frond renders the template; Feature 2's `TINA4_DEBUG` gates the
  split; Feature 43 supplies the request id; error reporters are the app's.
- The JSON fallback follows the response model (ADR-0050).
- Central fixtures, four runners, the CI matrix and the error/deployment docs update together.

## Breaking changes and migration

- No change to application code; the audit gates the CWE-209 guarantee and the fallback chain.
  If any language is found leaking a stack trace in production under test, closing it is a
  security fix, noted in the release note.
- An app shipping a custom error template keeps it (override preserved).

## Implementation backlog

1. Add `error_pages_contract.json` and wire four runners against real errors.
2. Gate the CWE-209 production no-trace guarantee and the debug overlay (ERR-01) in all four.
3. Gate the fallback chain (ERR-02), the code set (ERR-03), content negotiation (ERR-04),
   reporter isolation (ERR-05) and the production request id (ERR-06).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `renderError(code, message, path)` for 403/404/405/500. Render the app's Frond error
template if present, else the built-in, else JSON by content negotiation. Gate on `TINA4_DEBUG`:
on -> a full overlay with the exception and stack trace; off -> a generic page with a request id
and NEVER a stack trace, class or internal path (CWE-209). Run error reporters before the render,
isolated so one cannot break the page, and never let the error render throw (fall back down the
chain). Prove the port with a production-no-trace case, a debug-overlay case, a JSON case, and a
throwing-reporter case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (ERR-01..07).
- [x] Owner ambiguities recorded (5 proposed; the CWE-209 production guarantee is the key one).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
