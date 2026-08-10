# Feature 091: RabbitMQ queue provider

## Identity and status

- Matrix identity: 91 - RabbitMQ queue provider
- Audit state: decision-ready
- Audit note: proven as part of `queue_contract.json` (7/7 invariants, verified against a LIVE
  RabbitMQ). Measured 2026-08-10 against the shipped source and the proven fixture. No framework code
  changed.
- Dependencies: feature 089 (the lifecycle contract), a RabbitMQ broker, the AMQP client library
  (bunny/php-amqplib/amqplib; Python via its AMQP client)
- Dependants: apps that route work through RabbitMQ
- Existing ADRs: ADR-0022 (at-least-once the way the protocol allows; decisions 7 refuse-not-empty-list,
  8 Node-refuses-at-construction), ADR-0023, ADR-0024
- Shared fixtures: `queue_contract.json` (RabbitMQ is a live backend in the invariants)
- Catalog phase: Integration providers

## Why this feature exists

An application already running RabbitMQ wants its work queue on that broker. The RabbitMQ backend
delivers the 089 lifecycle AT-LEAST-ONCE via the broker's own ack protocol, and REFUSES - naming itself
- the operations RabbitMQ's protocol cannot express, so a swap to RabbitMQ never silently changes
behaviour.

## Boundary

This packet owns the RabbitMQ REALIZATION of the 089 contract: connect/publish/consume/ack, the
non-destructive dead-letter answer, and the explicit refusals. The lifecycle contract is 089.

## Existing implementation evidence

The RabbitMQ backend's implement-vs-refuse matrix (all PROVEN):

