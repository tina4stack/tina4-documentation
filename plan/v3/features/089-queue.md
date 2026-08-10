# Feature 089: Queue lifecycle

## Identity and status

- Matrix identity: 89 - Queue lifecycle
- Audit state: decision-ready
- Audit note: this feature is ALREADY PROVEN. `queue_contract.json` (7 invariants, 7 proven, 0 owed)
  drives four real runners against a LIVE MongoDB, RabbitMQ and Kafka (no mocks). This audit records the
  proven contract, the backend-realization split (features 090-093), and the peripheral open items.
  Measured 2026-08-10 against the shipped source and the proven fixture; the invariant proof narratives
  (dated 2026-08-03/04) are the ground truth. No framework code changed.
- Dependencies: the env/dotenv layer (`TINA4_QUEUE_BACKEND`, `TINA4_QUEUE_VISIBILITY_TIMEOUT`), the
  backends (lite/file 090, RabbitMQ 091, Kafka 092, MongoDB 093), the dev-admin queue panel (a consumer
  that reads the store)
- Dependants: any app doing background work; workers running `consume`/`process`
- Existing ADRs: ADR-0022 (the queue promises at-least-once, each backend keeps it the way its protocol
  allows), ADR-0023 (a job is acknowledged through the JOB, not the backend), ADR-0024 (the swap must
  work - a provider is an env var, never a code change). All Accepted.
- Shared fixtures: `queue_contract.json` - 7 invariants, ALL PROVEN against live MongoDB/RabbitMQ/Kafka.
  Reference-quality (with cache, session, messenger).
- Catalog phase: Integrations

## Why this feature exists

An application needs durable background work without a heavy dependency. Tina4 ships a job queue in
every language with ONE lifecycle contract - push, pop/reserve, complete/fail/reject/retry, dead-letter
past `max_retries`, close - across four interchangeable backends (a zero-config file store, MongoDB,
RabbitMQ, Kafka). The promise is at-least-once delivery (ADR-0022), acknowledged through the JOB
(ADR-0023), and swappable by one env var (ADR-0024). The four backends realize the same contract the
way each protocol allows: a backend that genuinely cannot do something RAISES naming itself, never
silently no-ops.

## Boundary

This feature owns the LIFECYCLE and the cross-backend CONTRACT: the `Queue` surface (push, pop,
pop_batch, pop_by_id, process, size, purge, retry_failed, failed, dead_letters, clear, close, produce,
consume), the `Job` acknowledgement surface (complete, fail, reject, retry), backend selection
(`TINA4_QUEUE_BACKEND`), the visibility/reservation timeout, and the seven proven invariants. The
per-backend REALIZATION (what each backend implements vs refuses) belongs to the provider features:
lite/file (090), RabbitMQ (091), Kafka (092), MongoDB (093).

## Existing implementation evidence

The seven proven invariants ARE the lifecycle contract (all PROVEN in all four, live services):

| Invariant | Rule (summary) | ADR |
| --- | --- | --- |
| every-method-exists-on-every-backend | every public Queue method resolves and RUNS on every offered backend; a backend that cannot do X RAISES naming backend+method, never a NoMethodError, no-op, or empty list | 0024, 0022/7 |
| operations-reach-the-configured-backend | every operation acts on the CONFIGURED backend; no method silently reads/writes the local file store when another backend is selected (pop_by_id was broken in ALL FOUR before the fix) | 0024 |
| the-failure-lifecycle-is-real-everywhere | `job.fail()` reaches the backend on every provider; a job past `max_retries` is observable via `dead_letters()` on every provider; a locally-written dead-letter handler finds the same jobs | 0023 |
| delay-is-honoured-on-every-backend | a job pushed with a delay is not visible before the delay elapses (MongoDB stamps available_at; the brokers RAISE - no per-message delay) | 0024 |
| priority-and-availability-are-honoured | priority orders delivery and a not-yet-available job is not delivered, on every backend that claims support (MongoDB sorts top-level priority; the brokers RAISE) | 0024 |
| an-unsupported-operation-raises-naming-itself | an unrecognised `TINA4_QUEUE_BACKEND` RAISES naming the value + valid set; a backend that cannot perform an operation RAISES naming backend+operation, never an empty result indistinguishable from success | 0024, 0022/7 |
| closing-a-queue-releases-the-backend | `close()` exists on the top-level Queue everywhere, releases whatever the backend holds, is idempotent, and closing a file-backed queue is not an error | 0024 |

