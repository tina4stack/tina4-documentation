# Feature 42: Configurable error pages

## Identity and status

- Matrix identity: 42 - Configurable error pages (custom 404/500/error responses; distinct from the dev
  overlay, feature 126)
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language source. The CWE-209 prod-no-leak guarantee HOLDS and is
  gated in all four (positive); the divergences are 403 rendering (4-way), the no-template fallback, and
  content negotiation (unimplemented). Python `core/server.py:590` (`46007c1`); PHP `Tina4/Router.php:2005`
  (`ab871934`); Ruby `lib/tina4/template.rb:36` (`f549923`); Node `packages/core/src/server.ts:445`
  (`1319cf3`).
- Dependencies: Frond (renders the template), the router (emits the codes), TINA4_DEBUG (overlay gate).
- Dependants: every error response.
- Existing ADRs: CWE-209 (no prod info leak).

- Catalog phase: Routing and middleware

## Why this feature exists

An error response should be a branded page an app can override, and a production 500 must NEVER leak the stack
trace. The audit questions: is prod safe, can an app override the pages, and is HTML-vs-JSON negotiated. Prod
is safe (gated), overrides work, but the 403 rendering splits four ways and content negotiation is
unimplemented.

## Existing implementation evidence

Measured, all four:

- The built-in template set is IDENTICAL (byte-for-byte): `302/401/403/404/500/502/503/base.twig`. The
  renderer resolves user `src/templates/errors/{code}.twig` -> framework template -> a fallback.
- PROD 500 = NO LEAK (CWE-209), gated in all four: `500.twig` guards the trace with `{% if error_message %}`,
  all four pass `error_message` EMPTY in production and render the stack overlay ONLY under `TINA4_DEBUG`; each
  has a named `router_error_event` test asserting no trace markers in the prod body + a request_id. POSITIVE.
- 403 rendering SPLITS four ways: Python emits JSON (`middleware.py:130`); PHP + Ruby render the HTML
  `403.twig` (`Router.php:1471`, `rack_app.rb:330`); Node sets a BARE 403 status with NO body
  (`middleware.ts:133`). `403.twig` ships in all four but is dead in Python + Node.
- The no-template FALLBACK: Python/PHP/Node fall back to JSON; Ruby falls back to a hardcoded HTML string
  (`template.rb:68`) and hardcodes `text/html`, so Ruby can NEVER emit a JSON error for 403/404/500.
- Which codes flow through the app-overridable template path DIFFERS: Python/Node 404+500; Ruby 403+404+500;
  PHP 403+404+405+500. 404 carries a request_id only in Python (500 request_id is all four).
- CONTENT NEGOTIATION (Accept -> JSON) is UNIMPLEMENTED in all four: no error path reads `Accept`; HTML-vs-JSON
  is decided by template presence, so a JSON API client gets an HTML 404/403/500 page.

## Public surface contract

An app overrides `src/templates/errors/{code}.twig`; production errors are generic (no leak); the dev overlay
shows the trace under `TINA4_DEBUG`. HTML-vs-JSON should follow the client's `Accept` (today it does not).

## Inputs and outputs

- Input: a status code + the request + `TINA4_DEBUG`. Output: the error page (HTML, or JSON on template-miss
  except Ruby), or the overlay in dev.

## Lifecycle and operation graph

1. An error/miss produces a code. 2. The renderer tries the user template, then the framework template, then
a fallback. 3. 500 in dev -> overlay; in prod -> generic (empty `error_message`).

## Configuration and precedence

- `TINA4_DEBUG` gates the overlay. Override via `src/templates/errors/{code}.twig` (Ruby also searches
  `templates`/`src/views`/`views`). No content-negotiation config.

## Failures, side effects and security

- SECURITY: the prod 500 NEVER leaks the stack/message (CWE-209), verified + gated in all four - a strength.
  The residual issues are consistency (403 split, JSON-vs-HTML) not leakage. See the register.

## Wire and persistence contract

The error page body + status. No persisted state. The prod-500 body carries a generic page + request_id and
NO trace (the gated contract).

## Providers and substitutability