| 089 operation | RabbitMQ backend |
| --- | --- |
| push / produce | full (publish to the topic; delivery is at-least-once via broker ack) |
| pop / consume + complete/fail/reject | full - complete acks, fail nacks/re-publishes; `job.fail()` reaches the broker (Ruby's `respond_to?` guard that swallowed this is fixed) |
| dead_letters() | ANSWERED non-destructively - drains the `<topic>.dead_letter` QUEUE and republishes, verified stable across three consecutive reads (NOT the broker's own DLX) |
| priority | REFUSES naming itself - native priority needs the queue DECLARED with `x-max-priority`, which an existing queue cannot be redeclared with (PRECONDITION_FAILED), so enabling it would break every queue in service |
| delay | REFUSES naming itself - the delayed-message-exchange is a non-core plugin and the TTL+dead-letter workaround head-of-line blocks |
| pop_by_id | REFUSES naming itself - AMQP cannot address a single message by id |
| purge-by-status | REFUSES naming itself |
| failed() / retry_failed() | REFUSE naming itself - a retryable failure is re-published to the MAIN topic where it cannot be told apart from pending work |
| size() | the broker-appropriate answer (a message count where available) |
| close() | full - releases the channel/connection; idempotent (Ruby's double-close ChannelAlreadyClosed is fixed with ensure-nil) |

Every refusal NAMES the backend and the operation and explains what to use instead (ADR-0022 decision
7) - never an empty list, which would falsely claim nothing has failed. Node satisfies the refusal half
at CONSTRUCTION (ADR-0022 decision 8): its RabbitMQ backend refuses the store-only operations up front.

## Public surface contract

Selected by `TINA4_QUEUE_BACKEND=rabbitmq`. No surface beyond the 089 `Queue` contract; the difference
is which operations RAISE. Connection via a broker URL/host/port/credentials (`amqp_url` helper in
Python), constructor-settable and env-configurable (constructor wins).

## Inputs and outputs

- Input: 089 job payloads; the broker connection config.
- Output: at-least-once delivery; real `complete`/`fail` acks; a non-destructive `dead_letters()`
  answer; a typed REFUSAL (naming backend + operation) for priority/delay/pop_by_id/purge-by-status/
  failed/retry_failed.

## Lifecycle and operation graph

Publish to the topic; the broker delivers to a consumer; `complete()` acks, `fail()` nacks and the
framework re-publishes (or writes the `<topic>.dead_letter` queue past `max_retries`). Redelivery of an
unacked message on a crashed consumer is the broker's job (the at-least-once guarantee) - the framework
visibility timeout does not apply here.

## Configuration and precedence

- `TINA4_QUEUE_BACKEND=rabbitmq` + the broker connection env (URL/host/port/user/pass). Every value is
  constructor-settable and the constructor wins. A failed connect RAISES (PHP no longer stores FALSE in
  a broker socket after a failed connect).

## Failures, side effects and security

- REFUSE, NAMING ITSELF (the core contract): every operation RabbitMQ cannot express raises a typed
  error naming the backend and the operation - never a no-op, never an empty list. This is what makes
  the swap safe: you learn at the call site that RabbitMQ cannot prioritise, not silently in production.
- DEAD-LETTER IS A QUEUE (ADR-0023): PHP once REFUSED `deadLetters()` outright on the premise that
  RabbitMQ's dead-letter EXCHANGE is the only dead-letter - true of the DLX, false of the
  `<topic>.dead_letter` QUEUE Tina4 writes itself. Now answered non-destructively (drain + republish),
  stable across reads.
- Broker credentials are the security surface; the transport uses the configured AMQP TLS.

## Wire and persistence contract

AMQP: messages published to a topic, acked/nacked by the consumer. The dead-letter is the
`<topic>.dead_letter` queue (framework-written), not the broker DLX. Persistence and redelivery are the
broker's; the job payload rides the message body.

## Providers and substitutability

One of the two BROKER backends (with Kafka 092). It delivers at-least-once and refuses the store-only
operations the file (090) and MongoDB (093) backends implement. The refusals are the substitutability
contract - RabbitMQ is interchangeable for delivery, explicit about what it will not do.

## Contradictions and defects

No open contract defects - RabbitMQ is proven (deliver + refuse + non-destructive dead-letters, all
mutation-proved). The AMQP client library is a required runtime dependency for this backend only (it is
never a core dep; the backend loads it lazily and a missing library is a clear error). The Kafka
off-box caveat (QL-02, 089) does NOT apply to RabbitMQ - it is lab-verified.

## Owner decisions

None. The realization is proven and the refusals are ratified by ADR-0022.

## Proposed conformance fixture

Covered by `queue_contract.json` against a live RabbitMQ - the refusal cases and the non-destructive
dead-letter answer are mutation-proved. No separate fixture is owed.

## Integration map

- Selected by `TINA4_QUEUE_BACKEND=rabbitmq`; realizes the 089 lifecycle over AMQP; the dead-letter is
  a framework queue, not the broker DLX.
- The AMQP client library is the one optional dependency (lazy-loaded).

## Breaking changes and migration

None outstanding. The refuse-not-no-op semantics and the non-destructive `deadLetters()` already
shipped. A deployment on RabbitMQ speaks the proven contract.

## Implementation backlog

1. Nothing on the backend - it is proven. A missing AMQP library must remain a clear error (not a
   silent fallback to the file store).

## Porting capsule

Implement a RabbitMQ backend that realizes the 089 lifecycle at-least-once via broker ack: publish on
push; deliver to a consumer; `complete()` acks, `fail()` nacks and re-publishes (writing the
`<topic>.dead_letter` QUEUE past max_retries); answer `dead_letters()` non-destructively (drain +
republish the dead-letter queue, stable across reads). REFUSE - naming the backend and the operation -
priority (needs `x-max-priority` at declare, cannot redeclare), delay (no core per-message delay),
pop_by_id, purge-by-status, and failed()/retry_failed() (a retry re-publishes to the main topic). Load
the AMQP client lazily; a failed connect RAISES. Prove it in `queue_contract.json` against a live
RabbitMQ.

## Audit closure checklist

- [x] Boundary and public surface complete (the RabbitMQ realization; lifecycle is 089).
- [x] Lifecycle and every producer/consumer edge complete (publish/deliver/ack/dead-letter).
- [x] Configuration, failure, side-effect and security rules complete (refuse-naming-itself, dead-letter-is-a-queue).
- [x] Wire/storage and provider contracts complete (AMQP; framework dead-letter queue).
- [x] Existing-language contradictions recorded (none open; deliver+refuse proven).
- [x] Owner ambiguities recorded (none).
- [x] Proposed shared cases and mutation witnesses complete (live RabbitMQ in `queue_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
