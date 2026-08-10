# Feature 093: MongoDB queue provider

## Identity and status

- Matrix identity: 93 - MongoDB queue provider
- Audit state: decision-ready
- Audit note: proven as part of `queue_contract.json` (7/7 invariants, verified against a LIVE
  MongoDB). MongoDB is the one non-file backend that implements the FULL lifecycle, so it is the
  parity target the fixture uses to prove priority/delay/pop-by-id on a real store. Measured 2026-08-10
  against the shipped source and the proven fixture. No framework code changed.
- Dependencies: feature 089 (the lifecycle contract), a MongoDB server, the MongoDB driver
- Dependants: apps that want a durable, queryable queue without a broker
- Existing ADRs: ADR-0022 (at-least-once), ADR-0023 (dead-letter is a queue), ADR-0024 (the swap)
- Shared fixtures: `queue_contract.json` (MongoDB is a live backend and the full-store control for
  priority/delay/pop-by-id)
- Catalog phase: Integration providers

## Why this feature exists

An application wants a durable, queryable work queue without standing up a broker. The MongoDB backend
implements the FULL 089 lifecycle - priority, delay, visibility-timeout reclaim, pop-by-id, the failure
lifecycle with dead-letters - exactly like the file backend but in a shared, networked store. It is the
proof that a non-file backend can be a real queue, and the fixture uses it as the control for the
store-only operations the brokers refuse.

## Boundary

This packet owns the MongoDB REALIZATION of the 089 contract: the document store, the atomic
claim-one-document reserve, priority/delay via document fields, and the full failure lifecycle. The
lifecycle contract is 089.

## Existing implementation evidence

MongoDB implements EVERY 089 operation - the only non-file backend that refuses nothing (all PROVEN):

