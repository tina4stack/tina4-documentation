# Feature 090: Lite queue provider (file)

## Identity and status

- Matrix identity: 90 - Lite queue provider
- Audit state: decision-ready
- Audit note: proven as part of `queue_contract.json` (7/7 invariants, live-service runs; the file
  backend is the always-present control in every case). Measured 2026-08-10 against the shipped source
  and the proven fixture. No framework code changed.
- Dependencies: feature 089 (the lifecycle contract this backend realizes), the filesystem
- Dependants: every app that does not configure another backend (this is the default)
- Existing ADRs: ADR-0022/0023/0024 (via 089); ADR-0040 (Ruby's file queue adopts the canonical store
  layout)
- Shared fixtures: `queue_contract.json` (the file backend is exercised in every invariant)
- Catalog phase: Integration providers

## Why this feature exists

An application needs a working queue with zero configuration and zero dependency - `push` and `consume`
must work the moment the framework boots, before any broker is provisioned. The lite backend is a
JSON-on-disk store that implements the FULL lifecycle (priority, delay, visibility-timeout reclaim,
failure lifecycle, dead-letters, pop-by-id), so it is both the default and the reference against which
the other three backends are measured.

## Boundary

This packet owns the FILE/LITE backend: the on-disk store, the reservation/visibility reclaim, and the
full realization of every 089 lifecycle operation. The lifecycle CONTRACT is 089; the other backends
are 091-093.

## Existing implementation evidence

The file backend implements EVERY 089 operation - it is the one backend that refuses nothing:

| 089 operation | Lite/file backend |
| --- | --- |
| push (priority, delay) | full - priority highest-first, ties oldest-first; delay via a not-yet-available timestamp |
| pop / pop_batch / pop_by_id | full - reserves the highest-priority available job; addresses one job by id |
| complete / fail / reject / retry | full - the failure lifecycle writes to the store; dead-letters past max_retries |
| size / purge / retry_failed / failed / dead_letters | full - all counts and lists are real |
| visibility-timeout reclaim | full - an expired reservation is reclaimed on the next pop (at-least-once) |
| clear / close | full - `clear()` returns its count; `close()` is a no-op that is not an error |

Python is the reference for priority (it was already correct when the others lost it); the fixture's
priority and delay invariants use the file backend as the control the brokers are measured against.

## Public surface contract

The lite backend is selected by default (`TINA4_QUEUE_BACKEND` unset or `file`/`lite`). It exposes no
surface of its own beyond the 089 `Queue` contract - every method resolves and runs. The store layout
is canonical across the four (ADR-0040 brought Ruby's file queue to the same layout).

## Inputs and outputs

- Input: the 089 job payloads; a store directory (default under the app data dir).
- Output: real `Job` objects, real counts, real dead-letter lists. A popped job is reserved for
  `TINA4_QUEUE_VISIBILITY_TIMEOUT` seconds; a crashed consumer's reservation is reclaimed on the next
  pop (attempts incremented, dead-lettered past `max_retries`).

## Lifecycle and operation graph

Identical to 089, realized on disk: push writes a job record (priority + availability timestamp); pop
selects the highest-priority available, unreserved job and reserves it; complete removes it; fail
re-queues (or dead-letters); an expired reservation is reclaimed. The dead-letter is a
`<topic>.dead_letter` store found by `dead_letters()`.

## Configuration and precedence

- `TINA4_QUEUE_BACKEND` = `file`/`lite` (or unset) selects it.
- `TINA4_QUEUE_VISIBILITY_TIMEOUT` governs the reservation reclaim (default 300; `<= 0` disables).
- A store directory/path config (per framework) with a sensible default; explicit config wins.

## Failures, side effects and security

- The file backend never refuses a lifecycle operation - it implements them all, so it is the backend
  where a silent no-op would be most dangerous and where the mutation tests are strongest (removing
  Python's `ensure_connected`/unconnected-clear fix, or Ruby's file-layout, kills exactly the dependent
  cases).
- The store is world-visible on disk to the app's user; it holds job payloads. No network surface.
- `clear()`/`purge()` act ONLY on the file store when the file backend is selected (operations-reach-
  the-configured-backend, 089) - the historical bug where another backend's `clear()` hit the file
  store is fixed and locked.

## Wire and persistence contract

A JSON store on disk with the canonical layout (ADR-0040). Each job record carries payload, priority,
availability timestamp, attempt count, status, and (on dead-letter) the error text. The layout is
byte-compatible in intent across the four so the dev-admin panel and a direct reader see the same
shape.

## Providers and substitutability

This IS the default provider and the reference. Swapping to MongoDB (093) keeps the full behaviour;
swapping to a broker (091/092) keeps delivery but refuses the store-only operations (priority, delay,
pop-by-id) - the file backend is the yardstick for what "full" means.

## Contradictions and defects

No open contract defects - the file backend is fully proven. The peripheral QL-01 (dev-admin panel
reads through the backend) touches this backend's store directly and is tracked in 089. The store is
plaintext on disk (a job payload with secrets is readable by the app user) - an operational note, not a
contract defect.

## Owner decisions

None. The file backend is the proven reference; the only cross-cutting item is QL-01 (089).

## Proposed conformance fixture

Covered by `queue_contract.json` - the file backend is the control in all seven invariants. No separate
fixture is owed.

## Integration map

- Selected by default via `TINA4_QUEUE_BACKEND`; used by the dev-admin panel as the store it reads.
- Realizes the 089 lifecycle; is the reference the 091/092/093 refusals are measured against.

## Breaking changes and migration

None. ADR-0040 (Ruby's canonical file layout) already shipped; a current release uses the canonical
store.

## Implementation backlog

1. Nothing on the backend itself - it is proven. QL-01 (dev-admin reads through the backend) is tracked
   in 089.

## Porting capsule

Implement a JSON-on-disk queue backend that realizes every 089 operation: push writing a job record
with priority and an availability timestamp; pop reserving the highest-priority available job for the
visibility timeout and reclaiming an expired reservation; the full failure lifecycle (fail -> re-queue
or dead-letter); `size`/`purge`/`retry_failed`/`failed`/`dead_letters`/`pop_by_id`/`clear`/`close`, all
real. Use the canonical store layout so a direct reader and the backend agree. Prove it as the control
in `queue_contract.json` - it must refuse nothing.

## Audit closure checklist

- [x] Boundary and public surface complete (the file backend; lifecycle is 089).
- [x] Lifecycle and every producer/consumer edge complete (on-disk realization).
- [x] Configuration, failure, side-effect and security rules complete (full support, plaintext-on-disk note).
- [x] Wire/storage and provider contracts complete (canonical JSON layout, ADR-0040).
- [x] Existing-language contradictions recorded (none; fully proven; QL-01 tracked in 089).
- [x] Owner ambiguities recorded (none).
- [x] Proposed shared cases and mutation witnesses complete (the control in `queue_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
