# Feature 45: Swagger / OpenAPI generator

## Identity and status

- Matrix identity: 45 - Swagger / OpenAPI generator (the spec + the /swagger UI)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source. The prior P1 SECURITY cluster is FIXED and
  regression-gated in all four (positive, no active defect); the residuals are a Node boot-snapshot + a
  latent Node /__feedback leak + ungated per-operation shape drift. Python `swagger/__init__.py:255`
  (`46007c1`); PHP `Tina4/Swagger.php:101` (`ab871934`); Ruby `lib/tina4/swagger.rb:130` (`f549923`); Node
  `packages/swagger/src/generator.ts:55` (`1319cf3`). Shared fixture: `plan/v3/fixtures/swagger_contract.json`
  (10 invariants, proven).
- Dependencies: the router (route table), the auth flag, Frond/the UI shell.
- Dependants: API consumers; the /swagger UI.
- Existing ADRs: the swagger contract fixture (P1 security).

- Catalog phase: Routing and middleware

## Why this feature exists

Swagger generates an OpenAPI spec from the routes and serves an interactive UI. The audit questions (after a
prior P1 security cluster): is the spec production-gated, does it emit a securityScheme, does it leak internal
routes, and is the shape at parity. The security contract is fixed + gated in all four; the residuals are
robustness (Node) and cosmetic shape drift.

## Existing implementation evidence

Measured, all four:

- OpenAPI `3.0.3` default, `3.1.0` opt-in via `TINA4_SWAGGER_OPENAPI` (parity). Routes discovered from the live
  router; path/query params, request bodies, and multi-status responses documented. `/swagger` (UI) +
  `/swagger/openapi.json` (spec) in all four.
- SECURITY (the prior P1 cluster) - FIXED + gated in all four: the production gate is WIRED
  (`TINA4_SWAGGER_ENABLED` wins, else `TINA4_DEBUG`, else off) and the static handler agrees (the bundled UI
  assets 404 when disabled); a `bearerAuth` `securityScheme` is always emitted; per-operation `security` reads
  the dispatch-enforced auth FLAG (a `noAuth`/`@noauth` route is documented public); the emitted document
  validates against a real OpenAPI validator. Proven by real no-mock contract suites + a static-gate suite in
  every language + the shared 10-invariant fixture. No active security defect.
- Node RESIDUALS: (a) the spec regenerates per request but over a BOOT-TIME route SNAPSHOT (`server.ts:1743`),
  so post-boot/hot-reloaded routes never appear (py/php/ruby re-read live routes); (b) `/__feedback/*` IS
  registered into the main router (`feedback.ts:260`) and kept out of the spec ONLY by boot ordering (swagger
  snapshots before `DevAdmin.register`), NOT by the exclusion list (`isIncludedPath` omits `/__feedback`) - a
  reorder would publish `POST /__feedback/api/turn`.
- SHAPE drift (ungated): Python (the master) emits NO `401` on a secured op; PHP/Ruby/Node do. Python omits
  `summary`/`tags` when undecorated; PHP/Ruby/Node always populate (Ruby always `description:""`). The internal
  exclusion rule is not shared (PHP carries 8 prefixes because it Router-registers `/ai`/`/rag`/etc; the others
  dispatch those outside the router, so `/swagger`+`/__dev` suffices). CDN default splits jsdelivr (py/ruby) vs
  unpkg (php/node), no SRI.

## Public surface contract

`/swagger` + `/swagger/openapi.json`, production-gated, with a securityScheme and per-op security from the real
auth flag, documenting only application routes. The security contract is met; the shape should also converge.

## Inputs and outputs

- Input: the route table + auth flags + env (`TINA4_SWAGGER_ENABLED`/`TINA4_DEBUG`/`TINA4_SWAGGER_OPENAPI`/
  `TINA4_SWAGGER_UI_CDN`). Output: the OpenAPI JSON + the UI.

## Lifecycle and operation graph

1. Enabled? (env gate). 2. Read the routes -> build the spec (params/bodies/responses/security). 3. Serve the
UI + spec, excluding internal routes.

## Configuration and precedence

- `TINA4_SWAGGER_ENABLED` (explicit) > `TINA4_DEBUG` > off. `TINA4_SWAGGER_OPENAPI` picks 3.0.3/3.1.0.
  `TINA4_SWAGGER_UI_CDN` overrides the UI CDN.

## Failures, side effects and security

- SECURITY: production-gated (spec + static assets 404 when disabled), a securityScheme emitted, no internal
  route leak on current code, no UI XSS from route data - all verified + gated. The residual Node
  boot-snapshot + `/__feedback` are robustness/fragility, not an active leak. See the register.

## Wire and persistence contract

The OpenAPI JSON (validated) + the UI HTML. The spec shape is structurally converged; per-operation shape
(401/summary/tags) is not gated.

## Providers and substitutability

