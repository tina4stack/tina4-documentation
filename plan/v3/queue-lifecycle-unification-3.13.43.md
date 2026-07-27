# 3.13.43 - Unified queue lifecycle across all 4 frameworks

## Why

A live MongoDB producer/consumer test (Python master) surfaced four queue bugs
(consume-topic ignored; Mongo retry stall; Mongo attempts snapshot; dead_letters
TypeError). Mirroring them exposed the real problem: **the four frameworks run
three different queue-lifecycle architectures**, and Node's is broken.

The job lifecycle is: `pop` reserves a job, then the consumer calls `complete()`
(ack and remove), `fail()` (requeue while retries remain, else dead-letter), or
`retry()`. A reserved job that is never acked is reclaimed after the visibility
timeout and re-delivered (at-least-once). So **`complete()` MUST ack the same
store the job was popped from.**

Current state:

| Framework | pop reserves on | complete() acks | fail()/retry()/deadLetters route to |
|---|---|---|---|
| Python (reference) | active backend | active backend | active backend |
| Ruby | active backend | active backend | active backend |
| PHP | active backend | **active backend** | lite backend / no-op for external |
| Node | active backend | **lite backend only** | lite backend only |

Python and Ruby are correct: one active backend owns the whole lifecycle.

PHP is half-right: `complete()` acks the external (Mongo) backend, but `fail()`
returns early for external backends and `deadLetters()`/`retryFailed()`/`failed()`
read the lite backend. So a Mongo job that fails is not requeued or dead-lettered
through Mongo, and `queue.deadLetters()` inspects the wrong store.

Node is broken: the external `QueueBackendInterface` is only
`push/pop/size/clear` - there is **no ack operation at all** - and every lifecycle
method routes to the lite (file) backend. Proven live against MongoDB: push -> pop
-> complete -> wait past the visibility window -> the same job re-pops with
`attempts: 1`. **Every completed job on Node's Mongo queue is re-delivered.**
Pre-existing since 3.13.41; the Node Mongo tests are mock-based, so the
complete-then-no-redelivery cycle was never exercised.

## Target contract (the Python/Ruby active-backend model, for all 4)

The active backend (whatever `TINA4_QUEUE_BACKEND` selects) owns the full
lifecycle. The Queue routes every lifecycle call to it. The lite/file backend is
just one backend among several, not a lifecycle coordinator behind the others.

Every backend implements (framework-idiomatic names; Node shown):
- `push(queue, payload, delay?, priority?)`
- `pop(queue)` - reserve with `availableAt = now + visibilityTimeout`
- `complete(queue, id)` / ack - drop the reservation so reclaim never re-delivers
- `reject(queue, id, requeue)` - requeue (reset availableAt, ++attempts) or fail
- `deadLetters(queue, maxRetries)` / `retryFailed(queue, maxRetries)` / `failed(queue, maxRetries)`
- `size(queue, status?)`, `clear(queue)`, `purge(queue, status, maxRetries)`
- `reclaim(queue, maxRetries)` - reclaim expired reservations (already present)

### Per-backend behaviour rules

- **file (lite) + mongodb**: framework-managed full lifecycle. `complete` acks,
  `fail` requeues (reset availableAt to now/now+retryBackoff) or dead-letters at
  `maxRetries`, reclaim re-delivers abandoned reservations. This is the model my
  Python 3.13.43 fixes already implement and Ruby already follows.
- **rabbitmq + kafka**: the broker owns redelivery (unacked messages requeue on
  channel close / consumer-group offsets). The framework still exposes a
  `<topic>.dead_letter` queue/topic for `deadLetters()`/`retryFailed()` (Python's
  rabbit/kafka adapters already do this). `complete` acks via the broker; `fail`
  at `maxRetries` publishes to the dead-letter topic. These were the Bug-D
  signature gaps already fixed in Python master for rabbit/kafka.

## Work per framework

### Node (largest - has the proven bug)
1. Expand `QueueBackendInterface` (queue.ts:99) beyond push/pop/size/clear to the
   full lifecycle: `complete`/ack, `reject`/requeue, `deadLetters`, `retryFailed`,
   `failed`, `purge` (+ existing reclaim).
2. Implement those ops on the **Mongo backend** (mongoBackend.ts): add `complete`
   (delete or mark completed + clear reservation), `reject` (reset availableAt +
   ++attempts, or dead-letter at maxRetries), `deadLetters`/`retryFailed`/`failed`
   (over a `<queue>.dead_letter` collection topic), `purge`. The script needs new
   ops: `complete`, `reject`, `deadLetter`, `deadLetters`, `retryFailed`, `purge`.
3. Implement on **rabbitmq + kafka** backends: `complete` = broker ack; `reject` =
   broker requeue / dead-letter-topic at maxRetries; dead-letter-topic reads for
   deadLetters/retryFailed/failed (mirror Python's broker adapters).
4. Wire `queue.ts` `_completeJob`/`_failJob`/`_retryJob`/`deadLetters`/`retryFailed`/
   `failed`/`purge` to route to `externalBackend` when present, lite otherwise.
5. Live-verify against MongoDB (the running `mongo:7`): push/pop/complete -> NO
   redelivery; fail -> requeue then dead-letter at maxRetries; topic isolation;
   reclaim still works. Add tests (mock-based for CI + a live-gated path).

### PHP (medium - complete already correct)
1. Route `Queue::failJob`/`retryJob`/`deadLetters`/`retryFailed`/`failed`/`purge`
   to the external backend when present (today they return early or hit lite).
2. The Mongo backend lifecycle methods (failed/deadLetters/retryFailed + requeue
   reset) mostly exist from the mirror; fill any gaps + the dead-letter path.
3. rabbit/kafka broker-delegated as above.
4. Verify. Local ext-mongodb is NOT installed (12 Mongo tests skip) - either
   install the extension to live-verify, or verify via the existing
   FakeMongoCollection stub harness + code review; state which was used.

### Ruby + Python (reference - confirm)
- Python: reference, done (4 bugs fixed, verified live).
- Ruby: confirm `complete`/`fail`/`dead_letters` all route to `@backend` and ack
  Mongo; live-verify against MongoDB (mongo gem permitting).

## Verification plan
- Live MongoDB producer/consumer/complete/fail/dead-letter/topic test per
  framework where the driver is installed (Python done; Node driver present;
  Ruby/PHP driver TBD).
- Full suite green per framework, re-run by me (not agent self-report).
- Cross-framework parity: identical lifecycle semantics on the Mongo backend.

## Decisions (defaults, flag if owner disagrees)
- Keep rabbit/kafka broker-delegated for redelivery (do NOT reimplement broker
  redelivery in-framework); framework owns only the dead-letter topic. Matches
  Python's existing design.
- This is behaviour-corrective, backward compatible (no API removal). Ships as
  3.13.43 across all 4 once every framework's Mongo lifecycle is verified live.
- `complete()` acking the active backend is the contract; the lite backend stops
  being a hidden lifecycle coordinator behind external backends.

## Status
Python master: DONE (4 bugs + rabbit/kafka Bug-D, full suite 3280, live-verified)
on feature/release3.13.43. Ruby/PHP: mirror landed (Bug A/B/C/D) but lifecycle
routing NOT yet unified. Node: Bug A fixed; lifecycle unification NOT yet done
(the redelivery bug is still live). Release HELD until all 4 unified + verified.