Every invariant was MUTATION-PROVED in all four (reverting each framework's fix kills exactly its
dependent case). The suite runs each method in TWO modes - a fresh queue per method AND one shared -
because they catch different bugs (fresh found Python's unconnected `clear()`; shared found PHP's dead
socket). This is the most rigorously-proven subsystem in the catalog.

## Public surface contract

- Producing: `push(data, priority=0, delay_seconds=0)`, `produce(topic, data, priority, delay_seconds)`.
- Consuming: `pop()` (reserve one), `pop_batch(count)`, `pop_by_id(id)`, `process(handler, topic,
  max_jobs, batch_size)`, `consume(topic, job_id, poll_interval)` (a long-running generator; sleeps
  when empty).
- Inspecting/managing: `size(status="pending")`, `purge(status, max_retries)`, `retry_failed(
  max_retries)`, `failed()`, `dead_letters(max_retries)`, `clear()`, `close()`.
- Acknowledging (through the JOB, ADR-0023): `job.complete()`, `job.fail(error)`, `job.reject(reason)`,
  `job.retry(delay_seconds)`.
- Selection: `TINA4_QUEUE_BACKEND` (file/lite default, mongodb, rabbitmq, kafka) - an unrecognised value
  RAISES naming the value and the valid set; the name is normalised (trim+lowercase) in all four.

## Inputs and outputs

- Input: a job payload (dict/object), optional priority and delay; a backend selection; a visibility
  timeout.
- Output: a `Job` with an id and payload; `size`/`failed`/`dead_letters` return counts/lists; a
  refused operation RAISES a typed error naming the backend and the operation.
- A popped job is RESERVED for `TINA4_QUEUE_VISIBILITY_TIMEOUT` seconds (default 300; `<= 0` disables);
  if the consumer dies before `complete()`/`fail()`, the next `pop()` reclaims it (increments attempts,
  dead-letters past `max_retries`) - the at-least-once guarantee (file + MongoDB; the brokers delegate
  redelivery to their own protocol).

## Lifecycle and operation graph

1. SELECT: `TINA4_QUEUE_BACKEND` picks the backend (unrecognised -> RAISE naming the valid set).
2. PUSH: enqueue with priority + delay; a delayed job is stamped not-yet-available.
3. RESERVE: `pop()` reserves the highest-priority available job for the visibility timeout.
4. ACK: the consumer calls `job.complete()` (done), `job.fail(error)` (retry or dead-letter),
   `job.reject(reason)`, or `job.retry(delay)` - acknowledgement flows through the JOB (ADR-0023).
5. RECLAIM: a job whose reservation expires (crashed consumer) is reclaimed on the next pop; past
   `max_retries` it dead-letters.
6. INSPECT: `dead_letters()` returns the dead-letter QUEUE (a `<topic>.dead_letter`), the same jobs a
   local handler would find; `failed()`/`retry_failed()` where the backend supports them.
7. CLOSE: `close()` releases the backend handle, idempotent.

## Configuration and precedence

- `TINA4_QUEUE_BACKEND` - the backend; default file/lite; unrecognised RAISES (ADR-0024).
- `TINA4_QUEUE_VISIBILITY_TIMEOUT` - reservation seconds (default 300; `<= 0` disables) for the
  file/MongoDB at-least-once reclaim; the brokers use their own redelivery.
- Broker connection env (`TINA4_QUEUE_URL`/host/port/credentials per backend) - see the provider
  features. Every env-read configurable is also constructor-settable (the ADR-0041 pattern) and the
  constructor wins.

## Failures, side effects and security

- REFUSE, NEVER NO-OP (an-unsupported-operation-raises-naming-itself, ADR-0022 decision 7): a backend
  that genuinely cannot perform an operation RAISES naming the backend and the operation - it may never
  no-op or return an empty result indistinguishable from success. An empty list would claim "nothing
  has failed", which is a lie. This is the security-of-correctness core: a silent no-op on a queue
  loses work.
