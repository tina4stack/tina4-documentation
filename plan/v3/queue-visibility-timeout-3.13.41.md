# 3.13.41 — Queue reservation / visibility timeout (at-least-once delivery)

## The bug
A consumer that reserves a message via `queue.consume()`/`pop()` and then dies
before `job.complete()` (crash, OOM, k8s pod eviction) strands the message:
- **File/lite backend**: `pop()` DELETES the pending file on claim. `complete()`
  is a no-op. The job is gone outright — never re-delivered, retried, or
  dead-lettered.
- **MongoDB backend**: `dequeue` flips `status -> reserved` (or `processing`) but
  does NOT advance `available_at`, and the selection predicate only matches
  `pending`. The doc stays `reserved` forever with `attempts = 0`.

Silent data loss in any multi-replica / rolling-deploy (Kubernetes) setup.

## Canonical fix (Python master = tina4-python)
Reference implementation (read these):
- `tina4_python/queue/lite_backend.py` — file backend reserve + reclaim
- `tina4_python/queue_backends/mongo_backend.py` — MongoConnector dequeue + reclaim_expired
- `tina4_python/queue/mongo_backend.py` — adapter calls reclaim_expired before dequeue
- `tina4_python/queue/__init__.py` — Queue(visibility_timeout=) + env + plumbing
- tests: `tests/test_queue.py` (TestVisibilityTimeout), `tests/test_queue_backends.py`

### Behaviour (must be identical across all 4 frameworks)
1. **Config**: `Queue(visibility_timeout=)` constructor param (seconds, float).
   Falls back to env `TINA4_QUEUE_VISIBILITY_TIMEOUT`, else **300** (5 min).
   `<= 0` disables the reclaim (a reservation then lasts until the consumer acks
   — the old behaviour, opt-out). Thread it into the file + mongo backends.
2. **File/lite backend** gains a `reserved/` subdir per topic:
   - `pop()`/`popBatch()`: FIRST reclaim expired reservations, THEN for each
     pending candidate write a reservation record `reserved/{id}` (status
     `reserved`, `reserved_at = now`, `available_at = now + visibility_timeout`)
     and THEN claim the pending file (delete). Only the claim-winner returns the
     job. (Write-reserved-before-claim so a crash mid-pop can't lose the job.)
   - **reclaim**: a reserved record with `available_at <= now` means the consumer
     died. Atomically claim it, increment `attempts`; if `attempts >= max_retries`
     dead-letter it, else re-enqueue to pending. Disabled when timeout <= 0.
   - `complete()` / `fail()` / `retry()`: delete the `reserved/{id}` record
     (complete = done; fail/retry already requeue/dead-letter).
   - `size("reserved")` counts the reserved dir; `clear()` clears it too.
3. **MongoDB backend**:
   - `dequeue`: the claim `$set` advances `available_at = now + visibility_timeout`
     and records `reserved_at = now` (the core fix).
   - `reclaim_expired(topic, max_retries)`: atomically flip each
     `{status: reserved, available_at <= now}` back to `pending` with
     `$inc attempts`; once `attempts >= max_retries` dead-letter + delete it.
     Called by `pop()` before `dequeue`. Disabled when timeout <= 0.
4. **RabbitMQ / Kafka**: accept the `visibility_timeout` param and ignore it —
   the broker owns redelivery (unacked requeue / consumer-group offsets).

### Tests (so we do not regress — the reporter asked explicitly)
File/lite backend, deterministic (small visibility_timeout + short sleep):
- reserve-then-abandon is reclaimed after the timeout, `attempts == 1`
- not reclaimed before the timeout (second consumer gets nothing)
- reclaim past `max_retries` dead-letters instead of re-delivering
- `complete()` (and `fail()`) clear the reservation (no phantom reclaim)
- default 300 + `TINA4_QUEUE_VISIBILITY_TIMEOUT` env override
- `visibility_timeout=0` disables reclaim (reservation stays)
Mongo (mock the collection where there is no live mongo): dequeue advances
`available_at` + sets `reserved_at`; reclaim requeues under the limit /
dead-letters past it / is a no-op at 0.

## Status
- Python master: DONE + committed `f92fad7` on feature/release3.13.41 (full suite 3250 green, ruff clean).
- Mirror: PHP / Ruby / Node (file + mongo backends + tests) — in flight.
- Release: 3.13.41, then delete feature/release3.13.40 + 3.13.41 branches.