A future runtime must production-gate the spec + assets, emit a securityScheme + real per-op security, exclude
internal routes by a SHARED rule, and regenerate from LIVE routes.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SWAG-NODE-BOOT-SNAPSHOT | Node regenerates the spec per request but over a BOOT-TIME route SNAPSHOT (`server.ts:1743` captures `router.getRoutes()` once); post-boot / hot-reloaded routes never appear. Python/PHP/Ruby re-read the LIVE routes per request. A per-request-freshness parity gap. | Regenerate Node's spec from the live route table per request (like the other three). |
| SWAG-NODE-FEEDBACK-LEAK | Node's `/__feedback/*` IS registered into the main router (`feedback.ts:260`) and is kept OUT of the spec ONLY by boot ordering (swagger snapshots at `server.ts:1743` before `DevAdmin.register` at `:1775`), NOT by the exclusion list (`isIncludedPath` `generator.ts:372` omits `/__feedback`). A reorder would publish `POST /__feedback/api/turn` as a secured route. Latent, not active. | Add `/__feedback` (and any non-`/__dev` internal Node registers into the router) to `isIncludedPath`; do not rely on boot ordering. |
| SWAG-EXCLUSION-NOT-SHARED | The internal-route exclusion rule is NOT shared: PHP carries 8 prefixes + a bare `/` (`Swagger.php:245`) because it Router-registers `/ai`/`/rag`/`/vision`/`/embed`/`/image`/`/__feedback`; Python/Ruby/Node use only `/swagger`+`/__dev` because they dispatch those internals OUTSIDE the router. Three different mechanisms achieve the same clean result; the fixture's goal is one shared rule. | Share ONE internal-exclusion rule (and register internals consistently) across the four. |
| SWAG-401-SHAPE | Python (the reference) emits NO `401 Unauthorized` on a secured operation; PHP/Ruby/Node each add one. So the master is the odd one out, and the per-op shape is ungated. | Decide whether a secured op documents a `401` (add to Python, or drop from the others); gate it. |
| SWAG-SHAPE-DRIFT | The per-operation object shape is ungated and drifts: Python omits `summary`/`tags` when undecorated, PHP/Ruby/Node always populate (Ruby always `description:""`); PHP alone adds a `requestBody.description`. Valid OpenAPI, but not identical. | Gate the per-op shape (summary/tags/description) in the contract fixture so the four agree. |
| SWAG-CDN-NO-SRI | The UI loads `swagger-ui-dist@5` from a public CDN with NO Subresource-Integrity hash, and the default CDN splits (jsdelivr for py/ruby, unpkg for php/node). Documented + `TINA4_SWAGGER_UI_CDN`-overridable, but a supply-chain + parity nit. | Pin one CDN default + add an SRI hash (or bundle the assets); low priority. |

## Owner decisions

- SWAG-DEC-01 (proposed): fix Node's boot-snapshot to regenerate from live routes (SWAG-NODE-BOOT-SNAPSHOT) and
  add `/__feedback` to Node's exclusion list (SWAG-NODE-FEEDBACK-LEAK) - the robustness/fragility gaps.
- SWAG-DEC-02 (proposed): share ONE internal-exclusion rule (SWAG-EXCLUSION-NOT-SHARED) and gate the per-op
  shape - the `401` (SWAG-401-SHAPE) and summary/tags (SWAG-SHAPE-DRIFT) - so the master and the ports agree;
  CDN/SRI (SWAG-CDN-NO-SRI) is cosmetic. Note: the P1 security cluster is FIXED + gated - do NOT re-open it.

## Proposed conformance fixture

The existing `swagger_contract.json` (10 invariants, proven: prod-gate, static-gate, securityScheme, per-op
security from the auth flag, valid document, no internal-route leak). Add: Node's spec reflects a route added
AFTER boot (catches SWAG-NODE-BOOT-SNAPSHOT); `/__feedback` is absent regardless of registration order (Node);
the per-op `401`/summary/tags shape is identical across the four.

## Integration map

- Consumers: API clients, the /swagger UI. Composes: the router (route table), the auth flag (per-op
  security), the dev-admin/feedback internals (excluded), Frond (the UI shell).

## Breaking changes and migration

- Gating the per-op shape may change the emitted spec for some ops (adding/removing a `401`) - a documented
  contract change. Fixing Node's snapshot changes which routes appear (post-boot routes now documented) - a
  correctness fix.

## Porting capsule

Generate the OpenAPI spec from the LIVE route table per request (never a boot snapshot - the Node gap),
production-GATE both the spec and the bundled UI assets (404 when disabled), emit a `bearerAuth`
securityScheme, and set per-operation `security` from the dispatch-enforced auth flag (a `noAuth` route is
public). Exclude internal routes by ONE shared rule (never rely on boot ordering - the Node `/__feedback`
fragility). Keep the per-op shape (401/summary/tags) identical across languages. The security contract is the
one to never regress; it is currently fixed and gated.

## Audit closure checklist

- [x] Boundary and public surface complete (spec + UI + gate x four).
- [x] Lifecycle and producer/consumer edges complete (gate -> read routes -> emit -> serve).
- [x] Configuration, failure and SECURITY (prod-gate, securityScheme, no-leak - verified) rules complete.
- [x] Wire (OpenAPI JSON) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (security fixed+gated; Node snapshot; shape drift).
- [x] Owner ambiguities decided (SWAG-DEC-01 Node robustness, SWAG-DEC-02 shared-rule/shape).
- [x] Conformance fixture (existing 10 invariants + snapshot/shape additions) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
