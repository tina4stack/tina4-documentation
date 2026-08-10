# Feature 092: Kafka queue provider

## Identity and status

- Matrix identity: 92 - Kafka queue provider
- Audit state: decision-ready
- Audit note: the Kafka realization is WRITTEN and mutation-proved in the fixture logic, but its live
  lifecycle is NOT yet verified off-box (QL-02): the lab Kafka advertises `PLAINTEXT://localhost:9092`,
  so a client on another host cannot connect (reference: lab-kafka-advertises-localhost). The other
  three backends are lab-verified. Measured 2026-08-10 against the shipped source and the proven
  fixture. No framework code changed.
- Dependencies: feature 089 (the lifecycle contract), a Kafka broker, the Kafka client library
- Dependants: apps that route work through Kafka
- Existing ADRs: ADR-0022 (at-least-once the way the protocol allows; decision 5 kafka size()->0,
  decision 8 Node-refuses-at-construction), ADR-0023, ADR-0024
- Shared fixtures: `queue_contract.json` (Kafka is a backend in the invariants; its live verification is
  QL-02)
- Catalog phase: Integration providers

## Why this feature exists

An application already running Kafka wants its work stream on that broker. The Kafka backend delivers
the 089 lifecycle AT-LEAST-ONCE via offset commit, and REFUSES - naming itself - the operations a
partition-ordered log cannot express (priority, per-message delay, address-by-id), so a swap to Kafka
never silently changes behaviour.

## Boundary

This packet owns the Kafka REALIZATION of the 089 contract: produce/consume/offset-commit, the
offset-rewind dead-letter answer, `size()->0`, and the explicit refusals. The lifecycle contract is
089.

## Existing implementation evidence

The Kafka backend's implement-vs-refuse matrix (written + mutation-proved; live verification is QL-02):

