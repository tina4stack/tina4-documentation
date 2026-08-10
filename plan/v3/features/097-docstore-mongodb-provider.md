# Feature 097: MongoDB document store provider

## Identity and status

- Matrix identity: 97 - MongoDB document store provider
- Audit state: decision-ready
- Audit note: proven as part of `docstore_contract.json` (9/9 invariants; every framework has at least
  one DocStore test against a REAL Mongo collection - invariant a-real-mongo-is-actually-exercised).
  Measured 2026-08-10 against the shipped source and the proven fixture. No framework code changed.
- Dependencies: feature 095 (the interface contract), a MongoDB server, the MongoDB driver
- Dependants: production apps that store documents in MongoDB
- Existing ADRs: ADR-0024 (a provider is an env var; the swap must work; the exported types encode),
  ADR-0025 (the fallback imitates the driver - the driver is the reference)
- Shared fixtures: `docstore_contract.json` (MongoDB is the real provider proven against live)
- Catalog phase: Integration providers

## Why this feature exists

A production application stores documents in MongoDB. The MongoDB provider is what `get_collection`
returns when a URI is configured and the driver is present: a REAL Mongo collection. It is the reference
the SQLite fallback (096) imitates - the driver defines the behaviour, and Tina4 supplies the uniform
spelling ON it (ADR-0035) without changing what the driver does.

## Boundary

This packet owns the MONGODB REALIZATION of the 095 interface: selecting the real driver when the URI +
driver are present, the bounded client lifecycle (one client per URI), and the exported types the driver
must encode. The interface contract is 095; the SQLite fallback is 096.

## Existing implementation evidence

The MongoDB provider IS the real driver's collection, wrapped so the 095 surface is uniform (all PROVEN):

| 095 concern | MongoDB provider |
| --- | --- |
| selection | chosen when `TINA4_MONGO_URI` (or the session fallbacks) is set AND the driver is present; a missing driver is a LOUD failure, never a silent SQLite degrade |
| surface | the real driver's collection, with the uniform 095 method + cursor names SUPPLIED on it (ADR-0035); no method removed |
| deferred cursor | `find()` returns the driver's cursor, deferred and chainable (sort/limit/skip), one sort contract (ADR-0036) |
| query semantics | the driver's native semantics; the SQLite fallback is written to MATCH these (096), so the fixture proves equality |
| exported types | ObjectId (and the datetime codec) are encodable by the real driver (exported-types-are-accepted-by-the-real-driver) |
| client lifecycle | one MongoClient per URI, cached and reused; `close_doc_store()` closes them all (bounded - the pre-3.13.95 per-call-client leak is fixed) |
| real exercise | every framework runs at least one DocStore test against a REAL Mongo collection |

The MongoDB provider is the behavioural reference; the fixture's job is to prove the SQLite fallback
matches it, and that the selection + missing-driver + client-lifecycle + type-encoding rules hold.

## Public surface contract

Selected by `TINA4_MONGO_URI` (falling back to `TINA4_SESSION_MONGO_URI`, then the legacy
`TINA4_SESSION_MONGO_URL`) with the driver present. It exposes the 095 surface backed by the real
driver; `is_serverless()` returns false. The sync/async shape is per-language and stable across
providers (Node async, others sync).

## Inputs and outputs

- Input: the 095 documents and Mongo-style filters/updates; a Mongo URI.
- Output: real driver results and a real driver cursor. ObjectId and datetime encode natively. A URI
  with no driver is a loud failure (not a silent local-file write).

## Lifecycle and operation graph

`get_collection` resolves the URI, ensures the driver is present (else fails loud), gets or reuses the
cached MongoClient for that URI, and returns the real collection. Queries and writes go straight to the
driver; the deferred cursor is the driver's. `close_doc_store()` closes every cached client.

## Configuration and precedence

- `TINA4_MONGO_URI` (or `TINA4_SESSION_MONGO_URI` / legacy `TINA4_SESSION_MONGO_URL`) selects it, the
  driver must be present. Credentials ride in the URI. Explicit configuration wins.

