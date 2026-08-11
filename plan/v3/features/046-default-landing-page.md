# Feature 46: Default landing page

## Identity and status

- Matrix identity: 46 - Default landing page (the built-in welcome page at `/` when no user route matches)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc that left
  production behaviour unverified and RECOMMENDED allowing the page in production - the OPPOSITE of shipped
  code, which is DEV-ONLY, 404 in prod, and test-gated). Python `core/server.py:2001` `_handle_no_route`
  (`ebbab30`); PHP `Tina4/App.php:632` `registerLandingPage` (`6faabac5`); Ruby `lib/tina4/rack_app.rb:342`
  `handle_404` (`6d5b1de`); Node `packages/core/src/server.ts:1362` `serveLandingPage` (`27cf0f4`).
- Dependencies: the router (fallback ordering), `TINA4_DEBUG`, the response builder.
- Dependants: first-run developer experience.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

A fresh app should show a branded welcome page at `/` so a developer sees the framework is running - but that
page carries the framework version, a `/__dev` admin link, and a gallery, so it must NEVER appear in
production. The audit question (production behaviour) is already decided and shipped: DEV-ONLY, 404 in prod.

## Existing implementation evidence

- DEV-ONLY, 404 in production, in all four (gated on `TINA4_DEBUG`): Python `server.py:2001` `elif
  request.path == "/" and _is_dev_mode()`; PHP `App.php:877` `if (!$this->isDevelopment()) return;` (the
  route is not even registered in prod); Ruby `rack_app.rb:342` `render_landing_page if path == "/" &&
  dev_mode?`; Node `server.ts:1364` `if (ctx.pathname !== "/" || !isDevMode()) return false`. Each source
  comment states the reason: the version/dev-admin/gallery must not leak to real users.
- A user-defined `/` route ALWAYS wins in all four.
- MECHANISM DIVERGES: PHP REGISTERS a route during bootstrap (`App.php:632`); Python/Ruby/Node serve from a
  request-time fallback (no-route / 404 / FALLBACK_STAGES) - not a registration.
- Content is self-contained HTML (branded title `Tina4Python`/`Tina4Php`/`Tina4Ruby`/`Tina4NodeJs`, version,
  gallery), no external CDN asset. Status 200, `text/html`.
- Prod-hide is proven by a REAL end-to-end `GET /` test only in Ruby (`landing_page_spec.rb:214`) and Node
  (`landingPage.test.ts:331`); Python and PHP test only the dev-mode FLAG helper, not the `/` response.

## Public surface contract

In DEV, a GET `/` with no user `/` route returns the branded welcome page (200). In PRODUCTION, the same GET
returns 404. A user `/` route always takes precedence.

## Inputs and outputs

- Input: GET `/`, `TINA4_DEBUG`. Output: the welcome page (dev) or 404 (prod).

## Lifecycle and operation graph

1. Routing misses `/`. 2. (PHP) a bootstrap-registered route (dev only) renders it; (Python/Ruby/Node) a
   request-time fallback renders it IF dev-mode, else falls through to 404.

## Configuration and precedence

- `TINA4_DEBUG` gates it (dev-only). A user `/` route wins. PHP additionally suppresses it when a
  `src/templates/pages/index.*` exists; Python/Node run a template fallback first; Ruby's equivalent
  index-template check is dead code (see the register).

## Failures, side effects and security

- SECURITY (why dev-only matters): in DEV the page exposes the framework version, a `/__dev` admin link, and
  the gallery. This is correctly gated behind `TINA4_DEBUG`, so production (404) leaks nothing. The prior
  doc's recommendation to "allow it in production" would REINTRODUCE this fingerprinting leak - reject it.

## Wire and persistence contract

A self-contained HTML page at `/` with a 200 in DEV; a 404 in production. No persisted state.

## Providers and substitutability