A future runtime must keep the CWE-209 guarantee, render a consistent 403, support content negotiation, and
allow the same override convention.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| ERR-403-SPLIT | The 403 (forbidden) rendering SPLITS four ways for the same scenario: Python JSON (`middleware.py:130`), PHP + Ruby the HTML `403.twig` (`Router.php:1471`, `rack_app.rb:330`), Node a BARE 403 status with NO body (`middleware.ts:133`). `403.twig` ships in all four but is dead in Python + Node. A client gets four different bodies. | Converge the 403 rendering (use the `403.twig` template consistently, or JSON consistently) across the four. |
| ERR-NO-CONTENT-NEGOTIATION | UNIVERSAL: no error path reads `Accept` in any language - HTML-vs-JSON is decided by TEMPLATE PRESENCE, so a JSON API client (`Accept: application/json`) gets an HTML 404/403/500 page; Ruby can NEVER emit a JSON error for 403/404/500. The stub's "JSON by content negotiation" is aspirational. | Implement Accept-based negotiation (JSON body for a JSON request, HTML for a browser) in all four, or drop the negotiation claim. |
| ERR-OVERRIDABLE-CODES-DIVERGE | Which status codes flow through the app-overridable template path DIFFERS: Python/Node 404+500; Ruby 403/404/500; PHP 403/404/405/500. So an app shipping `src/templates/errors/403.twig` sees it used in PHP/Ruby, ignored in Python/Node. | Agree which codes are app-overridable and route them through the renderer consistently in all four. |
| ERR-RUBY-FALLBACK-HTML | Ruby's no-template fallback is a HARDCODED HTML string (`template.rb:68`) and it hardcodes `text/html`, so Ruby can NEVER return a JSON error body for 403/404/500; the other three fall back to JSON. Ruby also searches 4 override roots (`templates`/`src/templates`/`src/views`/`views`) vs `src/templates/errors` only. | Align Ruby's fallback + content-type with the others (or with the ERR-NO-CONTENT-NEGOTIATION decision). |
| ERR-404-REQUESTID | The 404 carries a request_id only in Python (`server.py:2004`); PHP/Ruby/Node do not (the 500 request_id is present in all four). A correlation-parity gap on the 404. | Add a request_id to the 404 in PHP/Ruby/Node (with feature 43). |
| ERR-OVERRIDE-UNTESTED | No test asserts that a custom app `errors/{code}.twig` OVERRIDES the built-in, in any language (the override path is exercised only incidentally by landing-page specs). | Add a test that a custom 404/500 template is used over the built-in, in all four. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- ERR-DEC-01 (proposed): converge the 403 rendering (ERR-403-SPLIT), the app-overridable code-set
  (ERR-OVERRIDABLE-CODES-DIVERGE), and Ruby's HTML-only fallback (ERR-RUBY-FALLBACK-HTML) so an error response
  is consistent across the four.
- ERR-DEC-02 (proposed): implement Accept-based content negotiation (ERR-NO-CONTENT-NEGOTIATION) or drop the
  claim; add the 404 request_id (ERR-404-REQUESTID) and the override test (ERR-OVERRIDE-UNTESTED). Note the
  CWE-209 prod-no-leak guarantee is verified + gated - do NOT re-open it.

## Proposed conformance fixture

A shared fixture (real requests): a production 500 body has NO stack/message + a request_id (the gated CWE-209
guarantee); a 403 renders the SAME way in all four (catches ERR-403-SPLIT); `Accept: application/json` on a
404/500 yields a JSON body (after ERR-DEC-02); a custom `errors/404.twig` overrides the built-in.

## Integration map

- Consumers: every error response. Composes: Frond (renders), the router (emits codes), `TINA4_DEBUG` (the
  overlay, feature 126), the request-id (43).

## Breaking changes and migration

- Converging the 403 rendering changes what a 403 returns in Python/Node (JSON/bare -> the agreed form) - a
  consistency change; note it. Adding content negotiation changes error bodies for JSON clients - additive.

## Porting capsule

Render an error as a branded page an app can OVERRIDE at `src/templates/errors/{code}.twig`, falling back to a
framework template. NEVER leak the stack/message in a production 500 (guard the trace on `TINA4_DEBUG`; pass an
empty message - the CWE-209 guarantee to keep). Render the SAME 403 in all languages (not JSON here, HTML
there, bare-status elsewhere). Negotiate HTML-vs-JSON on the `Accept` header (a JSON client gets a JSON error).
Carry a request_id on the 404 and 500.

## Audit closure checklist

- [x] Boundary and public surface complete (error renderer + overrides x four).
- [x] Lifecycle and producer/consumer edges complete (code -> template -> fallback).
- [x] Configuration, failure and SECURITY (CWE-209 no-leak, verified) rules complete.
- [x] Wire (error body + status) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (no leak all four; 403 split; no negotiation).
- [x] Owner ambiguities decided (ERR-DEC-01 converge 403/codes, ERR-DEC-02 negotiation/tests).
- [x] Conformance fixture (no-leak + 403 + negotiation) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