## Failures, side effects and security

- MISSING DRIVER IS LOUD (ADR-0024): a configured URI with the driver absent fails with the SAME loud
  outcome in all four - it must never silently degrade to the SQLite file, which would look like success
  while the data went to the wrong place.
- BOUNDED CLIENTS (ADR-0025): one MongoClient per URI, cached and reused. The pre-3.13.95 bug built a
  client on EVERY `get_collection` call and never closed it (20 calls -> ~39 open connections, growing
  without bound, invisible locally because the SQLite fallback opens none); fixed by caching, closable
  via `close_doc_store()`. The fixture's client-lifecycle invariant is the guard.
- TYPE ENCODING (ADR-0024): the ObjectId and datetime the module exports must be encodable by the real
  driver - proven so no document written with an exported type is rejected on the wire.
- The Mongo URI (with credentials) is the security surface; the transport uses the driver's TLS.

## Wire and persistence contract

Real MongoDB (BSON documents) via the driver. The document shape matches the SQLite fallback's through
the shared value codec, so a document round-trips to the same shape on both providers. The query and
cursor contracts are the driver's native ones; the SQLite fallback is written to match them.

## Providers and substitutability

The real-driver provider behind `get_collection`, the counterpart to the SQLite fallback (096). Setting
`TINA4_MONGO_URI` swaps from SQLite to Mongo with no call-site change (ADR-0024, the swap must work);
the fallback imitates this provider (ADR-0025), never the reverse.

## Contradictions and defects

No open contract defects - the MongoDB provider is proven, the client leak is fixed, the missing-driver
outcome is loud and uniform, and the exported types encode. The MongoDB driver is a required runtime
dependency for this provider only (a missing driver is a loud failure by design, not a silent fallback).

## Owner decisions

None. The provider and its selection/lifecycle rules are proven and ratified (ADR-0024/0025).

## Proposed conformance fixture

Covered by `docstore_contract.json` against a live MongoDB - the selection, missing-driver, bounded-
client, type-encoding and real-exercise invariants are proven here, and the query/cursor invariants use
this provider as the reference the SQLite fallback matches. No separate fixture is owed.

## Integration map

- Selected by `TINA4_MONGO_URI`/session fallbacks; realizes the 095 interface on the real driver; the
  session/cache MongoDB backends reuse the same driver-selection idiom; `close_doc_store()` bounds the
  client lifecycle.
- It is the behavioural reference the SQLite fallback (096) imitates.

## Breaking changes and migration

None outstanding. The client-lifecycle fix, the loud missing-driver, and the uniform surface already
shipped. A deployment on MongoDB speaks the proven contract.

## Implementation backlog

1. Nothing on the provider - it is proven. A missing driver must remain a loud failure (not a silent
   SQLite fallback).

## Porting capsule

Implement a MongoDB document-store provider that `get_collection` returns when a URI (`TINA4_MONGO_URI`
or the session fallbacks) is configured and the driver is present: get-or-reuse ONE MongoClient per URI
(never one per call), return the real collection with the uniform 095 method + cursor names supplied on
it (never removing a driver method), and fail LOUDLY when the URI is set but the driver is absent (never
a silent SQLite degrade). Ensure the exported ObjectId and the datetime codec encode natively. Expose
`is_serverless()` false and close every cached client on `close_doc_store()`. Prove it in
`docstore_contract.json` against a live MongoDB as the behavioural reference the SQLite fallback matches.

## Audit closure checklist

- [x] Boundary and public surface complete (the real-driver provider; interface is 095).
- [x] Lifecycle and every producer/consumer edge complete (select/reuse-client/query/close).
- [x] Configuration, failure, side-effect and security rules complete (loud missing-driver, bounded clients, type encoding).
- [x] Wire/storage and provider contracts complete (real BSON via the driver; shared value codec).
- [x] Existing-language contradictions recorded (none open; the client leak is fixed and proven).
- [x] Owner ambiguities recorded (none).
- [x] Proposed shared cases and mutation witnesses complete (the real-provider reference in `docstore_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
