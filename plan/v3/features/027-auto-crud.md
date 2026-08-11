# Feature 27: Automatic CRUD from models

## Identity and status

- Matrix identity: 27 - Automatic CRUD from models (`tina4_python/crud/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, SECURE-BY-DEFAULT (verified) with a validation-status bug and a
  mass-assignment surface. Measured 2026-08-11. Python `crud/__init__.py:70` (`ebbab30`); PHP
  `Tina4/AutoCrud.php:45` (`6faabac5`); Ruby `lib/tina4/auto_crud.rb:29` (`6d5b1de`); Node
  `packages/orm/src/autoCrud.ts:116` (`27cf0f4`).
- Dependencies: the base model + validation (17/19), pagination (24), soft delete (20), the router auth gate.
- Dependants: apps that expose a model as REST with no hand-written routes.
- Existing ADRs: ADR-0043 (the 7-key list envelope).

- Catalog phase: ORM / HTTP

## Why this feature exists

AutoCrud turns a model into a REST resource - `GET/POST/PUT/DELETE /api/{table}` - with no hand-written
routes. Because it generates WRITE endpoints, the security-critical question is whether those writes are
secured by default. They are (verified in all four). The remaining issues are the error status on a failed
create and unguarded body columns.

## Existing implementation evidence

Universal: `register(Model, public=false)` / `discover()` / an `auto_crud=true` flag auto-registers 5 routes
(`GET` list, `GET /{id}`, `POST`, `PUT /{id}`, `DELETE /{id}`). The list returns the ADR-0043 7-key envelope
with a TRUE COUNT (feature 24). Soft delete is respected (list/get/existence checks filter `is_deleted`;
DELETE soft-deletes when enabled).

- AUTH - SECURE BY DEFAULT, verified end-to-end in all four: the write handlers opt out of the auth gate ONLY
  when `public=true`; the router requires auth for write methods unless the handler carries the no-auth flag.
  So generated `POST`/`PUT`/`DELETE` require a valid token by default; GET is public. Node's test even boots a
  real server and asserts a tokenless secure POST returns a real 401.
- Validation: POST validates the body (`validate()` -> a 4xx in Python/Node); PUT's validation diverges (see
  the register).

## Public surface contract

`register(Model, public=false)` -> 5 REST routes. Contract: reads are public, writes require auth unless
`public=true`, the list is the 7-key envelope, and an invalid body is rejected.

## Inputs and outputs

- Input: a registered model, HTTP requests. Output: JSON (list envelope / `{data}` / `{message,data}`);
  401 on an unauthenticated write; a 4xx (or, buggily, 500) on an invalid create.

## Lifecycle and operation graph

1. Register the model (explicit or via the flag) -> 5 routes with the write-auth gate on unless `public`.
2. POST: validate -> save (or reject); PUT: assign -> save; DELETE: soft/hard delete; list: paginated
   envelope.

## Configuration and precedence

- `register(..., public=?)` (or the model's `public` flag); the list reads `?page/?per_page/?limit/?offset/
  ?filter[]/?sort`.

## Failures, side effects and security

- The security-critical property (writes need auth by default) HOLDS in all four. The remaining issues: the
  create-error status is wrong in two languages, and the body allows writing any real column (mass
  assignment). See the register.

## Wire and persistence contract

The 7-key list envelope (ADR-0043); `{data}` for single records. The auth contract: write = secure unless
`public`.

## Providers and substitutability

No provider abstraction; the routes are generated from the model.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CRUD-VALIDATION-STATUS | The POST validation-failure status is WRONG in two of four, and inconsistent across the correct two. On an invalid create: Python returns 400 and Node returns 422 (both correct 4xx, but DIFFERENT codes); PHP returns HTTP 500 with a stale `detail` from `$db->error()` (no DB call happened - the cause is on the model's `getError()`); Ruby returns HTTP 500 (`create()` returns `false`, the handler calls `.persisted?` on `false` -> `NoMethodError` -> 500, run-verified). So PHP and Ruby report a server error for a client input error, and even Python/Node disagree on the code. | Return a consistent 4xx (choose 400 or 422) with the FIELD errors (from the model's error, not the DB error) on a validation failure, in all four. Fix PHP's status + detail source and Ruby's `create()`-returns-false handling. Add a test that an invalid POST returns the 4xx with the errors. |
| CRUD-PUT-NOVALIDATE | AutoCrud PUT (update) performs NO body validation in Node (confirmed; POST validates, PUT does not), and the partial-update validator mode (`isUpdate`) is wired into no write path. So an update can write type/length/pattern-violating data a create would reject. (Confirm PHP/Ruby PUT - Python/PHP validate via `save()`.) | Validate the PUT body (partial-update mode) in all four; wire the `isUpdate` mode. |
| CRUD-MASS-ASSIGNMENT | The body is not column-allow-listed: validation iterates the FIELD DEFS, so body keys not in `fields` are never checked, and the column mapper passes unknown keys through - so a client can write ANY real column, INCLUDING `is_deleted` (Node, explicit) via a POST/PUT body. Python additionally lets a client-supplied PK turn a POST-create into an overwrite of an existing row (or a 201 for a no-op update). | Allow-list writable columns (reject unknown/guarded keys like `is_deleted`, and strip the PK on create) in the AutoCrud handlers, all four. |
| CRUD-WRITE-TESTS | The generated write routes are under-tested at the wire level: no test boots a server, registers an AutoCrud model, and POSTs/PUTs/DELETEs through the gate (Node/PHP cover route STRUCTURE + GET; the secure-by-default property is asserted at the route-flag level, not via a real authenticated-vs-unauthenticated request in Ruby). | Add wire tests for POST(201/4xx)/PUT/DELETE, including a tokenless write returning 401 (Node has this; add to the others). |

## Owner decisions

- CRUD-DEC-01 (proposed): return a consistent 4xx with field errors on a failed create (CRUD-VALIDATION-STATUS)
  - fix PHP/Ruby's 500 - and validate the PUT body (CRUD-PUT-NOVALIDATE). Highest value (a client error
  currently reads as a server error, and updates skip validation).
- CRUD-DEC-02 (proposed): allow-list writable columns and strip the PK on create (CRUD-MASS-ASSIGNMENT); add
  the wire tests (CRUD-WRITE-TESTS).

## Proposed conformance fixture

A shared wire fixture (real server, no mocks): a tokenless POST/PUT/DELETE returns 401 (secure-by-default -
Node's model, ported to all); a valid POST returns 201; an INVALID POST returns a 4xx with the field errors
(catches CRUD-VALIDATION-STATUS); a PUT with invalid data is rejected (CRUD-PUT-NOVALIDATE); a body with
`is_deleted` or a client PK is rejected/stripped (CRUD-MASS-ASSIGNMENT); the list is the 7-key envelope.

## Integration map

- Consumers: apps exposing a model as REST. Composes: the base model + validation (17/19), pagination (24),
  soft delete (20), the router auth gate (feature family: auth/middleware).

## Breaking changes and migration

- Fixing the create-error status changes response codes (500 -> 4xx) - a correctness fix. Allow-listing columns
  rejects previously-accepted keys - document it (it closes a mass-assignment hole).

## Porting capsule

AutoCrud needs: 5 generated routes with WRITES SECURE BY DEFAULT (require a token unless `public=true`; GET
public - the one property to never get wrong, and it is right in all four today); the ADR-0043 7-key list
envelope with a true COUNT; soft-delete respected; a consistent 4xx (with FIELD errors) on a failed create,
NOT a 500; validation on BOTH create and update; and an allow-list of writable columns (reject `is_deleted`,
strip the PK on create) so a body cannot mass-assign guarded columns. Wire-test the auth (tokenless write ->
401) and the create/update/delete paths.

## Audit closure checklist

- [x] Boundary and public surface complete (5 routes + envelope + auth x four).
- [x] Lifecycle and producer/consumer edges complete (register -> gated routes -> validate/save).
- [x] Configuration, failure (validation status) and security (secure-by-default, mass assignment) rules
  complete.
- [x] Wire (7-key envelope, auth contract) and provider contracts complete.
- [x] Four-language behaviour recorded (secure-by-default all four; status bug php/ruby; mass assignment).
- [x] Owner ambiguities decided (CRUD-DEC-01/02).
- [x] Conformance fixture (auth + create/update/mass-assign) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