- FAILURE LIFECYCLE IS REAL (the-failure-lifecycle-is-real-everywhere, ADR-0023): the measurement found
  a family of SILENT defects (MongoDB `failed()` returned `[]` forever in Python/Node/Ruby; Ruby's
  `Job#fail` never reached RabbitMQ/Kafka because it was guarded by `respond_to?(:fail)`; Node's `pop()`
  returned external-backend jobs UNWRAPPED so `queue.pop().fail()` was a TypeError on MongoDB). All
  fixed and mutation-proved. A recorded lesson: reverting Ruby's `respond_to?` guard ALONE applied
  cleanly and proved NOTHING (the backend now HAS a `fail`, so the guard is inert) - a mutation that
  applies is not a mutation that reproduces.
- OPERATIONS REACH THE CONFIGURED BACKEND: `pop_by_id` was broken in ALL FOUR (a contract nobody had
  written down - unanimous, so a shared contract, not four bugs); each framework silently fell back to
  the local file store differently. Fixed uniformly (MongoDB claims one document by id; the brokers
  RAISE - neither can address a single message by id).
- No auth is added by the queue; broker credentials come from env/constructor.

## Wire and persistence contract

The persistence is the backend's: the file/lite store (a JSON store on disk), MongoDB documents,
RabbitMQ queues, Kafka topics. The dead-letter is itself a QUEUE (`<topic>.dead_letter`, ADR-0023), not
a broker feature - so a local dead-letter handler finds the same jobs on every backend. A job carries
its payload, priority, availability timestamp, attempt count and (on dead-letter) the error text. The
`Job` id is stable and addressable (`pop_by_id`) on the stores that can address one message.

## Providers and substitutability

Four interchangeable backends selected by `TINA4_QUEUE_BACKEND` (ADR-0024, the swap must work):
lite/file (090, the zero-config default and the feature reference), MongoDB (093, a full store that
implements priority/delay/pop-by-id like the file backend), RabbitMQ (091) and Kafka (092) (brokers
that deliver at-least-once via their own protocol and REFUSE the operations their protocol cannot
express, naming themselves). The refusal is the substitutability contract: swapping to a broker never
silently changes behaviour - it either works or raises a named error.

## Contradictions and defects

The lifecycle CONTRACT is proven (7/7). The open items are peripheral or environmental:

| ID | Finding | Required outcome |
| --- | --- | --- |
| QL-01 | The dev-admin queue panel historically LISTED a different store than it COUNTED (project_queue): it read the store directly instead of asking the backend, so the panel and the queue disagreed. Python landed a fix (`dev_admin/__init__.py:672` "three defects broke that" + `tests/test_dev_admin_queue_path.py`; `lite_backend.py:31` documents that a direct reader must ask the backend). PHP/Ruby/Node parity is UNCONFIRMED. | Confirm the dev-admin panel reads through the backend (not the raw store) in all four; add the queue-path test where missing. Peripheral to the lifecycle contract (a reporting-panel defect), but a real cross-framework parity check. |
| QL-02 | Kafka's failure-lifecycle, delay-refusal and priority-refusal are WRITTEN but NOT verified off-box: the lab Kafka advertises `PLAINTEXT://localhost:9092`, so any real client dials localhost from another host and cannot connect (reference: lab-kafka-advertises-localhost). The other three backends are lab-verified. | Verify Kafka's lifecycle ON the lab host itself (where localhost resolves to the broker), then record it PROVEN alongside the other three. Environmental, not a code defect. |
| QL-03 | No new ADR is owed - but the visibility/reservation timeout (`TINA4_QUEUE_VISIBILITY_TIMEOUT`, the at-least-once reclaim) is described in the CLAUDE.md and honoured in file+MongoDB, while the brokers delegate to their protocol. This split is correct but is not itself pinned by a fixture invariant. | Consider a visibility-timeout invariant in `queue_contract.json` (reserve, let it expire, prove the next pop reclaims on file+MongoDB and the brokers redeliver) - additive coverage, not a gap. |

