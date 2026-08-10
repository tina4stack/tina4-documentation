# Feature 095: Document store interface

## Identity and status

- Matrix identity: 95 - Document store interface
- Audit state: decision-ready
- Audit note: this feature is ALREADY PROVEN. `docstore_contract.json` (9 invariants, 9 proven, 0 owed)
  drives four real runners against a LIVE MongoDB and the SQLite fallback (no mocks). This audit records
  the proven contract, the provider-selection seam, and the provider realizations (096 SQLite, 097
  MongoDB). Measured 2026-08-10 against the shipped source and the proven fixture; source unchanged.
- Dependencies: the env/dotenv layer (`TINA4_MONGO_URI`, `TINA4_DOC_STORE_PATH`), SQLite (the
  zero-config fallback), the optional MongoDB driver
- Dependants: any app storing whole documents with Mongo-style queries; the session/cache MongoDB
  backends reuse the same driver-selection idiom
- Existing ADRs: ADR-0024 (a provider is an env var, the swap must work), ADR-0025 (the fallback
  imitates the driver - it is never the driver's job to imitate us), ADR-0035 (Tina4 SUPPLIES the
  uniform spelling on both providers; it does not delete it), ADR-0036 (find() is DEFERRED, and there
  is ONE sort contract). All Accepted.
- Shared fixtures: `docstore_contract.json` - 9 invariants, ALL PROVEN against live MongoDB + SQLite.
  Reference-quality (with cache, session, messenger, queue).
- Catalog phase: Integrations

## Why this feature exists

An application wants a document store with Mongo-style queries but zero configuration in development.
`get_collection(name)` returns a Mongo-style collection: a REAL Mongo collection when a URI is
configured and the driver is present, otherwise a SQLite-backed `SqliteCollection` (JSON1) with the
IDENTICAL surface. You develop against the zero-dependency local store and switch to MongoDB in
production by setting one env var - and the call sites do not change.

## Boundary

This feature owns the DOCUMENT-STORE INTERFACE: the `get_collection` factory, the provider-selection
gate (URI+driver -> real Mongo; else SQLite fallback; missing-driver -> one loud outcome), the identical
call-site surface across providers, the deferred cursor chain, the exported types (ObjectId), the value
codec (datetime, ObjectId round-trip), and the bounded client lifecycle (`close_doc_store`). The two
provider REALIZATIONS are features 096 (SQLite) and 097 (MongoDB).

## Existing implementation evidence

The nine proven invariants ARE the interface contract (all PROVEN in all four, live MongoDB + SQLite):

| Invariant | Rule (summary) | ADR |
| --- | --- | --- |
| a-configured-uri-selects-the-real-provider | a Mongo URI + driver present -> `get_collection()` returns a REAL Mongo collection, never silently the SQLite fallback | 0024 |
| a-missing-driver-has-one-outcome-in-all-four | URI configured + driver ABSENT -> the SAME LOUD outcome in all four; never a silent degrade to the local file | 0024 |
| the-call-site-surface-is-identical | every method + cursor op on the fallback exists with the same name and meaning on the real provider, and vice versa | 0025, 0035 |
| the-cursor-chain-is-deferred-and-works-on-both | `find()` returns a chainable query that ACCUMULATES sort/limit/skip and executes only when iterated/materialised - never inside `find()`; one sort contract | 0036 |
| the-sync-async-shape-does-not-change-with-the-provider | a call returns the same KIND of thing on both providers (value vs promise), so un-awaited code does not silently change meaning when the env var flips | 0025 |
| query-semantics-match-on-both-providers | a filter that matches on one provider matches on the other; array-containment in particular behaves the same on SQLite as on Mongo | 0025 |
| client-lifecycle-is-bounded | repeated `get_collection()` does not create unbounded client connections; clients are reused or closed | 0025 |
| exported-types-are-accepted-by-the-real-driver | a type the module exports for documents (ObjectId) can be encoded by the real driver | 0024 |
| a-real-mongo-is-actually-exercised | every framework has at least one DocStore test against a REAL Mongo collection, not only the SQLite fallback | 0024 |

