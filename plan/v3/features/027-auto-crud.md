# Feature 027: Automatic CRUD from models

## Identity and status

- Matrix identity: 27 - Automatic CRUD from models
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (Python `crud/__init__.py`, PHP
  `AutoCrud.php`, Ruby `tina4.rb` register logic, Node AutoCrud). No framework code changed.
- Dependencies: Feature 17 ORM base class (the models), Feature 24 pagination (the list
  envelope), the router (write-gating), Swagger (the generated routes are documented)
- Dependants: any application that exposes a model as a REST resource without hand-writing the
  routes; the Swagger doc; the dev-admin UI
- Existing ADRs: ADR-0043 (Accepted) governs the list endpoint's paginate envelope; the
  router's secure-by-default-writes rule (writes require a token unless opened)
- Shared fixtures: `autocrud_contract.json` is required (real routes over real SQLite)

## Why this feature exists

A developer points AutoCRUD at an ORM model and gets a full REST resource - list, read,
create, update, delete - without writing a single route, with writes locked behind auth by
default and the list already returning the canonical paginate envelope.

## Boundary

This feature owns model discovery and the generation of the five REST routes from a model:
`register(model, prefix, public)` and `discover(dir, public)`, the route handlers, and the
secure-by-default-writes posture. It DELEGATES the list envelope to Feature 24/ADR-0043, the
write-gating to the router, the model to Feature 17, and the route documentation to Swagger.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Register one model | `register(model, prefix="/api", public=False)` | `register($modelClass, $public=false)` | `register` (route logic in `tina4.rb`) | `AutoCrud` register |
| Discover a directory | via app wiring | `discover($modelsDir, $public=false)` | discovers `src/orm`/`orm` | discover |
| GET list | paginated, ADR-0043 envelope | same | same | same |
| GET one / POST / PUT / DELETE | yes | yes (`create*Handler`) | yes | yes |
| Writes secured by default | yes (token required) | yes | yes ("secured by default") | yes |
| Write-opening flag | `public` (default false) | `public` (default false) | route `auth:` (default true) | `public` |
| List envelope | `to_paginate()` (ADR-0043) | same | same | same (task 72: all four) |

All four generate the same five routes and all four secure the write routes by default (a
POST/PUT/DELETE needs a valid token unless the resource is opened), matching the framework-wide
router rule. The list route returns the ADR-0043 paginate envelope in all four (already
aligned). The one divergence is the flag that OPENS the writes: Python and PHP take `public`
(default `false`), while Ruby's route convention is `auth:` (default `true`) -- the same
inverted-flag pattern the audit has hit before (`production`/`development` in Feature 2,
`nullable`/`required` in Feature 19). `public = true` and `auth: false` mean the same thing
with opposite polarity and a different name.

## Public surface contract

`register(model, prefix="/api", public=false)` generates and registers five routes for one
model; `discover(dir, public=false)` does the same for every model in a directory. The five
routes are `GET {prefix}/{table}` (paginated list), `GET {prefix}/{table}/{id}` (one),
`POST {prefix}/{table}` (create), `PUT {prefix}/{table}/{id}` (update), `DELETE
{prefix}/{table}/{id}` (delete). GET is public; the writes require a token unless `public` is
true. The list returns the ADR-0043 envelope.

## Inputs and outputs

- Input: a model class (or a directory of them), a URL prefix (default `/api`), and the
  `public` flag.
- Output: registered routes; the list returns the seven-key paginate envelope; a read returns
  the serialized model; a create/update returns the written model; a delete returns a success
  status.
- A write without a valid token returns the framework's auth-failure status, not the write.
- The generated routes carry Swagger metadata so they appear in the API doc.

## Lifecycle and operation graph

1. `register(model, prefix, public)` (or `discover`) derives the table name and builds the
   five handlers.
2. The GET routes register open; the POST/PUT/DELETE routes register behind the router's
   write-gate unless `public` is true.
3. A list request paginates via `to_paginate()` and returns the ADR-0043 envelope.
4. A read/create/update/delete request runs the corresponding ORM operation and serializes the
   result.

## Configuration and precedence

- `prefix` defaults to `/api`; an explicit prefix overrides it.
- `public` defaults to `false` (writes secured); passing `true` opens the writes. This is the
  one flag that must be spelled and defaulted identically in all four.
- Model discovery scans a configured directory; an explicit model registration is exact.

## Failures, side effects and security

- SECURE BY DEFAULT: the write routes require a valid token unless explicitly opened, matching
  the router's framework-wide rule. Opening writes is an explicit, single-flag opt-in, never a
  default.
