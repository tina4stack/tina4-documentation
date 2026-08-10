# Feature 045: Swagger and OpenAPI

## Identity and status

- Matrix identity: 45 - Swagger and OpenAPI
- Audit state: decision-ready
- Audit note: cross-framework audit 2026-06-22 (P1 security/exposure cluster + spec-validity
  shipped 3.13.40; configurability shipped 3.13.42); reopened as a standalone 3.14 audit to
  consolidate the contract and gate it. Measured against source 2026-08-10. No framework code
  changed here.
- Dependencies: Feature 1 configuration (the `TINA4_SWAGGER_*` vars), Feature 30 responses,
  Feature 31 routes (the metadata the doc is generated from), Feature 41 static (serves the UI)
- Dependants: any API consumer reading the OpenAPI doc; the Swagger UI; codegen tooling
- Existing ADRs: the routing-surface metadata (Feature 31); the production/development split
  (Feature 2)
- Shared fixtures: `swagger_contract.json` is required (the Layer-2 contract map, ~10 invariants)
- Catalog phase: Routing and middleware

## Why this feature exists

An engineer needs one generated API contract and one optional Swagger UI that describe the
routes the application will dispatch - and CRUCIALLY, that contract must NOT expose the full API
surface (including secured routes) on a production server that did not opt in.

## Boundary

This feature owns OpenAPI document generation (paths, params, per-op summary/tags/responses,
`components.schemas` and `securitySchemes`), the configured description, and the
enable/serve policy for the Swagger UI and the raw spec. Routes belong to Feature 31 and
response delivery to Feature 30. The UI assets are served through Feature 41 (static), gated by
the same policy.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| OpenAPI skeleton | 3.0.3 (opt 3.1) | 3.0.3 (opt 3.1) | 3.0.3 | 3.0.3 |
| Serve `/swagger` + `/swagger/openapi.json` | yes | yes | yes | yes |
| Production gate (`TINA4_SWAGGER_ENABLED`) | DEAD before fix (gated only on TINA4_DEBUG) | wired (`isEnabled` gates register) | DEAD before fix | wired (`swaggerEnabled` short-circuits) |
| `components.securitySchemes` + per-op `security` | yes | yes | yes | NONE before fix |
| `->noAuth()` respected in the spec | yes | re-derived WRONG (read `noAuth`, not `auth_required`) | yes | yes |
| Multi-status responses | collapse to 200 before fix | yes | yes | yes |
| Spec validity | bare `*` wildcard (invalid) | `ws` method leak + operationId collisions | `*`/`path` param (invalid) | empty `{}` schema, wrong model inference |
| Swagger UI assets | swagger-ui-dist@5 from a public CDN (offline blank) | same | same | same |

The 2026-06-22 audit (28-agent workflow, 23 findings all adversarially confirmed) found that all
four emit a syntactically clean OpenAPI 3.0.3 skeleton but diverged badly on the parts that
matter. The P1 cluster (below) shipped fixes in 3.13.40; configurability (security schemes,
scopes, path filter, OpenAPI 3.1, custom schemas, 7 new `TINA4_SWAGGER_*` vars) shipped 3.13.42.
The standalone 3.14 audit re-verifies those fixes hold and gates them with the Layer-2 contract
map so they cannot silently regress.

## Public surface contract

The framework generates an OpenAPI 3.0.3 (or 3.1, opt-in via `TINA4_SWAGGER_OPENAPI`) document
from the route metadata and serves it at `/swagger/openapi.json`, with a Swagger UI at
`/swagger`. `addSecurityScheme` registers a named scheme (bearerAuth, oauth2) merged into
`components.securitySchemes`. Both the UI and the raw spec are served only when the Swagger gate
is on (`TINA4_SWAGGER_ENABLED`, defaulting off in production). A secured route is documented with
`security`; a `->noAuth()`/`@noauth` route is documented without it.

## Inputs and outputs

- Input: the registered routes and their metadata (summary, tags, params, responses, auth
  requirement), the registered security schemes and schemas, and the `TINA4_SWAGGER_*` config.
- Output: a validator-clean OpenAPI document (paths, path/query params, per-op summary/tags,
  multi-status responses, `components.schemas`/`securitySchemes`), and the Swagger UI - both
  served only when the gate is on.