| 089 operation | Kafka backend |
| --- | --- |
| push / produce | full (produce to the topic; delivery is at-least-once via offset commit) |
| pop / consume + complete/fail/reject | full - complete commits the offset, fail re-delivers; `job.fail()` reaches the broker (Ruby's `respond_to?` guard is fixed) |
| dead_letters() | ANSWERED via offset rewind-and-restore (read the `<topic>.dead_letter` records, restore the offset), verified stable across reads |
| size() | returns 0 (ADR-0022 decision 5) - a Kafka topic has no queryable pending count; 0 is the honest answer Python and PHP already gave and Ruby now gives |
| priority | REFUSES naming itself - Kafka has no priority concept; a partition is read in offset order |
| delay | REFUSES naming itself - a consumer reads a partition in offset order, there is no per-message delay |
| pop_by_id | REFUSES naming itself - a log cannot address a single record by an app id |
| failed() / retry_failed() | REFUSE naming itself - a retryable failure re-publishes to the MAIN topic, indistinguishable from pending |
| close() | full - releases the producer/consumer; idempotent |

Every refusal NAMES the backend and the operation (ADR-0022 decision 7) - never an empty list. Node
satisfies the refusal half at CONSTRUCTION (ADR-0022 decision 8).

## Public surface contract

Selected by `TINA4_QUEUE_BACKEND=kafka`. No surface beyond the 089 `Queue` contract; the difference is
`size()->0` and which operations RAISE. Connection via broker list + credentials, constructor-settable
and env-configurable (constructor wins).

## Inputs and outputs

- Input: 089 job payloads; the Kafka broker connection config.
- Output: at-least-once delivery via offset commit; `size()` returns 0; a typed REFUSAL for
  priority/delay/pop_by_id/failed/retry_failed; a rewind-based `dead_letters()` answer.

## Lifecycle and operation graph

Produce to the topic; a consumer reads in offset order; `complete()` commits the offset; `fail()`
re-delivers (or writes the `<topic>.dead_letter` records past `max_retries`). Redelivery on a crashed
consumer is the broker's (uncommitted offsets are re-read) - the framework visibility timeout does not
apply. A recorded wire caveat: Kafka 4.x dropped Produce v0-v2, so three of the four frameworks
hand-roll a RecordBatch v2 encoder (reference: kafka-recordbatch-v2) rather than depend on a client
that still speaks the old protocol.

## Configuration and precedence

- `TINA4_QUEUE_BACKEND=kafka` + the broker list/credentials. Every value is constructor-settable and
  the constructor wins. A failed connect RAISES.

## Failures, side effects and security

- REFUSE, NAMING ITSELF: priority, delay, pop_by_id, failed(), retry_failed() all raise a typed error
  naming the backend and the operation - never a no-op or an empty list.
- HONEST size()->0 (ADR-0022 decision 5): a Kafka topic has no queryable pending count, so 0 is the
  correct answer, not a guess or an error.
- OFF-BOX VERIFICATION GAP (QL-02): the lifecycle is written and mutation-proved in logic but the LIVE
  Kafka path is unverified because the lab broker advertises localhost. This must be run ON the lab host
  (where localhost is the broker) before Kafka is recorded fully proven alongside the other three.
- Broker credentials are the security surface; the transport uses the configured Kafka TLS/SASL.

## Wire and persistence contract

Kafka: records produced to a topic, consumed in offset order, acked by offset commit. The dead-letter
is a `<topic>.dead_letter` set of records (framework-written), read by offset rewind-and-restore.
Persistence and redelivery are the broker's. The RecordBatch v2 encoding is hand-rolled where the
client library does not cover Kafka 4.x.

## Providers and substitutability

The second BROKER backend (with RabbitMQ 091). It delivers at-least-once and refuses the store-only
operations the file (090) and MongoDB (093) backends implement, plus returns `size()->0`. The refusals
and the honest 0 are the substitutability contract.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| QL-02 (this backend) | Kafka's live lifecycle is unverified off-box because the lab broker advertises `PLAINTEXT://localhost:9092`; a client on another host cannot connect. The logic is written and mutation-proved; the live run is missing. | Run Kafka's lifecycle ON the lab host itself, then record Kafka PROVEN in `queue_contract.json` alongside MongoDB and RabbitMQ. Environmental, not a code defect. |

The Kafka client library is a required runtime dependency for this backend only (lazy-loaded; a missing
library is a clear error). The RecordBatch v2 hand-roll is a wire-compatibility measure, not a defect.

## Owner decisions

1. KAFKA OFF-BOX VERIFICATION (QL-02): run the lifecycle on the lab host and record it proven. No
   behavioural decision is open - the refusals and `size()->0` are ratified by ADR-0022.

## Proposed conformance fixture

Covered by `queue_contract.json` - the refusals and `size()->0` are mutation-proved; the live Kafka run
is the QL-02 completion, not a new fixture.

## Integration map

- Selected by `TINA4_QUEUE_BACKEND=kafka`; realizes the 089 lifecycle over Kafka; the dead-letter is a
  framework record set read by offset rewind.
- The Kafka client library is the one optional dependency (lazy-loaded); the RecordBatch v2 encoder is
  hand-rolled for Kafka 4.x.

## Breaking changes and migration

None outstanding. The refuse-not-no-op semantics, `size()->0`, and the offset-rewind dead-letter
already shipped. A deployment on Kafka speaks the written contract; QL-02 is a verification, not a
change.

## Implementation backlog

1. QL-02: verify Kafka's lifecycle on the lab host and record it proven.
2. Nothing else on the backend - the logic is written and mutation-proved.

## Porting capsule

Implement a Kafka backend that realizes the 089 lifecycle at-least-once via offset commit: produce on
push; consume in offset order; `complete()` commits, `fail()` re-delivers (writing `<topic>.dead_letter`
records past max_retries); answer `dead_letters()` by offset rewind-and-restore; return `size()->0`
(honest - no queryable pending count). REFUSE - naming the backend and the operation - priority, delay,
pop_by_id, failed()/retry_failed(). Hand-roll RecordBatch v2 if the client does not speak Kafka 4.x.
Load the client lazily; a failed connect RAISES. Prove it in `queue_contract.json` ON the lab host
(localhost resolves to the broker there).

## Audit closure checklist

- [x] Boundary and public surface complete (the Kafka realization; lifecycle is 089).
- [x] Lifecycle and every producer/consumer edge complete (produce/consume/offset-commit/dead-letter).
- [x] Configuration, failure, side-effect and security rules complete (refuse-naming-itself, honest size 0, off-box gap).
- [x] Wire/storage and provider contracts complete (Kafka offsets; RecordBatch v2 hand-roll; framework dead-letter records).
- [x] Existing-language contradictions recorded (QL-02 off-box verification is the one open item).
- [x] Owner ambiguities recorded (QL-02 only; refusals ratified).
- [x] Proposed shared cases and mutation witnesses complete (mutation-proved logic; live run is QL-02).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
