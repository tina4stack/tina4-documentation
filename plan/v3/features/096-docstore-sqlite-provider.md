# Feature 096: SQLite document store provider

## Identity and status

- Matrix identity: 96 - SQLite document store provider
- Audit state: decision-ready
- Audit note: proven as part of `docstore_contract.json` (9/9 invariants; the SQLite fallback is the
  always-present control that the real Mongo provider is measured against). Measured 2026-08-10 against
  the shipped source and the proven fixture. No framework code changed.
- Dependencies: feature 095 (the interface contract this backend realizes), SQLite with JSON1
- Dependants: every app that has not configured a Mongo URI (this is the default), and every dev machine
- Existing ADRs: ADR-0024/0025 (via 095); ADR-0035 (Tina4 supplies the uniform spelling on both); ADR-0036
  (deferred cursor, one sort contract)
- Shared fixtures: `docstore_contract.json` (the SQLite fallback is exercised in every invariant)
- Catalog phase: Integration providers

## Why this feature exists

An application needs a Mongo-style document store with ZERO configuration and ZERO dependency in
development. The SQLite provider stores documents as JSON in a local file and queries them via SQLite's
JSON1 (`json_extract`), presenting the IDENTICAL `get_collection` surface as real MongoDB - so an app
develops against it locally and switches to Mongo in production by setting one env var, with no call-site
change.

## Boundary

This packet owns the SQLite REALIZATION of the 095 interface: the JSON-on-disk store, the filter
compiler (Mongo query -> JSON1 SQL), the deferred cursor, and the value codec. The interface contract is
095; the real-driver backend is 097.

## Existing implementation evidence

The SQLite provider implements the FULL 095 surface - it is the imitation reference (ADR-0025: the
fallback imitates the driver):

| 095 operation | SQLite provider |
| --- | --- |
| insert_one / insert_many | full - documents stored as JSON, `_id` assigned (ObjectId 24-hex) |
| find / find_one (+ projection) | full - returns a DEFERRED cursor; filter compiled to JSON1 `json_extract` predicates |
| cursor sort / limit / skip / to_list | full - accumulates, executes only on iterate/materialise (ADR-0036, one sort contract) |
| count_documents / estimated_document_count / distinct | full |
| update_one / update_many / replace_one (upsert) | full - `$set`/`$unset`/`$inc`, replace, upsert |
| delete_one / delete_many / drop | full |
| query operators | equality, `$in`/`$nin`, `$gt`/`$gte`/`$lt`/`$lte`, `$ne`, `$exists`, `$regex`, implicit AND, `$or`/`$and`, dotted nested keys - matching Mongo, including array-containment |
| value codec | datetime <-> ISO-8601, ObjectId <-> 24-hex, queryable via `json_extract` |

The SQLite provider is the control in the fixture's query-semantics and cursor invariants: the equality
of its behaviour with Mongo IS the invariant.

## Public surface contract

Selected by default (no `TINA4_MONGO_URI`, or the driver absent is a loud failure - see 095/097).
`is_serverless()` returns true here. It exposes exactly the 095 surface - no extra methods, no missing
ones (ADR-0035). The store file is `TINA4_DOC_STORE_PATH` (default `data/tina4_docstore.db`).

## Inputs and outputs

- Input: the 095 documents and Mongo-style filters/updates; a store-file path.
- Output: the 095 results and a deferred cursor. Values round-trip through the codec; a filter that
  matches on Mongo matches here (query-semantics-match-on-both-providers).

## Lifecycle and operation graph

Identical to 095, realized on SQLite: a document is stored as a JSON row; `find` compiles the filter to
JSON1 `json_extract` predicates and returns a deferred cursor; sort/limit/skip accumulate and execute on
materialise; writes update the JSON row. The store opens no network connection (`is_serverless()` true).

## Configuration and precedence

- Selected when `TINA4_MONGO_URI` is unset (the default). `TINA4_DOC_STORE_PATH` sets the file (default
  `data/tina4_docstore.db`).

## Failures, side effects and security

- The SQLite provider never refuses a 095 operation - it implements the full surface, so it is the
  backend where the imitation must be exact (ADR-0025). The mutation tests target this equality: a
  filter or cursor that behaves differently here than on Mongo kills the dependent case.
- The store is a local file readable by the app user; it holds document data. No network surface, so
  `is_serverless()` is true and the connection-ceiling concern (095) does not apply here.
- A subtle ordering trap was fixed and locked: a DocStore test that re-imported the module changed the
  default-store identity; the store is now stable across re-import (the order-dependent test is fixed).

## Wire and persistence contract

JSON documents in a SQLite file, queried via JSON1. The value codec encodes datetime as ISO-8601 and
ObjectId as 24-hex so `json_extract` can query them and they round-trip to the same shape Mongo returns.
The document shape is byte-compatible in intent with the Mongo provider (097).

## Providers and substitutability

This IS the default provider and the imitation reference. Switching to Mongo (097) by setting the URI
keeps every call site and every query result identical - the SQLite provider is the yardstick for what
"the same" means.

## Contradictions and defects

No open contract defects - the SQLite provider is fully proven and refuses nothing. The store is
plaintext JSON on disk (a document with secrets is readable by the app user) - an operational note, not
a contract defect.

## Owner decisions

None. The SQLite provider is the proven imitation reference; the only cross-cutting items live in 095.

## Proposed conformance fixture

Covered by `docstore_contract.json` - the SQLite fallback is the control in all nine invariants. No
separate fixture is owed.

## Integration map

- Selected by default via `TINA4_MONGO_URI` unset; realizes the 095 interface on SQLite/JSON1; the value
  codec is shared with the Mongo provider so documents round-trip identically.

## Breaking changes and migration

None. The identical-surface, deferred-cursor and value-codec behaviour already shipped; the module
re-import identity fix already landed.

## Implementation backlog

1. Nothing on the backend - it is proven. The order-dependent re-import test is fixed and locked.

## Porting capsule

Implement a SQLite document-store provider that realizes every 095 operation on JSON documents in a
local file queried via JSON1 (`json_extract`): insert (assign an ObjectId `_id`), `find`/`find_one`
returning a DEFERRED cursor (accumulate sort/limit/skip, execute on materialise), count/distinct,
update/replace/delete/drop, and the full Mongo filter-operator set (including array-containment) compiled
to JSON1 predicates. Round-trip datetime (ISO-8601) and ObjectId (24-hex) through a value codec so a
document reads back the same shape Mongo returns. `is_serverless()` returns true; open no network
connection. Prove it as the imitation control in `docstore_contract.json` - it must match Mongo on every
query.

## Audit closure checklist

- [x] Boundary and public surface complete (the SQLite backend; interface is 095).
- [x] Lifecycle and every producer/consumer edge complete (JSON1 realization, deferred cursor).
- [x] Configuration, failure, side-effect and security rules complete (full support, plaintext-on-disk note, re-import fix).
- [x] Wire/storage and provider contracts complete (JSON docs + JSON1; shared value codec).
- [x] Existing-language contradictions recorded (none; fully proven; the imitation control).
- [x] Owner ambiguities recorded (none).
- [x] Proposed shared cases and mutation witnesses complete (the control in `docstore_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