- A secured route's operation carries `security`; a no-auth route's does not.
- The document is regenerated per request (not memoized stale across a hot reload).

## Lifecycle and operation graph

1. On a request to `/swagger` or `/swagger/openapi.json`, the gate is checked FIRST
   (`TINA4_SWAGGER_ENABLED`, honoring the production default); if off, the path is not served
   (and the static handler must not serve `/swagger` as a plain 200 either).
2. When on, the document is generated from the current routes: paths, params, responses,
   `components.schemas` (ORM-derived where available), `securitySchemes`, and per-op `security`
   read from the route's `auth_required` (not re-derived).
3. The document is emitted, validator-clean (no bare `*` path, no `ws` method, no operationId
   collision, no empty `{}` schema).
4. The Swagger UI is served (its assets from CDN today, a zero-dependency gap).

## Configuration and precedence

- `TINA4_SWAGGER_ENABLED` is the explicit on/off override; the default is OFF in production and
  on in dev (`TINA4_DEBUG`). This is the security gate.
- `TINA4_SWAGGER_OPENAPI` selects 3.0.3 (default) or 3.1.
- The other `TINA4_SWAGGER_*` vars (contact email, path filter, schemes/scopes) tune the
  document; the contact-email variable is `TINA4_SWAGGER_CONTACT_EMAIL` (the docs' `CONTACT_TEAM`/
  `CONTACT_URL` were drift).

## Failures, side effects and security

- SECURITY (P1): the production gate must be WIRED, not dead. Before the fix, Python and Ruby
  gated only on `TINA4_DEBUG` and never called `is_enabled()`/`enabled?`, so `/swagger` exposed
  the FULL API surface - including secured paths - unconditionally in production, and the env
  switch was dead. The gate must honor `TINA4_SWAGGER_ENABLED` in all four, and the static
  handler must not serve `/swagger` as a plain 200 when the gate is off (the two must agree).
- SECURITY: a secured route must be documented as secured (`security` + the scheme). Node emitted
  no `securitySchemes` at all, so "Try it out" fired unauthenticated and secured routes looked
  public.
- A `->noAuth()` route must be read from the route's `auth_required`, not re-derived from a
  missing `noAuth` key (the PHP bug documented every no-auth write route as secured).
- The document must be OpenAPI-VALID: a bare `*` wildcard path, a `ws` path-item method, an
  operationId collision, or an empty `{}` schema each make the whole doc invalid and break
  codegen.
- The UI loads `swagger-ui-dist@5` from a public CDN, so it is blank offline - a break of the
  zero-dependency claim to weigh (bundle vs CDN).

## Wire and persistence contract

There is no persistence; the wire contract is the OpenAPI JSON document (validator-clean 3.0.3
or 3.1) at `/swagger/openapi.json` and the UI at `/swagger`, both served only when the gate is
on. The document is regenerated per request. Its shape (paths, params, responses, components,
security) is identical across the four for the same routes.

## Providers and substitutability

The generator is zero-dependency (hand-rolled OpenAPI emission); only the UI pulls
`swagger-ui-dist` from a CDN. A future runtime generates the same document from its routes, wires
the same production gate, and emits the same security metadata.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SW-01 | The production gate was DEAD in Python and Ruby (gated only on `TINA4_DEBUG`), exposing the full API surface in prod; fixed in 3.13.40. | Gate that `/swagger` and `/swagger/openapi.json` are NOT served in production without `TINA4_SWAGGER_ENABLED`, in all four, and that the static handler agrees. |
| SW-02 | Node emitted no `securitySchemes`/per-op `security`; secured routes looked public; fixed. | Gate that a secured route carries `security` and the scheme in all four. |
| SW-03 | PHP re-derived `noAuth` from a missing key, documenting no-auth routes as secured; fix reads `auth_required`. | Gate that a `->noAuth()` route is documented WITHOUT security in all four. |
| SW-04 | Spec validity: bare `*` wildcard (Python/Ruby), `ws` method + operationId collision (PHP), empty schema + wrong model inference (Node) each invalidate the doc. | Gate the document validates against an OpenAPI validator in all four (no wildcard, no ws method, no collision, no empty schema). |
| SW-05 | Multi-status responses collapsed to 200 (Python); Ruby memoized the doc stale across hot reload. | Gate multi-status responses and per-request regeneration in all four. |
| SW-06 | The UI loads swagger-ui-dist from a public CDN (blank offline), breaking the zero-dep claim. | Decide: bundle the UI assets or document the CDN dependency; gate the offline behaviour. |
| SW-07 | No shared fixture (Layer-2 contract map) is materialized. | Add `swagger_contract.json` with the ~10 invariants. |