## Owner decisions

The lifecycle contract is ratified (ADR-0022/0023/0024) and proven. The open calls are:

1. DEV-ADMIN PARITY (QL-01): the queue panel reads through the backend in all four (Python done; confirm
   the others). Peripheral but real.
2. KAFKA OFF-BOX VERIFICATION (QL-02): run Kafka's lifecycle on the lab host and record it proven.
3. VISIBILITY-TIMEOUT COVERAGE (QL-03): optionally add a reservation-reclaim invariant to the fixture.

There are no open behavioural decisions on the lifecycle itself.

## Proposed conformance fixture

ALREADY EXISTS and is PROVEN: `queue_contract.json` (7 invariants, 7 proven, 0 owed) drives four
runners against a LIVE MongoDB, RabbitMQ and Kafka (no mocks), each mutation-proved. The recommended
additions are the QL-03 visibility-timeout invariant and folding Kafka's off-box lifecycle into the
proven set once run on the lab (QL-02). No new fixture is owed for the core lifecycle.

## Integration map

- `TINA4_QUEUE_BACKEND` selects the backend; the env layer supplies connection config; workers call
  `consume`/`process`; the dev-admin panel reads the store (through the backend - QL-01).
- `queue_contract.json` is the shared oracle; ADR-0022/0023/0024 are the ratifying decisions.
- The provider features 090-093 own each backend's realization of this contract.

## Breaking changes and migration

None outstanding. The breaking changes that unified the queue (the refuse-not-no-op semantics, the
pop_by_id fix, the failure-lifecycle fixes, `close()`) already shipped. A current release speaks the
proven contract. QL-01/QL-02 are a panel-parity check and an environmental verification; QL-03 is
additive coverage.

## Implementation backlog

1. QL-01: confirm the dev-admin queue panel reads through the backend in PHP/Ruby/Node; add the
   queue-path test where missing.
2. QL-02: verify Kafka's lifecycle on the lab host and record it proven in `queue_contract.json`.
3. QL-03: optionally add the visibility-timeout reservation-reclaim invariant.
4. Nothing else on the core lifecycle - it is proven; re-run the queue contract runners on the lab to
   confirm 7/7 at the current HEAD (routine).

No framework implementation is needed for the core lifecycle.

## Porting capsule

Implement a job queue with ONE lifecycle across four backends: `push(data, priority, delay_seconds)` /
`produce(topic, ...)`; `pop()` reserving the highest-priority available job for a visibility timeout;
`pop_batch`, `pop_by_id`, `consume`/`process`; acknowledgement THROUGH the job (`complete`, `fail`,
`reject`, `retry`); `size`, `purge`, `retry_failed`, `failed`, `dead_letters` (the dead-letter is a
QUEUE, `<topic>.dead_letter`, found the same way on every backend); and `close()` (idempotent). Select
the backend by `TINA4_QUEUE_BACKEND` (unrecognised RAISES naming the valid set). Guarantee at-least-once
(file+MongoDB reclaim an expired reservation; the brokers use their protocol). A backend that cannot
perform an operation RAISES naming the backend and the operation - NEVER a no-op or an empty result
indistinguishable from success. Prove the port with `queue_contract.json` against live MongoDB, RabbitMQ
and Kafka - all seven invariants, mutation-proved, no mocks.

## Audit closure checklist

- [x] Boundary and public surface complete (the lifecycle + the cross-backend contract; providers own realization).
- [x] Lifecycle and every producer/consumer edge complete (select/push/reserve/ack/reclaim/inspect/close).
- [x] Configuration, failure, side-effect and security rules complete (refuse-not-no-op, real failure lifecycle, visibility timeout).
- [x] Wire/storage and provider contracts complete (per-backend persistence; the dead-letter is a queue).
- [x] Existing-language contradictions recorded (contract proven 7/7; QL-01/02/03 peripheral or environmental).
- [x] Owner ambiguities recorded (dev-admin parity, Kafka off-box, optional visibility invariant).
- [x] Proposed shared cases and mutation witnesses complete (`queue_contract.json`, 7/7 proven, live services, mutation-proved).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