| 089 operation | MongoDB backend |
| --- | --- |
| push (priority, delay) | full - priority stored TOP-LEVEL and sorted highest-first, ties oldest-first; delay stamps `available_at` in the future, which every dequeue filters on |
| pop / pop_batch / pop_by_id | full - atomically claims one document (so a crashed consumer's job is still reclaimed); `pop_by_id` claims one document by id exactly as the head claim does |
| complete / fail / reject / retry | full - the failure lifecycle updates the document; dead-letters carry the attempt count AND the error text (both were lost before the fix) |
| failed() / retry_failed() / dead_letters() | full - `failed()` now queries correctly (it once queried `status="failed"` which the retryable path never writes, returning `[]` forever in Python/Node/Ruby) |
| size / purge / clear | full - `clear()` connects first (Python's once did not); `purge` by status is real |
| visibility-timeout reclaim | full - an expired reservation is reclaimed on the next pop (at-least-once) |
| close() | full - releases the client; idempotent. NODE EXCEPTION: Node's Mongo backend spawns a CHILD PROCESS per operation, each closing its own client, so `close()` releases nothing by design and says so in code (ADR-0022) - a handle assertion there would be theatre |

MongoDB is the fixture's control for priority-and-availability and delay-is-honoured: the brokers refuse
those, the file and MongoDB backends must prove them.

## Public surface contract

Selected by `TINA4_QUEUE_BACKEND=mongodb`. No surface beyond the 089 `Queue` contract - every method
resolves and runs (it refuses nothing). Connection via a Mongo URI, constructor-settable and
env-configurable (constructor wins).

## Inputs and outputs

- Input: 089 job payloads; a Mongo URI.
- Output: real `Job` objects, priority-ordered delivery, delay honoured, `pop_by_id` claiming one
  document, real dead-letters with attempt count and error text. A popped job is reserved for the
  visibility timeout; a crashed consumer's reservation is reclaimed.

## Lifecycle and operation graph

Identical to 089, realized as documents: push inserts a job document (top-level priority + `available_at`
timestamp); pop atomically claims the highest-priority available, unreserved document and reserves it;
complete removes it; fail updates attempts (or dead-letters, preserving attempts + error); an expired
reservation is reclaimed. The dead-letter is a `<topic>.dead_letter` collection found by
`dead_letters()`.

## Configuration and precedence

- `TINA4_QUEUE_BACKEND=mongodb` + the Mongo URI. Every value is constructor-settable and the
  constructor wins. A failed connect RAISES.

## Failures, side effects and security

- FULL SUPPORT, NO REFUSALS: MongoDB is the non-file backend that implements everything, so the
  measured defects here were all SILENT wrong-answers, not refusals: `failed()` returning `[]` forever
  (wrong query), dead-letters losing the attempt count and error, `clear()` not connecting first,
  priority stored where a sort could not reach it, delay never filtered. All fixed and mutation-proved.
- ATOMIC CLAIM: the reserve is an atomic claim-one-document, so two consumers never get the same job and
  a crashed consumer's job is reclaimed - the at-least-once guarantee on a shared store.
- NODE CHILD-PROCESS MODEL: Node spawns a child process per Mongo operation (each closes its own
  client), so `close()` releases nothing and the fixture asserts no retained handle there (ADR-0022) -
  a deliberate design, documented in code.
- The Mongo URI (with credentials) is the security surface; the transport uses the configured Mongo TLS.

## Wire and persistence contract

MongoDB documents: each job is a document with payload, TOP-LEVEL priority, `available_at`, attempt
count, status, and (on dead-letter) the error text. The dead-letter is a `<topic>.dead_letter`
collection. Priority is stored top-level (not inside a sub-document) precisely so the dequeue sort can
reach it - a fixed defect where PHP/Ruby buried it and sorted on `created_at` alone.

## Providers and substitutability

The full-store alternative to the file backend (090) and the counterpoint to the brokers (091/092):
MongoDB proves a networked, shared store can be a complete queue. Swapping between file and MongoDB
keeps ALL behaviour; swapping to a broker loses the store-only operations (which then refuse). MongoDB
is the fixture's evidence that the store-only invariants are real, not file-backend accidents.

## Contradictions and defects

No open contract defects - MongoDB is fully proven and refuses nothing. The Node child-process-per-op
model (close releases nothing) is a documented design choice, not a defect. The MongoDB driver is a
required runtime dependency for this backend only (lazy-loaded; a missing driver is a clear error, not
a silent fallback to the file store).

## Owner decisions

None. The realization is proven; the only cross-cutting queue items are QL-01/QL-02 in 089 (neither is
MongoDB-specific - MongoDB is lab-verified).

## Proposed conformance fixture

Covered by `queue_contract.json` against a live MongoDB - MongoDB is the full-store control for the
priority, delay and pop-by-id invariants, all mutation-proved. No separate fixture is owed.

## Integration map

- Selected by `TINA4_QUEUE_BACKEND=mongodb`; realizes the full 089 lifecycle as documents; the
  dead-letter is a collection.
- The MongoDB driver is the one optional dependency (lazy-loaded).
- It is the fixture's control for the store-only invariants the brokers refuse.

## Breaking changes and migration

None outstanding. The priority-top-level fix, the delay filter, the correct `failed()` query, the
attempt-count+error dead-letters, and `pop_by_id` all shipped. A deployment on MongoDB speaks the proven
full contract.

## Implementation backlog

1. Nothing on the backend - it is fully proven. A missing driver must remain a clear error (not a
   silent file-store fallback).

## Porting capsule

Implement a MongoDB backend that realizes the FULL 089 lifecycle as documents: push inserting a job
document with TOP-LEVEL priority and an `available_at` timestamp; pop atomically claiming the
highest-priority available, unreserved document (ties oldest-first) and reserving it for the visibility
timeout; `pop_by_id` claiming one document by id; the full failure lifecycle (fail updates attempts or
dead-letters, preserving attempt count AND error text; `failed()` queries the right state); `size`,
`purge`, `clear` (connect first), `dead_letters` (a `<topic>.dead_letter` collection), and `close()`
(idempotent). Reclaim an expired reservation on the next pop. Refuse NOTHING - MongoDB is the full-store
control. Load the driver lazily; a failed connect RAISES. Prove it in `queue_contract.json` against a
live MongoDB as the control for priority, delay and pop-by-id.

## Audit closure checklist

- [x] Boundary and public surface complete (the MongoDB realization; lifecycle is 089).
- [x] Lifecycle and every producer/consumer edge complete (document store, atomic claim, dead-letter collection).
- [x] Configuration, failure, side-effect and security rules complete (full support, atomic claim, Node child-process model).
- [x] Wire/storage and provider contracts complete (documents, top-level priority, dead-letter collection).
- [x] Existing-language contradictions recorded (none open; all silent wrong-answers fixed and proven).
- [x] Owner ambiguities recorded (none MongoDB-specific).
- [x] Proposed shared cases and mutation witnesses complete (the full-store control in `queue_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