## Owner decisions

Proposed for owner ratification:

1. The production gate is `TINA4_SWAGGER_ENABLED`, default OFF in production, wired in ALL four
   (not dead), and the static handler agrees (no `/swagger` 200 when off). This is the security
   decision this row exists to lock.
2. A secured route is documented with `security` and the scheme; a `->noAuth()`/`@noauth` route
   without, read from `auth_required`, in all four.
3. The document is OpenAPI-valid (no bare wildcard, no `ws` method, no operationId collision, no
   empty schema) and regenerated per request (never memoized stale).
4. OpenAPI 3.0.3 is the default, 3.1 opt-in via `TINA4_SWAGGER_OPENAPI`; the contact variable is
   `TINA4_SWAGGER_CONTACT_EMAIL`.
5. The Swagger UI's CDN dependency is either bundled (restoring zero-dep/offline) or explicitly
   documented; the offline behaviour is gated.

## Proposed conformance fixture

Add `swagger_contract.json` (the Layer-2 contract map) with stable ids for: `/swagger` and
`/swagger/openapi.json` NOT served in production without `TINA4_SWAGGER_ENABLED` (and the static
handler agreeing); a secured route carrying `security`; a `->noAuth()` route carrying none; the
emitted document VALIDATING against an OpenAPI validator (no wildcard/ws/collision/empty-schema);
multi-status responses present; per-request regeneration after a route change; and `TINA4_SWAGGER_
OPENAPI` emitting 3.1. Every case generates a real document from real routes and validates it; no
mock can claim conformance (the security gate and the spec validity must be proven on real
output).

## Integration map

- Feature 31 supplies the route metadata and `auth_required`; Feature 41 serves the UI assets
  under the same gate; Feature 2's `TINA4_DEBUG` and `TINA4_SWAGGER_ENABLED` govern serving.
- Codegen and API consumers read `/swagger/openapi.json`; the doc's validity is their contract.
- Central fixtures, four runners, the CI matrix (which must run an OpenAPI validator) and the
  Swagger docs update together; the CLAUDE.md drift (contact vars) is corrected.

## Breaking changes and migration

- The P1 fixes already shipped (3.13.40/42); the 3.14 audit gates them so they cannot regress.
  No new application break; a production server that relied on `/swagger` being open must set
  `TINA4_SWAGGER_ENABLED=true` (a security correction, noted in the release note).
- Bundling the UI (if chosen) removes the CDN dependency; no application change.

## Implementation backlog

1. Materialize `swagger_contract.json` (the Layer-2 map) and wire four runners with an OpenAPI
   validator in CI.
2. Re-verify and gate the production gate (SW-01) and the static-handler agreement in all four.
3. Gate security schemes (SW-02), `noAuth` from `auth_required` (SW-03), spec validity (SW-04),
   and multi-status + per-request regeneration (SW-05).
4. Decide and gate the UI CDN/bundle question (SW-06); fix the CLAUDE.md contact-var drift.
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Generate an OpenAPI 3.0.3 (3.1 opt-in) document from the routes: paths, params, per-op
summary/tags/multi-status responses, `components.schemas` and `securitySchemes`, and per-op
`security` read from the route's `auth_required` (a no-auth route gets none). Serve it at
`/swagger/openapi.json` and a UI at `/swagger` ONLY when `TINA4_SWAGGER_ENABLED` is on (default
off in production), and make the static handler agree. Emit a validator-clean document (no bare
wildcard, no `ws` method, no operationId collision, no empty schema) and regenerate per request.
Prove the port with a production-gated-off case, a secured-vs-noauth pair, and an
OpenAPI-validator pass.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (SW-01..07, from the 2026-06-22 audit).
- [x] Owner ambiguities recorded (5 proposed; the production gate is the key security one).
- [x] Proposed shared cases and mutation witnesses complete (the Layer-2 map).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