The interface is the substitutability seam proven end to end: the same code runs on SQLite in dev and
Mongo in prod with no call-site change, and the fallback imitates the driver (ADR-0025), not the
reverse.

## Public surface contract

`get_collection(name)` returns a collection exposing `insert_one`/`insert_many`, `find_one`, `find`
(-> a deferred `Cursor` with `sort`/`limit`/`skip`/projection/`to_list`), `count_documents`/
`estimated_document_count`, `distinct`, `update_one`/`update_many`/`replace_one` (with `upsert`),
`delete_one`/`delete_many`, and `drop`. Exports: `ObjectId` (24-hex round-trip), `is_serverless()`
(true on the SQLite fallback), `close_doc_store()` (closes every Mongo client + the SQLite store).
Idiomatic casing per language; the concept set is identical (ADR-0035 - Tina4 supplies the uniform
spelling on both providers). The sync/async SHAPE is per-language (Python/PHP/Ruby return the collection
directly; Node's `getCollection` is async) but stable across providers WITHIN each framework.

## Inputs and outputs

- Input: a collection name; documents (dicts/objects, values including datetime and ObjectId); Mongo-
  style filters (equality, `$in`/`$nin`, `$gt`/`$gte`/`$lt`/`$lte`, `$ne`, `$exists`, `$regex`, implicit
  AND, `$or`/`$and`, dotted nested keys) and updates (`$set`/`$unset`/`$inc`, replace, upsert).
- Output: result objects (`InsertOneResult`/`UpdateResult`/`DeleteResult`) and a deferred `Cursor` from
  `find`. Values round-trip: datetime <-> ISO-8601, ObjectId <-> 24-hex, queryable via `json_extract` on
  the fallback. Non-goals (both providers): aggregation pipelines, `$elemMatch`, geo queries.

## Lifecycle and operation graph

1. SELECT: `get_collection(name)` reads the URI config; URI + driver -> a real Mongo collection; else a
   `SqliteCollection` (JSON1). URI + driver ABSENT -> a LOUD failure (never a silent local-file degrade).
2. QUERY: `find()` returns a deferred cursor; `sort`/`limit`/`skip` accumulate and execute only on
   iterate/materialise (ADR-0036).
3. WRITE: insert/update/replace/delete act on the selected provider; values are encoded through the
   codec so datetime/ObjectId round-trip.
4. CLOSE: `close_doc_store()` releases every cached Mongo client and the SQLite store (bounded
   lifecycle - one client per URI, reused across calls).

## Configuration and precedence

- `TINA4_MONGO_URI` - the app-wide Mongo URI; falls back to `TINA4_SESSION_MONGO_URI`, then the legacy
  `TINA4_SESSION_MONGO_URL`. When set and the driver is present, `get_collection` returns a real Mongo
  collection.
- `TINA4_DOC_STORE_PATH` - the SQLite fallback file (default `data/tina4_docstore.db`).
- A configured URI with a MISSING driver is a loud failure in all four (ADR-0024), not a silent
  fallback - the operator asked for Mongo and must be told the driver is absent.

## Failures, side effects and security

- MISSING-DRIVER IS LOUD (a-missing-driver-has-one-outcome-in-all-four, ADR-0024): a configured URI with
  no driver produces the SAME loud outcome in all four - it must NOT silently write to the local file,
  which would look like success while the operator believed they were on Mongo. This is the same
  fail-loud posture as the session/cache backend selection.
- THE FALLBACK IMITATES THE DRIVER (ADR-0025): the SQLite fallback matches the driver's surface, sync/
  async shape, and query semantics (including array-containment) - so code cannot behave differently
  when the env var flips. The uniform spelling is SUPPLIED on both, never deleted from one (ADR-0035).
- BOUNDED CLIENTS (client-lifecycle-is-bounded, ADR-0025): `get_collection` caches one Mongo client per
  URI rather than building one per call - the pre-3.13.95 bug built a client on every call and never
  closed it, so 20 calls left ~39 connections open and grew without bound (invisible locally because the
  SQLite fallback opens none). `close_doc_store()` closes them all.
- The Mongo URI (with credentials) is the security surface; the SQLite fallback is a local file.

## Wire and persistence contract

Two persistence backends behind one surface: the SQLite fallback (JSON documents in a local file, keyed
and queried via JSON1 `json_extract`) and real MongoDB (BSON documents). The value codec makes datetime
and ObjectId round-trip identically on both, so a document written on SQLite reads back the same shape on
Mongo. The query contract (the filter operators, the deferred cursor, the sort contract) is identical
across providers - that identity IS the feature.

## Providers and substitutability

Two providers behind `get_collection`, selected by `TINA4_MONGO_URI` (ADR-0024): SQLite (096, the
zero-config default and the imitation reference) and MongoDB (097, the real driver). The substitution is
proven by the fixture end to end: the same code runs on both, the fallback imitates the driver, and the
sync/async shape and query semantics do not change with the provider.

## Contradictions and defects

No open contract defects - the interface is proven (9/9) and every historical divergence is closed
(the connection-ceiling leak, the missing-driver silent degrade, the deferred-cursor and one-sort
contract, the module-re-import identity test). The two provider realizations carry their own rows (096,
097). No new ADR is owed.

## Owner decisions

None. The interface contract is ratified (ADR-0024/0025/0035/0036) and proven. The sync/async
per-language shape (Node async, others sync) is a settled idiom, stable across providers within each
framework.

## Proposed conformance fixture

ALREADY EXISTS and is PROVEN: `docstore_contract.json` (9 invariants, 9 proven, 0 owed) drives four
runners against a LIVE MongoDB and the SQLite fallback (no mocks), including a real-Mongo exercise per
framework. No new fixture is owed.

## Integration map

- `TINA4_MONGO_URI`/`TINA4_DOC_STORE_PATH` select the provider; the session/cache MongoDB backends reuse
  the same driver-selection idiom; `close_doc_store()` bounds the client lifecycle.
- `docstore_contract.json` is the shared oracle; ADR-0024/0025/0035/0036 are the ratifying decisions.
- The provider features 096 (SQLite) and 097 (MongoDB) own each backend's realization.

## Breaking changes and migration

None outstanding. The changes that unified the interface (the identical surface, the deferred cursor,
the one-sort contract, the bounded client lifecycle, the loud missing-driver) already shipped. A current
release speaks the proven contract.

## Implementation backlog

1. Nothing on the interface - it is proven. Re-run the docstore contract runners on the lab against a
   live Mongo to confirm 9/9 at the current HEAD (routine).

## Porting capsule

Implement a document-store interface: `get_collection(name)` returning a Mongo-style collection that is
a REAL Mongo collection when a URI (`TINA4_MONGO_URI`) is configured and the driver is present, else a
SQLite-backed `SqliteCollection` (JSON1) with the IDENTICAL surface (`insert_one`/`find`/`find_one`/
`update_one`/`update_many`/`replace_one`/`delete_one`/`delete_many`/`count_documents`/`distinct`/`drop`).
A URI with a MISSING driver fails LOUDLY (never a silent local-file degrade). `find()` returns a DEFERRED
cursor that accumulates sort/limit/skip and executes only on iterate/materialise (one sort contract).
Keep the sync/async shape stable across providers, match query semantics (including array-containment) on
both, round-trip datetime and ObjectId, cache one client per URI (bounded lifecycle), and expose
`close_doc_store()`. The fallback imitates the driver - never the reverse. Prove it with
`docstore_contract.json` against a live MongoDB and the SQLite fallback.

## Audit closure checklist

- [x] Boundary and public surface complete (the interface + the provider-selection seam; providers own realization).
- [x] Lifecycle and every producer/consumer edge complete (select/query/write/close).
- [x] Configuration, failure, side-effect and security rules complete (loud missing-driver, imitation, bounded clients).
- [x] Wire/storage and provider contracts complete (SQLite JSON1 + real Mongo behind one surface).
- [x] Existing-language contradictions recorded (none open; all historical divergences closed and proven).
- [x] Owner ambiguities recorded (none; the sync/async idiom is settled).
- [x] Proposed shared cases and mutation witnesses complete (`docstore_contract.json`, 9/9 proven, live Mongo + SQLite).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