Presentation-level. A future runtime must keep the page DEV-ONLY (404 in prod), let a user `/` route win, and
avoid any external asset load.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| LAND-PROD-DECIDED | The prior doc left production behaviour unverified (its LP-02 cell) and Owner-decision #2 RECOMMENDED "allow it in production". GROUND TRUTH: the page is DEV-ONLY, 404 in production, in all four, and the source comments cite avoiding a version/dev-admin/gallery leak as the reason. So it is decided, shipped, AND test-gated - and the prior recommendation is a regression + info-leak. | Ratify DEV-ONLY (the shipped behaviour); explicitly REJECT "allow in production". Correct LP-02. |
| LAND-MECHANISM-DIVERGE | The prior doc described a bootstrap ROUTE REGISTRATION as the uniform mechanism; only PHP registers (`App.php:632`). Python (`server.py:1979` no-route), Ruby (`rack_app.rb:334` 404), and Node (`server.ts:1362` fallback) serve from a request-time fallback, not a registration. Observable behaviour converges; the mechanism does not. | Document both mechanisms; decide whether to converge on one (low priority - behaviour already matches). |
| LAND-TEST-PARITY | Prod-hide is proven by a REAL end-to-end `GET /` (200 dev / 404 prod) only in Ruby (`landing_page_spec.rb:214`) and Node (`landingPage.test.ts:331`). Python (`test_landing_page.py`) and PHP (`LandingPageTest.php`) assert only the dev-mode FLAG helper (`_is_dev_mode()` / `DotEnv::isTruthy`), not the actual `/` response - so the shipped 404-in-prod is end-to-end-gated in only 2 of 4. | Add an end-to-end `GET /` test (200 dev, 404 prod, no banner) to Python and PHP. |
| LAND-SUPPRESS-DIVERGE | Suppression conditions differ: PHP suppresses on an existing GET `/` route AND a `src/templates/pages/index.*` template (`App.php:855-872`); Python/Node run a template fallback before the landing; Ruby's index-template check `should_show_landing_page?` (`rack_app.rb:357`) is DEAD CODE (unreferenced in the main checkout), so Ruby lacks the pages-index suppression the others have. | Unify the suppression conditions across the four (and fix Ruby's dead check). |
| LAND-DEADCODE | Node's `renderLandingPage(routes, port)` never references `routes` (`server.ts:657`) yet the caller builds `ctx.router.getRoutes().map(...)` every request and passes it (`:1366-1372`) - wasted work (NOT a routes leak; the list never reaches the page). Ruby's `should_show_landing_page?` (`:357`) and `try_serve_index_template` (`:434`) are unreferenced in the main checkout. | Delete the dead param/work (Node) and the unreferenced methods (Ruby). |
| LAND-NO-FIXTURE | No shared `landing_page_contract.json` exists. | Add it (dev shows / prod 404 / user-route-wins). |

## Owner decisions

- LAND-DEC-01 (proposed): RATIFY dev-only (LAND-PROD-DECIDED) - the code already does this and it prevents a
  production fingerprinting leak; explicitly REJECT the prior doc's "allow in production" recommendation. Add
  the end-to-end `GET /` test to Python and PHP (LAND-TEST-PARITY) so the 404-in-prod is gated in all four.
- LAND-DEC-02 (proposed, low): unify the suppression conditions (LAND-SUPPRESS-DIVERGE, incl. Ruby's dead
  index check), delete the dead code (LAND-DEADCODE), and optionally converge the mechanism
  (LAND-MECHANISM-DIVERGE).

## Proposed conformance fixture

A shared fixture (real `GET /`): dev-mode with no user `/` route -> 200 + the branded banner; production ->
404 + NO banner/version/dev-admin link (catches the info-leak and LAND-PROD-DECIDED); a user `/` route wins in
both modes.

## Integration map

- Consumers: first-run developers. Composes: the router fallback ordering, `TINA4_DEBUG`, the response
  builder, the template fallback (a `pages/index.*` beats the landing).

## Breaking changes and migration

- None to the shipped behaviour (it is already correct). Deleting the dead code is internal. Adding the
  end-to-end tests is additive.

## Porting capsule

Serve a branded welcome page at `/` ONLY in dev (`TINA4_DEBUG`) and ONLY when the app has no `/` route (a user
route wins) and no `pages/index.*` template; in production return 404 so the framework version, the dev-admin
link, and the gallery never leak. Keep the page self-contained (no external asset). Prove it with a real `GET
/`: 200 + banner in dev, 404 + no banner in prod.

## Audit closure checklist

- [x] Boundary and public surface complete (dev-only page + user-route precedence x four).
- [x] Lifecycle and producer/consumer edges complete (route-miss -> dev-gate -> render/404).
- [x] Configuration (TINA4_DEBUG), failure and SECURITY (prod info-leak) rules complete.
- [x] Wire (200 dev / 404 prod) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (dev-only all four; mechanism diverges) - correcting the
  prior unverified + the reversed prod recommendation.
- [x] Owner ambiguities decided (LAND-DEC-01 ratify dev-only, LAND-DEC-02 cleanup).
- [x] Conformance fixture (dev 200 / prod 404) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