- The inverted-flag divergence (`public` vs `auth:`) is a security-shaped footgun: a developer
  porting a resource who reads the wrong polarity could open writes believing they closed them.
  One spelling, one polarity, removes the hazard.
- The list envelope carries no duplicate or camelCase keys (ADR-0043), so a consumer cannot
  read a wrong spelling.
- A create/update validates the model before writing (Feature 19); an invalid body returns a
  validation response, not a partial write.

## Wire and persistence contract

The wire shapes are: the ADR-0043 seven-key envelope for the list, the serialized model
(Feature 17) for a read/create/update, and a success status for a delete. AutoCRUD adds no new
persistence; it maps HTTP verbs to ORM operations over the model's own table.

## Providers and substitutability

AutoCRUD is engine-agnostic: it composes ORM operations that any provider satisfies. A future
runtime generates the same five routes with the same secure-by-default posture and the same
envelope.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| CRUD-01 | The write-opening flag diverges in name and polarity: Python/PHP `public` (default false), Ruby route `auth:` (default true). Same inverted-flag class as Features 2 and 19; a security-shaped footgun. | One spelling and polarity in all four: `public` (default false); reject the old spelling with a clear error, never a silent reinterpretation. |
| CRUD-02 | The list envelope must be the ADR-0043 seven-key shape in all four (task 72 fixed it; it needs a standing gate). | Gate the ADR-0043 envelope on the AutoCRUD list route in all four. |
| CRUD-03 | The update verb (PUT vs PATCH) and the exact route set are not proven identical. | Pin the five routes and the update verb in all four. |
| CRUD-04 | Model discovery (register-one vs discover-a-directory) and the default prefix are not gated as parity. | Gate `register` and `discover` and the `/api` default in all four. |
| CRUD-05 | No shared fixture exists. | Add `autocrud_contract.json` exercising real routes. |

## Owner decisions

Proposed for owner ratification:

1. One write-opening flag: `public`, default `false`, in all four (reconcile Ruby's `auth:`
   convention at the AutoCRUD surface to `public`, rejecting the old spelling). Writes are
   secured by default; opening them is a single explicit opt-in.
2. The five routes are fixed: `GET {prefix}/{table}` (list), `GET {prefix}/{table}/{id}`,
   `POST`, `PUT {prefix}/{table}/{id}`, `DELETE {prefix}/{table}/{id}`, with `prefix` default
   `/api`.
3. The list route returns the ADR-0043 seven-key paginate envelope (already aligned; gated).
4. A create/update validates via Feature 19 before writing; an invalid body is a validation
   response, not a partial write.
5. Generated routes carry Swagger metadata so the resource is self-documenting.

## Proposed conformance fixture

Add `autocrud_contract.json` with stable ids for: `register` generating exactly the five
routes; a list returning the ADR-0043 envelope; a write REJECTED without a token by default;
the same write ACCEPTED with `public=true`; a create validating the body; `discover`
registering a directory of models; and the `/api` default prefix. Every case exercises real
routes over real SQLite through the real auth gate; no mock can claim conformance.

## Integration map

- Feature 17 supplies the models; Feature 24/ADR-0043 supplies the list envelope; the router
  supplies the write-gate; Swagger documents the generated routes; the dev-admin UI may list
  them.
- Feature 19 validates a create/update body.
- Central fixtures, four runners, the CI matrix, release notes and the CRUD docs update
  together.

## Breaking changes and migration

- Reconciling the write-opening flag to `public` changes Ruby's AutoCRUD spelling; the old
  `auth:` spelling is rejected with a clear error (never silently reinterpreted, because a
  silent polarity flip on a security control is the worst outcome). `Breaking:` entry.
- The list envelope is already ADR-0043 in all four (no further break there).
- Pinning the update verb may change one framework's route; state it in the release note.

## Implementation backlog

1. Add `autocrud_contract.json` and wire four runners against real routes over real SQLite.
2. Reconcile the write-opening flag to `public` (default false) in all four; gate the
   secured-by-default and the open-with-public cases.
3. Gate the ADR-0043 list envelope and the five-route set (including the update verb).
4. Gate `register`/`discover` and the `/api` default.
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `register(model, prefix="/api", public=false)` and `discover(dir, public=false)`
generating five routes: a paginated list (the ADR-0043 seven-key envelope), a read, a create,
an update and a delete. Register GET open and POST/PUT/DELETE behind the router's write-gate
unless `public` is true. Validate a create/update body (Feature 19) before writing, attach
Swagger metadata, and use `public` (default false) as the single write-opening flag. Prove the
port against real routes over real SQLite, including a write rejected without a token by
default.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (CRUD-01..05).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
